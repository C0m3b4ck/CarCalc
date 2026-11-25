# CarCalc

[![Latest release](https://img.shields.io/github/v/release/C0m3b4ck/CarCalc?style=flat-square)](https://github.com/C0m3b4ck/CarCalc/releases/latest)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20x64%20%7C%20Linux-lightgrey?style=flat-square)](#building)

A small, power-conscious car calculator built with FLTK and SQLite.
Pick a car from an official French vehicle dataset and calculate fuel usage,
CO₂ emissions and trip costs.

## Features

- Browse/filter vehicles by **class**, **fuel type**, model, engine and gearbox
- Search-by-prefix filtering with live sorted results
- Urban, extra-urban and mixed fuel consumption, CO₂ emissions and price
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

**Build against system libraries.** For a quick incremental build:

```bash
./compile_app.sh
# or:
g++ -O2 -std=c++17 -o prog \
  main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp language.cpp \
  government_prices.cpp car_calc_ui.cxx \
  -lsqlite3 -lcurl $(fltk-config --cxxflags) $(fltk-config --ldflags)
```

This variant requires FLTK development headers and SQLite3 development files.

### Windows x64 (cross-compile from Linux)

```bash
./compile_windows.sh
```

Produces a standalone `CarCalc.exe` (PE32+ GUI, statically linked — no FLTK or
SQLite DLLs needed; only standard Windows system DLLs are used). The script
caches dependencies in `.win-deps/` and copies `cars.db` next to the `.exe`.

Requirements: `g++-mingw-w64-x86-64` (`x86_64-w64-mingw32-g++`) and `unzip`.

Useful overrides:

```bash
OUT=~/Downloads/CarCalc.exe ./compile_windows.sh   # custom output path
FLTK_WIN_DIR=/path/to/fltk ./compile_windows.sh    # custom Windows FLTK build
```

The bundled helper uses a prebuilt MinGW-w64 FLTK 1.3.9 static library when
available; SQLite is compiled from the bundled amalgamation in
[`external_libraries/sqlite-3.54.1/`](external_libraries/sqlite-3.54.1/). To build FLTK from source too,
use the checked-in upstream sources (or fetch the same releases):

| Dependency | Version | Bundled source | Upstream | License |
|---|---|---|---|---|
| FLTK | 1.4.5 | [`external_libraries/fltk-1.4.5/`](external_libraries/fltk-1.4.5/) | [fltk.org](https://www.fltk.org/software.php?VERSION=1.4.5) · [GitHub tag](https://github.com/fltk/fltk/releases/tag/release-1.4.5) | LGPL v2 + FLTK exceptions |
| SQLite | 3.54.1 | [`external_libraries/sqlite-3.54.1/`](external_libraries/sqlite-3.54.1/) | [sqlite.org](https://www.sqlite.org/download.html) | Public domain |

Cross-compile FLTK with `x86_64-w64-mingw32-g++ --host=x86_64-w64-mingw32`,
build statically, then point `FLTK_WIN_DIR` at that tree. SQLite's
`sqlite3.c`/`sqlite3.h` are compiled directly into the executable by the script.
See [`external_libraries/README.md`](external_libraries/README.md) for checksums and rebuild details.

## Licenses

- CarCalc: [Apache License 2.0](LICENSE)
- Third-party components: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md), with full texts in [`licenses/`](licenses/)

## Author

Started on October 13th 2026 by C0m3b4ck.

## Credits

CarCalc is based in part on the work of the FLTK project
(https://www.fltk.org). Thanks to the FLTK, SQLite and MinGW-w64 teams and to
ADEME for the open Car Labelling data.
