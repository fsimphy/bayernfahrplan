# bayernfahrplan
[![Travis CI status](https://travis-ci.org/fsimphy/bayernfahrplan.svg?branch=develop)](https://travis-ci.org/fsimphy/bayernfahrplan)
[![codecov](https://codecov.io/gh/fsimphy/bayernfahrplan/branch/develop/graph/badge.svg)](https://codecov.io/gh/fsimphy/bayernfahrplan)
[![Join the chat at https://gitter.im/fsimphy/Lobby](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/fsimphy/Lobby)

A JSON-fetcher for bus departues in bavaria written in D

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system ([Raspberry Pi](https://www.raspberrypi.org/)).

### Prerequisites

#### D compiler
Either [DMD](https://dlang.org/download.html#dmd) or [LDC](https://github.com/ldc-developers/ldc#installation) is needed to compile the project. Additionally, the packagemanager [DUB](https://code.dlang.org/) is needed. Install via your distribution’s packagemanager if you are running linux or via [Homebrew](https://brew.sh/) if you are running OS X:
- Debian based systems:
```
sudo wget http://master.dl.sourceforge.net/project/d-apt/files/d-apt.list -O /etc/apt/sources.list.d/d-apt.list
sudo apt-get update && sudo apt-get -y --allow-unauthenticated install --reinstall d-apt-keyring
sudo apt-get update
# DMD:
sudo apt-get install dmd-compiler
# LDC:
sudo apt-get install ldc
# DUB:
sudo apt-get install dub
```
- Arch Linux:
```
# DMD:
sudo pacman -S dmd
# LDC:
sudo pacman -S ldc
# DUB:
sudo pacman -S dub
```
- OS X
```
# DMD:
brew install dmd
# LDC:
brew install ldc
# DUB:
brew install dub
```

#### OpenSSL
The project depens on OpenSSL being available. Both OpenSSL-1.0 and OpenSSL-1.1 are supported.
OpenSSL should be available by default on most systems. If it is not available, use your distribution’s packagemanager to install it if you are running linux, or [Homebrew](https://brew.sh/) if you are running OS X:
- Debian based systems:
```
sudo apt-get install openssl
```
- Arch Linux:
```
sudo pacman -S openssl
```
- OS X
```
brew install openssl
```

### Installing

To install the project, you first need to clone the repository:
```
git clone https://github.com/fsimphy/bayernfahrplan.git
```

Building the project is done by running the following command inside the project’s root directory:
```
dub build
```

To run the project, simply run the following command in the project’s root directory:
```
dub run [-- options]
```
If you already built the project, you can also run it directly:
```
./bayernfahrplan [options]
```
See configuration for a list of available options.

## Configuration
The project can be configured by commandline switches. These are the available options:
```
Usage: bayernfahrplan [options]

 Options:
-f             --file The file that the data is written to.
-s             --stop The bus stop for which to fetch data.
-r --replacement-file The file that contais the direction name replacement info.
-v          --version Display the version of this program.
-h             --help This help information.
```
The `replacement-file` file is an optional file used to replace the names of certain bus stops. This is the basic syntax:
```
"<name>" = "<replacment>"
```
For example, a `replacement-file` could look like this:
```
"Regensburg Wernerwerkstraße" = "Wernerwerkstraße"
"Regensburg Neuprüll" = "Neuprüll"
"Regensburg Klinikum" = "Klinikum"
```

## Running the tests

To run the tests, run the following command in the project’s root directory:
```
dub test
```
This runs all available tests.
## Deployment

Deploying the project on a Raspberry Pi requires some more work, because DMD is not able to build arm binaries and LDC is not available in the repositories of the major linux distributions for the Raspberry Pi.

We suggest using [Arch Linux ARM](https://archlinuxarm.org/), but using a different distribution such as [Raspbian](https://www.raspbian.org) should also be possible.

### Deployment to Arch Linux ARM
First install neccessary dependencies:
```
sudo pacman -S llvm gcc ncurses zlib
```
We will install LDC-1.6.0, which depens on `libtinfo`, which is contained in the `ncurses` package, but the version (`libtinfo.so.6.0`) is wrong (LDC needs `libtinfo.so.5`). It seems as though simply creating a symbolic link does the trick:
```
sudo ln -s /usr/lib/libtinfo.so /usr/lib/libtinfo.so.5
```
Be aware that this is quite hacky and might cause problems later on. It might be better to install `libtinfo.so.5` manually.

To install LDC-1.6.0 (and DUB), download and extract it in your home folder via the following commands:
```
wget https://github.com/ldc-developers/ldc/releases/download/v1.6.0/ldc2-1.6.0-linux-armhf.tar.xz
tar xf ldc2-1.6.0-linux-armhf.tar.xz
```
Then add it to your `PATH`:
```
export PATH=~/ldc2-1.6.0-linux-armhf/bin
```
You might want to add the previous command to your `.bashrc` (or similar) file so you don't have to retype it every time you want to use DUB or LDC.

Now you can build, run and test the project as explained in the earlier sections.
## Built With

* [DUB](https://code.dlang.org/) - Dependency Management
* [requests](https://github.com/ikod/dlang-requests) - HTTP client library


## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on the process for submitting issues and pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/fsimphy/bayernfahrplan/tags). 

## Authors

* [**Johannes Loher**](https://github.com/ghost91-)
* [**Oliver Rümpelein**](https://github.com/pheerai)

See also the list of [contributors](https://github.com/fsimphy/bayernfahrplan/contributors) who participated in this project.

## License

This project is licensed under the MIT License, see the [LICENSE.md](LICENSE.md) file for details.

## Acknowledgments

Thanks a lot to the folks at the [D Programming Language Forum](https://forum.dlang.org/) and especially to [ikod](https://github.com/ikod), the maintainer of [dlang-requests](https://vibed.org/), for always helping out with technical questions.

