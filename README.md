# cctools for Mavericks

Apple's cctools 1035.1.102 and ld64 957.1 (`ld`, `as`, `ar`, `lipo`, `otool`, `nm`, `libtool`, `strip`,
`install_name_tool`, `codesign_allocate` and the rest), built to run on Mac OS X 10.9 Mavericks, on a modern
Mac, and on x86_64 Linux. They need no Command Line Tools.

The reason to want them: `ld -kext` makes a kext that 10.9's kernel loads. clang22's `ld64.lld` makes no
`MH_KEXT_BUNDLE`, and 10.9's own `ld` needs the Command Line Tools.

## Install

### On a Mac

Download `cctools-<version>.pkg` from the [latest release](https://github.com/Mavergreen/cctools/releases/latest)
and open it, or:

```sh
sudo installer -pkg cctools-<version>.pkg -target /
```

The tools are in `/usr/local/mavergreen/cctools/bin`, and in a new Terminal on your `PATH` after `/usr/bin`,
so name the directory, or put it first, to be sure of getting these:

```sh
/usr/local/mavergreen/cctools/bin/ld -arch x86_64 -kext -static -macosx_version_min 10.9 hello.o -o hello
```

A Sparkle updater keeps them current.

`as`, like Apple's own in this cctools, hands the assembly to a clang: the first `clang` on `PATH`, or the
one `CCTOOLS_CLANG_AS_EXECUTABLE` names (clang22's, say). The other tools need nothing beside them.

### On Linux

```sh
sudo mkdir -p /opt/mavergreen
sudo tar -C /opt/mavergreen -xzf cctools-<version>-linux-x86_64.tar.gz
```

The tools are in `/opt/mavergreen/cctools/bin`. They need glibc 2.35 or later.

## Source and licence

Apple's code is under the Apple Public Source License 2.0, and some files under licences of their own;
the tools install both in `share/doc/cctools`. They are built from
[cctools-port](https://github.com/tpoechtrager/cctools-port), pinned by commit, with the changes in
[`patches/`](patches). Every release carries the source tarball and patches it was built from. How it is
built and checked is in [INGREDIENTS.md](INGREDIENTS.md).

This is an unofficial community build, not affiliated with or supported by Apple.
