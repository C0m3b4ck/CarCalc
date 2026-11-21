#!/usr/bin/env bash
# Cross-compile CarCalc into a standalone 64-bit Windows .exe from Linux/macOS.
#
# Usage:
#   ./compile_windows.sh                 # produces ./CarCalc.exe
#   OUT=~/CarCalc.exe ./compile_windows.sh
#
# Optional overrides:
#   CXX, CC        - cross compiler (default: x86_64-w64-mingw32-g++/gcc)
#   FLTK_WIN_DIR   - directory with Windows FLTK 1.3/1.4 (FL/ + lib/libfltk.a)
#   CARCALC_DEPS   - where cached dependencies are stored (default: ./.win-deps)
#
# SQLite is compiled from the vendored amalgamation in vendor/sqlite-3.54.1/
# when available; FLTK uses a prebuilt MinGW-w64 static library (see below).
#
# Requires: x86_64-w64-mingw32-g++, unzip, and curl/wget (only if deps are missing).

set -euo pipefail
cd "$(dirname "$0")"

CXX="${CXX:-x86_64-w64-mingw32-g++}"
CC="${CC:-x86_64-w64-mingw32-gcc}"
OUT="${OUT:-$PWD/CarCalc.exe}"
DEPS="${CARCALC_DEPS:-$PWD/.win-deps}"

for tool in "$CXX" "$CC" unzip; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2
        echo "Install with: sudo apt install g++-mingw-w64-x86-64 unzip" >&2
        exit 1
    }
done

mkdir -p "$DEPS"

# ---------------------------------------------------------------------------
# 1. Windows FLTK 1.3 static library + headers
# ---------------------------------------------------------------------------
if [[ -n "${FLTK_WIN_DIR:-}" ]]; then
    FLTK_DIR="$FLTK_WIN_DIR"
else
    FLTK_DIR="$DEPS/fltk-1.3.9"
fi

if [[ ! -f "$FLTK_DIR/FL/Fl.H" || ! -f "$FLTK_DIR/lib/libfltk.a" ]]; then
    echo "==> Preparing Windows FLTK 1.3 in $FLTK_DIR"
    mkdir -p "$FLTK_DIR"

    # Prefer the local prebuilt MinGW-w64 bundle if present on this machine.
    fltk_zip=""
    for candidate in \
        "${FLTK_WIN_ZIP:-}" \
        /home/sb3x/Toshiba-dump/fltk-1.3.9-compiled.zip \
        "$HOME/Toshiba-dump/fltk-1.3.9-compiled.zip" \
        "$PWD/../Toshiba-dump/fltk-1.3.9-compiled.zip"
    do
        if [[ -n "$candidate" && -f "$candidate" ]]; then
            fltk_zip="$candidate"
            break
        fi
    done

    if [[ -n "$fltk_zip" ]]; then
        echo "    using prebuilt bundle: $fltk_zip"
        unzip -o -q "$fltk_zip" \
            'fltk-1.3.9/FL/*' \
            'fltk-1.3.9/config.h' \
            'fltk-1.3.9/lib/libfltk.a' \
            -d "$DEPS"
    else
        echo "error: no Windows FLTK found." >&2
        echo "Set FLTK_WIN_DIR to a FLTK 1.3 tree built with MinGW-w64," >&2
        echo "or FLTK_WIN_ZIP to a prebuilt zip, or place it in ~/Toshiba-dump/." >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 2. SQLite amalgamation (compiled into the .exe, no sqlite3.dll needed)
# ---------------------------------------------------------------------------
VENDORED_SQLITE="$PWD/vendor/sqlite-3.54.1"
SQLITE_DIR="$DEPS/sqlite"
if [[ -f "$VENDORED_SQLITE/sqlite3.c" && -f "$VENDORED_SQLITE/sqlite3.h" ]]; then
    SQLITE_DIR="$VENDORED_SQLITE"
    echo "==> Using vendored SQLite 3.54.1 from $SQLITE_DIR"
else
    if [[ ! -f "$SQLITE_DIR/sqlite3.c" || ! -f "$SQLITE_DIR/sqlite3.h" ]]; then
        echo "==> Preparing SQLite amalgamation in $SQLITE_DIR"
        mkdir -p "$SQLITE_DIR"

        if [[ -f /home/sb3x/qmark-build/sqlite3.c && -f /home/sb3x/qmark-build/sqlite3.h ]]; then
            echo "    using local amalgamation"
            cp /home/sb3x/qmark-build/sqlite3.c /home/sb3x/qmark-build/sqlite3.h "$SQLITE_DIR/"
        else
            url="https://www.sqlite.org/2026/sqlite-amalgamation-3540100.zip"
            zip="$DEPS/sqlite-amalgamation-3540100.zip"
            echo "    downloading $url"
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "$url" -o "$zip"
            elif command -v wget >/dev/null 2>&1; then
                wget -q "$url" -O "$zip"
            else
                echo "error: need curl or wget to fetch SQLite" >&2
                exit 1
            fi
            unzip -o -q "$zip" -d "$DEPS"
            cp "$DEPS/sqlite-amalgamation-3540100/sqlite3.c" \
               "$DEPS/sqlite-amalgamation-3540100/sqlite3.h" \
               "$SQLITE_DIR/"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 3. Build
# ---------------------------------------------------------------------------
echo "==> Compiling sqlite3.c"
"$CC" -O2 -DSQLITE_THREADSAFE=1 -DSQLITE_OMIT_LOAD_EXTENSION \
    -I"$SQLITE_DIR" -c "$SQLITE_DIR/sqlite3.c" -o "$DEPS/sqlite3.o"

echo "==> Linking $OUT"
"$CXX" -O2 -std=c++17 -static -mwindows \
    -I"$FLTK_DIR" -I"$SQLITE_DIR" \
    -DWIN32 -DUSE_OPENGL32 \
    -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 \
    main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp language.cpp government_prices.cpp car_calc_ui.cxx \
    "$DEPS/sqlite3.o" "$FLTK_DIR/lib/libfltk.a" \
    -lole32 -luuid -lcomctl32 -lwinhttp \
    -o "$OUT"

OUT_DIR="$(dirname "$OUT")"

# The program opens the selected language database from its working directory.
for db in cars.db cars_en.db cars_pl.db; do
    if [[ -f "$db" && ! -f "$OUT_DIR/$db" ]]; then
        cp "$db" "$OUT_DIR/$db"
        echo "==> Copied $db next to $OUT"
    fi
done

# Ship autodetected translation files alongside the binary.
if [[ -d translations && ! -d "$OUT_DIR/translations" ]]; then
    cp -r translations "$OUT_DIR/translations"
    echo "==> Copied translations/ next to $OUT"
fi

# Ship third-party license notices alongside the binary.
if [[ -f THIRD_PARTY_LICENSES.md && "$OUT_DIR" != "$PWD" ]]; then
    mkdir -p "$OUT_DIR/licenses"
    cp -u THIRD_PARTY_LICENSES.md "$OUT_DIR/"
    cp -u licenses/* "$OUT_DIR/licenses/"
    echo "==> Copied license notices next to $OUT"
fi

echo "Done: $OUT"
file "$OUT" || true
