#!/usr/bin/perl
# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use warnings;
use strict;
use 5.10.0;

use Mojo::UserAgent;
use Mojo::JSON qw(decode_json);
use Term::ANSIColor::Markup;
use Switch;
use Getopt::Long;

my $ua      = Mojo::UserAgent->new;
my $url     = 'https://weakdh.org/check/';
my @colors  = qw(green yellow red blue);
my @stats   = qw(Good Warning Bad Unknown);
my $nocolor = 0;
my @servers;

GetOptions ('nocolor' => \$nocolor);
if ($ARGV[0]) {
    if ($ARGV[0] =~ m/help/) {
        _print_usage();
    }
    if (-f $ARGV[0]) {
        open (my $fh, '<', $ARGV[0]) or die "Unable to open $ARGV[0]: $!";
        while (<$fh>) {
            chomp;
            push @servers, $_;
        }
    } else {
        @servers = ($ARGV[0]);
    }
} else {
    say "Please, give a file containing servers to check or an server to check as first argument\n";
    _print_usage();
}

for my $server (@servers) {
    my $color  = 1;
    my ($detail, @ips);

    my $tx    = $ua->get($url => form => { server => $server });
    if (my $res = $tx->success) {
        my $json  = decode_json($res->body);

        if (defined($json->{error})) {
            $color  = 4;
            $detail = $json->{error};
        } else {
            for my $result (@{$json->{results}}) {
                my ($color2, $detail2);
                if (!$result->{has_tls}) {
                    $color2  = 3;
                    $detail2 = 'This server does not support TLS.';
                } elsif ($result->{error}) {
                    $color2  = 4;
                    $detail2 = $result->{error};
                } elsif ($result->{export_dh_params}) {
                    ($color2, $detail2) = _details('support_export');
                } else {
                    if (defined($result->{chrome_cypher}) && $result->{chrome_cypher} =~ m/ECDHE/) {
                        ($color2, $detail2) = _details('ecdhe');
                    } else {
                        ($color2, $detail2) = _details(_dhe_to_status($result->{dh_params}));
                    }
                }
                push @ips, {
                    ip     => $result->{ip},
                    color  => $colors[$color2 - 1],
                    status => $stats[$color2 - 1],
                    detail => $detail2
                };
                $color = $color2 if ($color2 > $color);
            }
        }
    } else {
        $color  = 4;
        $detail = "Error while trying to get results for server $server";
        my $err = $tx->error;
        if ($err->{code}) {;
            $detail = "$err->{code} response: $err->{message}";
        } else {
            $detail = "Connection error: $err->{message}";
        }
    }

    my $struct = {
        color  => $colors[$color - 1],
        server => $server,
        status => $stats[$color - 1]
    };
    $struct->{detail} = $detail if (defined($detail));
    $struct->{ips}    = \@ips   if (@ips);

    _print_server($struct);
}

sub _is_common {
    my $prime = shift;
    my @common_primes = (
        '1n3kQMu73Bk21pPTSv0K1QyE0jmkX1ILuIF0y5i86VGEn5EuY5xy+xO0tNcXfhbVWsF5ukILKin+MkpGemNegf9ZATd77dz9MxaKRhqtO3La6IYAeARbB6fbynh0CH0VEOqfzJ3dMwUH3WLbiK6qdH3g9NbivWiw5zk+DyQhjrM=',
        'u7wtythGdJB8Q/z1gOnP29lYo/VotC1LCO7U6w+zUExsAwJ25xCADFzLuqiSJhTFvuylZaX98dKHorwEm+Z3gGDpGpKnV+MEj2iwdvfTbMjym6XfgdwspyXs5mJwzJpQNdjOzu+eoCdKY6seWPr9SYjQ9l0UZ1faBx3wRc/ha5s=',
        '5padPUlb4yx88YDDvdR5jpG3gYJRuwVeKiBkkEp5p3D6FaJZy9UjpqbvCcQwSNWiL5cfPCASm0gADm7dBhy8BT43HXlOUyffYR67vhusm1xgRM8CPXbgXuqbrZkbE6Y8l06e8YOetdsSUTb3Ji5WqIcVON/YI8ZQUIXiHw3VyGs=',
        'ybv193SoKXsPl83aOjRoxxF7a/eZoT2fH12sSHsiQf6V77E8KFXf0viYs/mRiOJO3zJt1ox2zIVTcoNRLUbxlTEpxpM2TYxxIC6rs+vIXB31OQf70LfrSQrQvJkoloaADEarBL983ZrUJeb7JVkutiWKBlXXXpOyZxdGrjSechs=',
        'zVwi+uoMU8OeYCJCwIj6DqMVhvRy6bBGBq7fs19WxJSAlfaHs4hXX6FwDbPQIlMCWlI6x26WRvdVoSM4ZTrgcctk8YVZHDTGZz+sm3jcTXHlPzpcymMm+JxUAPv4Jyp2NnxjDiNKkF5OVYzalopGoTatMIjdKV+TTsNq219pw/M=',
        'kkAkNcOhLkTTcw2OeMrfp44vW1GpVr/0245WUj6WleY+MlBs/rkS8qd9IucbtUyGgIk7gq0bzzN/f3eW0/uWgYHZuh9wNKv7H5ezEEzzID9mPoGZC34JD2xMXuGg5X7BdNPoStnnLmrH2mrqEt8pfBMYVPvyGsToecI7vGC091M=',
        '///////////JD9qiIWjCNMTGYouA3BzRKQJOCIpnzHQCC76mOxObIlFKCHmONATd75UZs806QxswKwpt8l8UN0/hNW1tUcJF5IW1dmJefsb0TELppjftawv/XLb0Brft7jhr+1qJn6WunyQRfEsf5kkoZlHs5lOB//////////8=',
        '1sCUrVf1N09o1Yx7CWhy2UXO4fgmZOBZRCHh1ePI6YvD8Kavj5Lxnj/vkze5m5yToFXVWpbkJXNABaaO1HBA/fAKVZNuukuT9ky6GgBORRNhHJshdDinA6IGDCA40M+q/7ukj7naxLJFDcWMsDIKAxfioxtEoCeHxlf7DAy+wR0=',
        '6eZCWZ01XzfJf/01ZxILjiXJzUPpJ7OpZw++xdiQFBki0sOzrSSACTeZhp0ehGqrSfqwrSbSzmoiIZ1HC859d31KIfvpwnC1f2BwAvPO+Dk2lM9F7jaIwRqMVqsSej2v',
        'sQuPlqCA4B3ekt5erl1U7FLJn7z7BqPGmmqdylLSO2Fgc+KGdaI9GJg47x4u5lLAE+y0rqkGESMkl1w81JuDv6zL3X2QxL1wmEiOnCGac3JO/9b65WRHOPqjGk/1W8zAoVGvXw3ItL1FvzffNlwaZeaM/adtTacI3x+yvC5KQ3E='
    );
    if (grep /^$prime$/, @common_primes) {
        return 1;
    }
    return 0;
}

