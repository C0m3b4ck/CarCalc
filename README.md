# CarCalc

[![Latest release](https://img.shields.io/github/v/release/C0m3b4ck/CarCalc?style=flat-square)](https://github.com/C0m3b4ck/CarCalc/releases/latest)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20x64%20%7C%20Windows%20x86%20legacy%20%7C%20Linux-lightgrey?style=flat-square)](#building)

A small, power-conscious car calculator built with FLTK and SQLite.
Pick a car from an official French vehicle dataset and calculate fuel usage,
CO₂ emissions and trip costs.

## Features

- Browse/filter vehicles by **class**, **fuel type**, model, engine and gearbox
- Search-by-prefix filtering with live sorted results
- Urban, extra-urban and mixed fuel consumption in **L/km** (litres per kilometre;
  the ADEME database stores L/100 km, so values are converted), CO₂ emissions and price
- Trip-distance based fuel calculations
- Localized databases (`cars.db`, `cars_en.db`, `cars_pl.db`)
- Lightweight native GUI (FLTK) with an embedded SQLite database — no server or runtime install needed
- Resize-aware scaling: dragging scales boxes/fonts continuously from the minimum window up to any screen size (including 1920x1680); gaps stay pixel-sized from 1x upward and shrink below 1x; field labels follow their value displays; `CARCALC_UI_SCALE=1.5 ./prog` overrides the factor

## Download

**[Download the latest release →](https://github.com/C0m3b4ck/CarCalc/releases/latest)**

The badge above and this link always resolve to the newest published release.
Extract the archive and keep `cars.db` (or a localized variant) next to the executable.

## Database

This calculator uses the French car database from
[ADEME Car Labelling](https://www.data.gouv.fr/datasets/ademe-car-labelling/)
(data.gouv.fr). It contains official French vehicle certification data:
fuel consumption, CO₂ emissions and vehicle specifications for cars marketed
in France, updated quarterly.

The dataset is published under **Licence Ouverte / Open Licence 2.0**; see
[`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) for attribution details.

- [`DB_QUALITY.md`](DB_QUALITY.md) — data audit and known intentional gaps
  (for example, electric cars have no fuel-consumption figure).
- [`OFFLINE_DATA_SOURCES.md`](OFFLINE_DATA_SOURCES.md) — alternative datasets
  (EPA/FuelEconomy.gov, EEA, ADEME) that can be downloaded once and used locally.
- [`ui_v2/`](ui_v2/) — isolated redesigned GUI with a compact flat layout and
  the same resize-aware scaling, built by `ui_v2/compile_ui_v2.sh`.

## Building

### Staging every target (`stage_release.sh`)

`./stage_release.sh` builds each target from source into `release/<target>/`,
then writes an archive beside each folder: `.tar.gz` for Linux/macOS, and
`.zip`, `.7z`, plus a self-extracting `.exe` (when a Windows SFX module is
available) for Windows targets. The two ARM Windows targets also get a `.cab`:
`windows-mobile-arm.cab` is a Windows CE/Mobile installer package (MSCE
control file, installs into `\Program Files\CarCalc` and adds a Start Menu
link), while `windows-arm64.cab` is a plain CAB archive of the desktop ARM64
release. Targets whose toolchain is missing are listed as skipped; the rest
still build. The script never commits, tags or uploads anything.

Install the Linux cross compilers first:

```bash
sudo apt-get install -y gcc-i686-linux-gnu g++-i686-linux-gnu binutils-i686-linux-gnu libc6-dev-i386-cross gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu libc6-dev-arm64-cross
```

One-line setup for the macOS SDK/toolchain, Windows ARM toolchain and Windows
SFX module:

```bash
mkdir -p /tmp/opencode/carcalc-tools && cd /tmp/opencode/carcalc-tools && sudo apt-get install -y clang liblzma-dev libxml2-dev libssl-dev zlib1g-dev && git clone -q https://github.com/tpoechtrager/osxcross.git osxcross && mkdir -p osxcross/tarballs && wget -qcO osxcross/tarballs/MacOSX11.3.sdk.tar.xz https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX11.3.sdk.tar.xz && (cd osxcross && UNATTENDED=1 ./build.sh) && wget -qcO llvm-mingw.tar.xz https://github.com/mstorsjo/llvm-mingw/releases/download/20261117/llvm-mingw-20261117-ucrt-ubuntu-22.04-x86_64.tar.xz && mkdir -p llvm-mingw && tar -xf llvm-mingw.tar.xz -C llvm-mingw --strip-components=1 && wget -qcO 7z2606.exe https://github.com/ip7z/7zip/releases/download/26.06/7z2606.exe && mkdir -p 7z-extra && 7z x -y -o7z-extra 7z2606.exe 7z.sfx >/dev/null && echo 'Cross toolchains ready.'
```

Then, from the CarCalc checkout:

```bash
export PATH="/tmp/opencode/carcalc-tools/osxcross/target/bin:$PATH"
export MACOS_X64_CC=/tmp/opencode/carcalc-tools/osxcross/target/bin/x86_64-apple-darwin20.4-clang
export MACOS_X64_CXX=/tmp/opencode/carcalc-tools/osxcross/target/bin/x86_64-apple-darwin20.4-clang++
export MACOS_X64_AR=/tmp/opencode/carcalc-tools/osxcross/target/bin/x86_64-apple-darwin20.4-ar
export MACOS_STDLIB=libc++
export WINDOWS_ARM64_CXX=/tmp/opencode/carcalc-tools/llvm-mingw/bin/aarch64-w64-mingw32-g++
export WINDOWS_ARM64_CC=/tmp/opencode/carcalc-tools/llvm-mingw/bin/aarch64-w64-mingw32-gcc
export WINDOWS_ARM64_WINDRES=/tmp/opencode/carcalc-tools/llvm-mingw/bin/aarch64-w64-mingw32-windres
export WINDOWS_MOBILE_CXX=/tmp/opencode/carcalc-tools/llvm-mingw/bin/armv7-w64-mingw32-g++
export WINDOWS_MOBILE_CC=/tmp/opencode/carcalc-tools/llvm-mingw/bin/armv7-w64-mingw32-gcc
export WINDOWS_MOBILE_WINDRES=/tmp/opencode/carcalc-tools/llvm-mingw/bin/armv7-w64-mingw32-windres
export SFX_STUB=/tmp/opencode/carcalc-tools/7z-extra/7z.sfx
export CARCALC_LINUX_X11_ROOT=/tmp/opencode/carcalc-tools/linux-x11-sysroot
./stage_release.sh
```

`CARCALC_LINUX_X11_ROOT` should contain target-architecture X11/curl headers
and libraries under `usr/include/` and `usr/lib/<target-triple>/`. `linux-arm`
also needs target-architecture `libssl.so` and `libcrypto.so`; if they are
missing, that target is reported as skipped instead of aborting the run.

The Windows ARM compilers are set per target instead of prepending
`llvm-mingw/bin` to `PATH`, so the system x86/x64 MinGW builds keep using the
matching `libgcc`. `SFX_STUB` is optional; without it the self-extracting
Windows archives are skipped while ZIP and 7z are still produced. The Windows
Mobile target emits PE32 ARM with subsystem 4.20; full Windows CE runtime
compatibility needs a CE SDK.

### Native (Linux)

**Fully local build (recommended).** FLTK 1.4.5 and SQLite 3.54.1 are checked
into [`external_libraries/`](external_libraries/) and compiled from scratch:

```bash
./build_full.sh                 # produces ./prog
OUT=~/CarCalc ./build_full.sh   # custom output path
CLEAN=0 ./build_full.sh         # reuse the dependency build tree
```

This needs a C++17 compiler, CMake, X11 headers and libcurl headers, but **no
system FLTK or SQLite package**. Dependencies are built into the ignored
`.build-full/` directory.

**Quick incremental and sanitizer builds.** `compile_app.sh`,
`compile_app_safe.sh` and `compile_asan.sh` reuse the bundled FLTK 1.4.5 tree in
`.build-full/` (creating it with `build_full.sh` if needed). They deliberately do
**not** use the system `fltk-config`: FLTK 1.3.x renders the FLUID 1.4.5 layout
incorrectly, with misplaced widgets and overlapping labels.

```bash
./compile_app.sh            # normal optimized ./prog
./compile_app_safe.sh       # ASan build as ./prog
./compile_asan.sh --build   # ASan build as ./prog_asan (no GUI launch)
```

Only libcurl headers are required from the system.

### Windows x64 (cross-compile from Linux)

```bash
./compile_windows.sh
```

Produces a standalone `CarCalc.exe` (PE32+ GUI, statically linked — no FLTK or
SQLite DLLs needed; only standard Windows system DLLs are used). FLTK 1.4.5 is
cross-built from the bundled source into `.win-deps/fltk-1.4.5/`, matching the
FLUID 1.4.5 generated UI. The script copies `cars.db` and the translations next
to the `.exe`.

Requirements: `g++-mingw-w64-x86-64` (`x86_64-w64-mingw32-g++`) and CMake.

Useful overrides:

```bash
OUT=~/Downloads/CarCalc.exe ./compile_windows.sh   # custom output path
FLTK_WIN_DIR=/path/to/fltk-1.4.5 ./compile_windows.sh  # custom matching tree
```

### Windows x86 legacy (Windows 2000+)

```bash
./compile_windows_legacy.sh
```

Produces `CarCalc-legacy.exe`: a 32-bit PE32 GUI executable with subsystem
version 5.00, aimed at Windows 2000 and newer. The script builds its own
32-bit FLTK 1.4.5 static library in the ignored `.win-legacy-build/` directory
and leaves the modern Windows (`.win-deps/`) and Linux (`.build-full/`) build
trees untouched. FLTK is built without GDI+, OpenGL and printing; SQLite is
single-threaded and uses small Win2000 shims for `GetTickCount64` and
libstdc++ condition variables. Requirements are `gcc-mingw-w64-i686`,
`g++-mingw-w64-i686` and CMake.

```bash
OUT=~/Downloads/CarCalc-legacy.exe ./compile_windows_legacy.sh
CLEAN=1 ./compile_windows_legacy.sh     # rebuild the legacy FLTK tree
```

Both Windows scripts compile SQLite from the bundled amalgamation in
[`external_libraries/sqlite-3.54.1/`](external_libraries/sqlite-3.54.1/) and use
FLTK 1.4.5 from the checked-in source tree:

| Dependency | Version | Bundled source | Upstream | License |
|---|---|---|---|---|
| FLTK | 1.4.5 | [`external_libraries/fltk-1.4.5/`](external_libraries/fltk-1.4.5/) | [fltk.org](https://www.fltk.org/software.php?VERSION=1.4.5) · [GitHub tag](https://github.com/fltk/fltk/releases/tag/release-1.4.5) | LGPL v2 + FLTK exceptions |
| SQLite | 3.54.1 | [`external_libraries/sqlite-3.54.1/`](external_libraries/sqlite-3.54.1/) | [sqlite.org](https://www.sqlite.org/download.html) | Public domain |
| GNU Wget | 1.25.0 | [`external_libraries/wget-1.25.0/`](external_libraries/wget-1.25.0/) | [GNU FTP](https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz) | GPL v3 or later (source only, not linked) |

SQLite's `sqlite3.c`/`sqlite3.h` are compiled directly into each executable by
the scripts. See [`external_libraries/README.md`](external_libraries/README.md)
for checksums and rebuild details.

## Licenses

- CarCalc: [Apache License 2.0](LICENSE)
- Third-party components: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md), with full texts in [`licenses/`](licenses/)

## Author

Started on October 13th 2026 by C0m3b4ck.

## Credits

CarCalc is based in part on the work of the FLTK project
(https://www.fltk.org). Thanks to the FLTK, SQLite and MinGW-w64 teams and to
ADEME for the open Car Labelling data.
