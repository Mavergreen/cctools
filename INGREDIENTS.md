# Build ingredients

Everything baked into the shipped `.pkg` and Linux archive, and how a change to it reaches a release.
An *ingredient* is an input to the product; the *own upstream* is the thing this repo exists to port.

| Ingredient | Pinned in | Renovate | On a bump |
|---|---|---|---|
| Apple's cctools 1035.1.102 and ld64 957.1 (own upstream) | `UPSTREAM_VERSION` | none: ld64 957.1 is the last Apple published, so no newer one will come | a new cctools version would cut `-mavericks.1` |
| cctools-port, the portable tree of that cctools and ld64 | `components/cctools-port/version` (branch and commit), with GitHub's tarball SHA-256 in `components/cctools-port/sha256` | ✅ `git-refs` on the branch moves the commit; the SHA-256 moves by hand (see below) | repackage → `-mavericks.(N+1)` |
| clang22 (the compiler on every host) | `components/clang22/version`, with its Linux archive's digest in `components/clang22/linux-sha256` | ✅ `github-releases` on `Mavergreen/clang-22`; the digest moves by hand | repackage |
| Recaulk (headers and `librecaulk.a`, through clang22's cfgs, x86_64 only) | inside the pinned clang22 | moves with clang22 | repackage |
| GNU Make (runs the Mac build; 10.9 has none without the Command Line Tools) | `components/make/version` | ✅ `github-releases` on `Mavergreen/make` | repackage |
| swift-corelibs-libdispatch, with its BlocksRuntime (linked statically into the Linux tools) | `components/libdispatch/version` (tag and commit), with its tarball SHA-256 in `components/libdispatch/sha256` | ✅ `github-tags`; the SHA-256 moves by hand | repackage |
| MacOSX10.9 and 11.3 SDKs, Sparkle framework | `Mavergreen/shipyard@v1` | ✅ github-actions manager tracks the tag | `@v1` is a moving tag, so content moves without a path changing |
| The Linux build container (Ubuntu 22.04 and its packages) | `build/linux/base-image`, `apt-snapshot`, `packages.lock` (clang-22's, copied) | none; moved by hand, with clang-22's | repackage |

**Digests Renovate cannot write.** A bump of cctools-port, libdispatch or clang22 fails its build at
the fetch, naming the digest it got, until someone writes it on the branch, so those three never
automerge. A pins bot would write them (`.superpowers/QUEUE.md`); every repo that has one keeps its
own copy today, and shipyard should own one instead.

## How cctools is verified

cctools-port has no releases and signs nothing. Each build fetches GitHub's tarball of the pinned commit
with shipyard's `fetch_pinned_source.sh`, which checks it against `components/cctools-port/sha256`
and fails closed. The first pin was recorded from the tarball of `ef96908`, the head of
`1035.1.102-ld64-957.1` on 2026-11-20. `build/fetch-cctools.sh` also refuses a pinned branch that is not
a branch of `UPSTREAM_VERSION`.

## How cctools is built

`build/build-cctools.sh --variant mac-x86_64|mac-arm64|linux-x86_64` runs cctools-port's own
`configure` and `make` with clang22, on any host that can build the variant: in CI all three build on Linux, in
clang-22's locked Ubuntu 22.04 container, through `build/build-release.sh`, and a 10.9 box builds
`mac-x86_64` natively. It works in an environment holding only `HOME` (an empty directory),
`TMPDIR`, `PATH` (clang22, GNU Make on a Mac, then the system's directories), `LC_ALL=C` and
`SOURCE_DATE_EPOCH`.

- **Changes:** `patches/`, applied in name order by shipyard's `apply_patches.sh`.
  `0001` stops `configure` from searching `/usr/local` and `/usr/pkg` on a native build, so a box's
  own libraries never reach the tools. `0002` makes `ld -v` say where the modified source is, as the
  APSL asks, in place of the time of the build. A changed APSL file says so, with the date, in its
  licence header.
- **Off:** libtapi (the 10.9 SDK has no `.tbd` stubs to read), LTO (there is no libLTO to load) and
  so xar and llvm-config.
- **Mac, x86_64:** for Mac OS X 10.9, against the 10.9 SDK, with clang22's cfgs on: they bring
  Recaulk's headers and `librecaulk.a`, and clang22's own libc++, which ld64's C++20 needs.
  `build/dispatch-standin.h` is force-included (see Conformance deviations).
- **Mac, arm64:** for macOS 11, against the 11.3 SDK and its own libc++, with the cfgs off (they target
  x86_64 10.9, and clang22's runtimes are x86_64 only), on Linux or a modern Mac: the 10.9 clang22 has
  no AArch64 backend.
- **Linux, x86_64:** in clang-22's locked Ubuntu 22.04 container, with clang22 and lld, against
  libdispatch and BlocksRuntime that `build/build-libdispatch.sh` builds statically, so the archive
  needs no library beside it. The tools run on the container's glibc 2.35 or later.
- **Guarded:** shipyard's compat guard runs over every binary of both Mac slices before the build exits 0.
- **Staged:** under `/usr/local/mavergreen/cctools` on a Mac and `/opt/mavergreen/cctools` on Linux:
  `bin/` (ld, as, ar, lipo, otool, nm, libtool, strip, install_name_tool, codesign_allocate and the
  rest), `share/man`, and `share/doc/cctools` with `APPLE_LICENSE`, the patches the binaries are
  built with, and `THIRD_PARTY_NOTICES`, which `build/third-party-notices.sh` collects from every
  source file under a licence of its own (BSD, LLVM's University of Illinois licence).
- **Checked:** `tests/smoke-test.sh` checks the layout and licences, fails on any installed file naming
  the build host, and allows Mach-O loads only from `/usr/lib` and `/System`. Where the tools run, it
  assembles `tests/fixtures/kext/hello.s` with `as`, links it with `ld -kext`, and requires an
  `MH_KEXT_BUNDLE` holding only the load commands 10.9's kxld accepts. In the 10.9 VM,
  `tests/kext-load-test.sh` has kxld link that kext, then loads and unloads it.
  `tests/kext-fixture-test.sh` keeps `hello.s` what clang22 makes of `hello.c`.

## How the pkg is made

`build/merge.sh` merges the x86_64 and arm64 stages into one universal tree with shipyard's
`lipo-merge-tree.sh`. `build/package-pkg.sh` packages it as `cctools-<version>.pkg`: shipyard's
`dev.mavergreen.base`, then `dev.mavergreen.cctools`, with the 10.9.5 install floor, the APSL as the
licence, and `stage_product.sh`'s manifest and install scripts. Everything in the tree's `bin` and
`share/man` is exported to the family's link farm, which `PATH` searches after `/usr/bin`.

## What a release carries

`cctools-<version>.pkg`, the feed `cctools.xml`, `cctools-<version>-linux-x86_64.tar.gz`,
`cctools-port-<commit>.tar.gz` (the source tarball the builds verified, checked again as it is
attached) and `cctools-<version>-patches.tar.gz`. Together they are the source of every binary, kept
with the release for as long as it is published, which is what APSL 2.0 section 2.2 asks of a
distributor of modified Covered Code. `publish-release.yml` adds `SHA256SUMS` over them all.

## How the updater is built

`CMakeLists.txt` is the Sparkle updater, "Mavericks cctools", with the generic app icon by explicit
opt-in. `build/build-updater.sh` builds it with clang22, once per arch, and merges the two into one
universal app. Its public key is the family's, in `updater/ed25519_key.pub`.

## Declared state

- upstream: UPSTREAM_VERSION
- cctools-port: components/cctools-port/version
- cctools-port-sha256: components/cctools-port/sha256
- clang22: components/clang22/version
- make: components/make/version
- libdispatch: components/libdispatch/version
- patches: patches

## Conformance deviations

- arm64:usr/local/mavergreen/cctools/bin/*: cctools is a developer tool that links and inspects
  Mavericks binaries (a kext, first, for Recaulk), so it runs on the modern Macs that build them too.
  `modern-smoke` runs the arm64 slice.
- macos-runner:release.yml:modern-smoke: the arm64 slice is installed and run on current macOS (check 37); exit: none while the slice ships
- shipyard-cmake-only:build/build-updater.sh: on Linux the updater configures with the Ubuntu CMake locked in
  `build/linux/packages.lock`; the cmake product has only Mac host binaries. Reconsider when a Linux cmake
  product exists.
- shipyard-cmake-only:build/build-libdispatch.sh: the Linux build configures libdispatch with the
  Ubuntu CMake locked in `build/linux/packages.lock`; the cmake product has only Mac host binaries.
  Reconsider when a Linux cmake product exists.
- debt:build/dispatch-standin.h: ld64-957.1 uses `DISPATCH_APPLY_AUTO` and `dispatch_queue_global_t`,
  which the 10.9 SDK lacks. Recaulk's `<dispatch/dispatch.h>` carries both from its next release
  (c2dd7a1); `tests/dispatch-standin-test.sh` fails once the pinned clang22 brings it, and then the
  stand-in is deleted.
