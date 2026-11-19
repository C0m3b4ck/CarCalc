# Third-party licenses and notices

CarCalc itself is licensed under the Apache License 2.0 (see [`LICENSE`](LICENSE)).

This file lists the third-party components used by CarCalc. Full license texts,
where applicable, are in [`licenses/`](licenses/).

| Component | Version | Used for | License | License text / notice |
|---|---|---|---|---|
| [FLTK](https://www.fltk.org/) | 1.4.5 (native Linux build); cross-build script currently uses a prebuilt 1.3.9 Windows static lib | GUI toolkit | LGPL v2 **with FLTK exceptions** (static linking allowed) | [`licenses/FLTK-LICENSE.txt`](licenses/FLTK-LICENSE.txt) |
| [SQLite](https://www.sqlite.org/) | amalgamation (3.46.x used by the build script) | Embedded car database | Public domain | [`licenses/SQLITE-PUBLIC-DOMAIN.txt`](licenses/SQLITE-PUBLIC-DOMAIN.txt) |
| [ADEME Car Labelling dataset](https://www.data.gouv.fr/datasets/ademe-car-labelling/) | quarterly updates | `cars*.db` data | Licence Ouverte / Open Licence 2.0 | [`licenses/ADEME-OPEN-LICENCE-2.0.md`](licenses/ADEME-OPEN-LICENCE-2.0.md) |
| MinGW-w64 + GCC runtime | toolchain | Windows `.exe` build | GPLv3 + GCC Runtime Library Exception, plus permissive MinGW-w64 licenses | [`licenses/MINGW-W64-RUNTIME-NOTICE.md`](licenses/MINGW-W64-RUNTIME-NOTICE.md) |

## Required attributions

- **FLTK**: the FLTK license requires that programs identify their use of
  FLTK. This README does so in the Credits section. Static linking is
  explicitly allowed by the FLTK exceptions, so CarCalc's Apache 2.0 license
  is unaffected.
- **ADEME data**: when redistributing the database, keep the source
  attribution and the date of the last update. The dataset page and its
  Open Licence 2.0 text are linked above; see the licence file for details.
- **SQLite**: public domain, no attribution required.
