# cctools for Mavericks

Apple's
[cctools](https://github.com/apple-oss-distributions/cctools)
and
[ld64](https://github.com/apple-oss-distributions/ld64)
for Mac OS X 10.9 Mavericks.

Primary usefulness: linking a `.kext`, from any supported host platform, that 10.9's kernel will load.
(clang-22's `ld64.lld` can't do this. 10.9's Command Line Tools `ld` can, but only on 10.9.)

## Linking a 10.9 kernel extension

A `.kext` is a directory containing an `Info.plist` and a specially formatted executable:

```txt
HelloWorld.kext
└── Contents
    ├── Info.plist
    └── MacOS
        └── hello
```

### Directly on Mavericks or modern macOS

```sh
sudo installer -pkg cctools-<version>.pkg -target /
/usr/local/mavergreen/cctools/bin/ld -arch x86_64 -kext -static -macosx_version_min 10.9 hello.o -o hello
```

### From Linux

```sh
sudo mkdir -p /opt/mavergreen
sudo tar -C /opt/mavergreen -zxpf cctools-<version>-linux-x86_64.tar.gz
/opt/mavergreen/cctools/bin/ld -arch x86_64 -kext -static -macosx_version_min 10.9 hello.o -o hello
```
