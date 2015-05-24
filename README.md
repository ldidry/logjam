# Logjam.pl

Logjam.pl is a small perl script to verify if you server is vulnerable to the [Logjam attack](https://weakdh.org/).

It uses <https://weakdh.org/check/> to get the informations about the vulnerability of your server.

## Installation

First, get the sources.

```
git clone https://git.framasoft.org/luc/logjam
cd logjam
```

### Manual installation

Install the dependancies described in `cpanfile`, then launch the program.

```
./logjam.pl help
```

### Installation with Carton

[Carton](https://metacpan.org/pod/distribution/Carton/script/carton) is a dependancy manager for Perl. It installs the dependancies locally.

```
# Install Carton
cpan Carton
# Install dependancies
carton install
# Launch the program
carton exec ./logjam.pl help
```

## License

WTFPL. See LICENSE file.

## Bugs

Please, report any bug to <https://git.framasoft.org/luc/logjam/issues>
