# Third-party licenses and notices

CarCalc itself is licensed under the Apache License 2.0 (see [`LICENSE`](LICENSE)).

This file lists the third-party components used by CarCalc. Full license texts,
where applicable, are in [`licenses/`](licenses/).

| Component | Version | Used for | License | License text / notice |
|---|---|---|---|---|
| [FLTK](https://www.fltk.org/) | 1.4.5 (bundled in `external_libraries/fltk-1.4.5/` and compiled into every build) | GUI toolkit | LGPL v2 **with FLTK exceptions** (static linking allowed) | [`licenses/FLTK-LICENSE.txt`](licenses/FLTK-LICENSE.txt) · [`external_libraries/fltk-1.4.5/COPYING`](external_libraries/fltk-1.4.5/COPYING) |
| [SQLite](https://www.sqlite.org/) | 3.54.1 amalgamation (bundled in `external_libraries/sqlite-3.54.1/`) | Embedded car database | Public domain | [`licenses/SQLITE-PUBLIC-DOMAIN.txt`](licenses/SQLITE-PUBLIC-DOMAIN.txt) |
| [GNU Wget](https://www.gnu.org/software/wget/) | 1.25.0 source (bundled in `external_libraries/wget-1.25.0/`; source only, not linked into CarCalc) | Bundled downloader source | GPL v3 or later | [`licenses/GPL-3.0.txt`](licenses/GPL-3.0.txt) · [`external_libraries/wget-1.25.0/COPYING`](external_libraries/wget-1.25.0/COPYING) |
| [ADEME Car Labelling dataset](https://www.data.gouv.fr/datasets/ademe-car-labelling/) | quarterly updates | `cars*.db` data | Licence Ouverte / Open Licence 2.0 | [`licenses/ADEME-OPEN-LICENCE-2.0.md`](licenses/ADEME-OPEN-LICENCE-2.0.md) |
| MinGW-w64 + GCC runtime | toolchain | Windows `.exe` build | GPLv3 + GCC Runtime Library Exception, plus permissive MinGW-w64 licenses | [`licenses/MINGW-W64-RUNTIME-NOTICE.md`](licenses/MINGW-W64-RUNTIME-NOTICE.md) |

Upstream source archives and their checksums are recorded in
[`external_libraries/README.md`](external_libraries/README.md). `./build_full.sh` compiles FLTK and
SQLite from those checked-in sources rather than using system libraries.

## Required attributions

- **FLTK**: the FLTK license requires that programs identify their use of
  FLTK. This README does so in the Credits section. Static linking is
  explicitly allowed by the FLTK exceptions, so CarCalc's Apache 2.0 license
  is unaffected.
- **ADEME data**: when redistributing the database, keep the source
  attribution and the date of the last update. The dataset page and its
  Open Licence 2.0 text are linked above; see the licence file for details.
- **SQLite**: public domain, no attribution required.

## Shipped with each binary

`stage_release.sh` copies these into every target folder (and into the matching
archive), because they apply to the distributed binary or its data:

- `LICENSE` — CarCalc's Apache License 2.0.
- `THIRD_PARTY_LICENSES.md` and `licenses/` — the FLTK license and required
  attribution, the SQLite public-domain notice, the MinGW-w64/GCC runtime
  notice for Windows binaries, the ADEME Open Licence 2.0 for the bundled
  `cars*.db`, and the GPL-3.0 notice for the bundled Wget source.
- `cars*.db` and `translations/` — data and translations covered by the ADEME
  attribution above.

GNU Wget is bundled as source only and is not linked into CarCalc, so its GPL
obligations apply to redistribution of that source, not to these binaries.
Linux binaries link libcurl and the X11/font libraries dynamically from the
host system, so those components' licenses stay with the operating system;
Windows binaries use the OS-provided `winhttp` library.
