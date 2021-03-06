# Installation

**NOTE**: As of July 2016, ngless is available only as a pre-release to allow
for testing of early versions by fellow scientists. We do not recommend use in
production. Please [get in touch](mailto:coelho@embl.de) if you are interested
in using ngless in your projects.

At the moment, ngless can be esily obtained in binary form for Windows
(experimental) and with either *brew* or *nix* (for Mac OS X or Linux). Of
course, you can also compile from source.

## Windows

Download and run the [Windows
Installer](https://dl.dropboxusercontent.com/u/68453937/NGLess-0.0.0-install.exe).
The result is a command line utility, so you need to run it on the command
line. After running the installer, typing `ngless` on the terminal should work
as the installer will add the right directories to the path variable; you may
have to start a new terminal, though. It should also work under Cygwin (but
Cygwin is **not** a dependency).

The Windows package includes [bwa](http://bio-bwa.sourceforge.net/) and
[samtools](http://www.htslib.org/). The bwa and samtools executables are
available as `ngless-0.0.0-bwa` and `ngless-0.0.0-samtools`, respectively.  It
has been tested on Windows 10, but this has not had as intensitive testing as
the Linux/Mac OS X versions so any [bug
reports](https://github.com/luispedro/ngless/issues) are appreciated.


## From source

[Stack](http://docs.haskellstack.org/en/stable/README.html) is the simplest way
to install the necessary requirements. You should also have `gcc` installed (or
another C-compiler).

The following sequence of commands should download and build the software

    git clone https://github.com/luispedro/ngless
    cd ngless
    make


The first time you run this, it will take a while as it will download all
dependencies. After this ngless is ready to use!

## With Nix

If you use [nix](http://nixos.org), you can easily build and install ngless
using it (these scripts also install all necessary dependencies):

    nix-env -i -f https://github.com/luispedro/ngless-nix/archive/master.tar.gz

This should download the nix scripts and build ngless.

If you prefer, you can also first clone the repository:

    git clone https://github.com/luispedro/ngless-nix
    cd ngless-nix
    # inspect the default.nix & ngless.nix files if you wish
    nix-env -i -f .

## Make targets

The following are targets in the Makefile.

make
    compiles NGLess and haskell dependencies

clean
    remove local generated files by compilation

check
    run tests

bench
    run benchmarks

