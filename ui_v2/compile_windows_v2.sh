#!/usr/bin/env bash
# Cross-compile the isolated v2 GUI for Windows. The original root UI is not
# compiled or modified by this script.
set -euo pipefail
cd "$(dirname "$0")"

ROOT="$PWD/.."
CXX="${CXX:-x86_64-w64-mingw32-g++}"
CC="${CC:-x86_64-w64-mingw32-gcc}"
OUT="${OUT:-$PWD/CarCalc_v2.exe}"
DEPS="${CARCALC_DEPS:-$ROOT/.win-deps}"
FLTK_DIR="${FLTK_WIN_DIR:-$DEPS/fltk-1.3.9}"
SQLITE_DIR="$ROOT/external_libraries/sqlite-3.54.1"

for tool in "$CXX" "$CC"; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2
        echo "Install the MinGW-w64 cross compiler with your package manager," >&2
        echo "or set CXX/CC to compatible tools." >&2
        exit 1
    }
done

if [[ ! -f "$FLTK_DIR/FL/Fl.H" || ! -f "$FLTK_DIR/lib/libfltk.a" ]]; then
    echo "error: no Windows FLTK found in $FLTK_DIR" >&2
    echo "Run the root compile_windows.sh once, or set FLTK_WIN_DIR." >&2
    exit 1
fi
if [[ ! -f "$SQLITE_DIR/sqlite3.c" || ! -f "$SQLITE_DIR/sqlite3.h" ]]; then
    echo "error: bundled SQLite sources not found in $SQLITE_DIR" >&2
    exit 1
fi
for generated in car_calc_ui_v2.cxx car_calc_ui_v2.h; do
    if [[ ! -f "$generated" ]]; then
        echo "error: missing $generated; run compile_ui_v2.sh once" >&2
        exit 1
    fi
done

mkdir -p "$DEPS"
if [[ ! -f "$DEPS/sqlite3.o" || "$SQLITE_DIR/sqlite3.c" -nt "$DEPS/sqlite3.o" ]]; then
    echo "==> Compiling sqlite3.c"
    "$CC" -O2 -DSQLITE_THREADSAFE=1 -DSQLITE_OMIT_LOAD_EXTENSION \
        -I"$SQLITE_DIR" -c "$SQLITE_DIR/sqlite3.c" -o "$DEPS/sqlite3.o"
fi

echo "==> Linking $OUT"
"$CXX" -O2 -std=c++17 -static -mwindows \
    -I"$FLTK_DIR" -I"$SQLITE_DIR" -I"$ROOT" -I"$PWD" \
    -DWIN32 -DUSE_OPENGL32 \
    -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 \
    main_v2.cpp car_calc_ui_v2.cxx ui_v2_helpers.cpp \
    "$ROOT/business_layer.cpp" "$ROOT/io_layer.cpp" "$ROOT/sql_layer.cpp" \
    "$ROOT/language.cpp" "$ROOT/government_prices.cpp" \
    "$DEPS/sqlite3.o" "$FLTK_DIR/lib/libfltk.a" \
    -lole32 -luuid -lcomctl32 -lwinhttp \
    -o "$OUT"

OUT_DIR="$(dirname "$OUT")"
for db in cars.db cars_en.db cars_pl.db; do
    if [[ -f "$ROOT/$db" && ! -f "$OUT_DIR/$db" ]]; then
        cp "$ROOT/$db" "$OUT_DIR/$db"
    fi
done
if [[ -d "$ROOT/translations" && ! -d "$OUT_DIR/translations" ]]; then
    cp -r "$ROOT/translations" "$OUT_DIR/translations"
fi

echo "Done: $OUT"
file "$OUT" || true