sub _dhe_to_status {
    my $params = shift;

    if (!defined($params)) {
        return 'unsupported';
    }
    if ($params->{prime_length} < 1024) {
        return 'short';
    }
    if ($params->{prime_length} == 1024 && _is_common($params->{prime})) {
        return 'common';
    }
    if ($params->{prime_length} < 2048) {
        return 'ok';
    }
    if ($params->{prime_length} >= 2048) {
        return 'strong';
    }
};

sub _details {
    my $status = shift;

    switch ($status) {
        case 'support_export' {
            return (3, "This site supports export-grade Diffie-Hellman key exchange and is vulnerable to the Logjam attack. You need to disable export cipher suites.");
        }
        case 'short' {
            return (3, "This site uses weak Diffie-Hellman parameters. Your site is vulnerable to attack and may stop working in Chrome, Firefox, Safari, and Internet Explorer with upcoming patches. You need to generate new, 2048-bit Diffie-Hellman parameters.");
        }
        case 'common' {
            return (2, "This site uses a commonly-shared 1024-bit Diffie-Hellman group, and might be in range of being broken by a nation-state. It might be a good idea to generate a unique, 2048-bit group for the site.");
        }
        case 'ok' {
            return (1, "This site uses a unique or infrequently used 1024-bit Diffie-Hellman group. You are likely safe, but it's still a good idea to generate a unique, 2048-bit group for the site.");
        }
        case 'strong' {
            return (1, "This site uses strong (2048-bit or better) key exchange parameters and is safe from the Logjam attack.");
        }
        case 'ecdhe' {
            return (1, "This site is safe from the Logjam attack. It supports ECDHE, and does not use DHE.");
        }
        case 'unsupported' {
            return (2, "This site does not support perfect forward secrecy.  While it is safe from the Logjam attack, you should deploy Elliptic-Curve Diffie-Hellman (ECDHE) in order to protect your users.");
        }
    }
}

sub _print_server {
    my $s = shift;

    die 'Error while trying to print server information' unless (defined($s->{server}));
    $s->{color} = $colors[3] unless (defined($s->{color}));

    if ($nocolor) {
        say "$s->{server}:";
    } else {
        say Term::ANSIColor::Markup->colorize("<$s->{color}><bold>$s->{server}</bold></$s->{color}>:");
    }
    say "  status: $s->{status}";
    say "  detail: $s->{detail}" if (defined($s->{detail}));
    say "  ips:" if (defined($s->{ips}));
    for my $ip (@{$s->{ips}}) {
        if ($nocolor) {
            say "    $ip->{ip}:";
        } else {
            say Term::ANSIColor::Markup->colorize("    <$ip->{color}><bold>$ip->{ip}</bold></$ip->{color}>:");
        }
        say "      status: $ip->{status}";
        say "      detail: $ip->{detail}";
    }
}

sub _print_usage {
    say <<EOF;
logjam.pl

(c) 2015 Luc Didry <luc\@didry.org>
This program is free software, licensed under the WTFPL (http://www.wtfpl.net/about/)

It uses https://weakdh.org/ to check if you server is you server is vulnerable to Logjam attack.

Usage   : ./logjam.pl [--nocolor] [--help] <server|file containing servers>
Options : --nocolor     prevents colouring the ouput

If using a file to provide servers to check, make sure it has only one server per line.
EOF
    exit 0;
}
