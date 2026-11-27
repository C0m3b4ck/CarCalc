# Bundled external library sources

This directory contains the exact upstream source releases used by
`./build_full.sh`. They are checked in so a full build does not depend on a
package manager, a prebuilt FLTK archive, or network access.

| Component | Version | Directory | Upstream | License |
|---|---|---|---|---|
| FLTK | 1.4.5 | [`fltk-1.4.5/`](fltk-1.4.5/) | [GitHub tag `release-1.4.5`](https://github.com/fltk/fltk/releases/tag/release-1.4.5) · [fltk.org](https://www.fltk.org/software.php?VERSION=1.4.5) | LGPL v2 with FLTK exceptions ([`COPYING`](fltk-1.4.5/COPYING)) |
| SQLite | 3.54.1 | [`sqlite-3.54.1/`](sqlite-3.54.1/) | [sqlite.org amalgamation](https://www.sqlite.org/download.html) | Public domain ([notice](../licenses/SQLITE-PUBLIC-DOMAIN.txt)) |
| GNU Wget | 1.25.0 | [`wget-1.25.0/`](wget-1.25.0/) | [GNU FTP](https://ftp.gnu.org/gnu/wget/wget-1.25.0.tar.gz) | GPL v3 or later ([`COPYING`](wget-1.25.0/COPYING), [`../licenses/GPL-3.0.txt`](../licenses/GPL-3.0.txt)) |

## Source archives

| Archive | SHA-256 |
|---|---|
| `fltk-1.4.5.tar.gz` (`release-1.4.5` source tarball) | `7715e69ce081fa9ce6da48bb0dd3b07a4cf2cf937813814c04272f36fff593ea` |
| `sqlite-amalgamation-3540100.zip` | `0a9c8e34352dad46006aa82836d5383bff9dc6bc9ce5a60553c05aa30e6ad1f9` |
| `wget-1.25.0.tar.gz` | `766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784` |

SQLite also publishes the SHA3-256 of the amalgamation zip:
`92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30`.

The SQLite bundle contains the four standard amalgamation files
(`sqlite3.c`, `sqlite3.h`, `sqlite3ext.h`, `shell.c`). Only `sqlite3.c` and
`sqlite3.h` are needed by CarCalc.

## Rebuilding

`./build_full.sh` configures and compiles FLTK with CMake (static libraries,
X11 backend, tests/fluid/OpenGL disabled), compiles the SQLite amalgamation
with the system C compiler, then links the application against those freshly
built libraries. Build artifacts go to `.build-full/`; set `CLEAN=0` to reuse
them.

GNU Wget 1.25.0 is included as reference/downloader source: it is **not**
compiled or linked into CarCalc, and the government-price code still uses the
platform HTTP backend (WinHTTP on Windows, libcurl elsewhere). Its full GPLv3
source is bundled so the downloader can be built locally without fetching it
again.

When upgrading a dependency, replace the corresponding directory here, update
the versions and checksums in this file, in [`../README.md`](../README.md) and
in [`../THIRD_PARTY_LICENSES.md`](../THIRD_PARTY_LICENSES.md), and verify that
`./build_full.sh` still succeeds.
