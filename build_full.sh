#!/usr/bin/env bash
# Build CarCalc entirely from the bundled external dependency sources.
#
# FLTK 1.4.5 and SQLite 3.54.1 are compiled from external_libraries/ into BUILD_DIR;
# no system FLTK or SQLite development package is required at link time.
# System libcurl headers are still needed for the government price feature.
#
# Usage:
#   ./build_full.sh                 # rebuilds dependencies and produces ./prog
#   OUT=~/CarCalc ./build_full.sh   # custom output path
#   BUILD_DIR=/tmp/cc-build ./build_full.sh
#   CLEAN=0 ./build_full.sh         # reuse an existing dependency build tree
#   JOBS=2 ./build_full.sh          # limit parallel compilation

set -euo pipefail
cd "$(dirname "$0")"

ROOT="$PWD"
OUT="${OUT:-$ROOT/prog}"
BUILD_DIR="${BUILD_DIR:-$ROOT/.build-full}"
FLTK_SRC="$ROOT/external_libraries/fltk-1.4.5"
SQLITE_SRC="$ROOT/external_libraries/sqlite-3.54.1"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
CLEAN="${CLEAN:-1}"

CC="${CC:-gcc}"
CXX="${CXX:-g++}"
AR="${AR:-ar}"

for tool in cmake "$CC" "$CXX" "$AR"; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2
        exit 1
    }
done

for required in "$FLTK_SRC/CMakeLists.txt" "$FLTK_SRC/FL/Fl.H" \
                "$SQLITE_SRC/sqlite3.c" "$SQLITE_SRC/sqlite3.h"; do
    if [[ ! -f "$required" ]]; then
        echo "error: missing bundled source: $required" >&2
        echo "       restore external_libraries/ from the repository before building." >&2
        exit 1
    fi
done

FLTK_VERSION=$(<"$FLTK_SRC/fltk_version.dat")
SQLITE_VERSION=$(awk '/^#define SQLITE_VERSION / { gsub(/"/, "", $3); print $3; exit }' \
    "$SQLITE_SRC/sqlite3.h")

echo "==> CarCalc full build (FLTK $FLTK_VERSION, SQLite $SQLITE_VERSION)"

if [[ "$CLEAN" == "1" ]]; then
    echo "==> Cleaning dependency build tree: $BUILD_DIR"
    rm -rf "$BUILD_DIR/fltk" "$BUILD_DIR/sqlite"
fi
mkdir -p "$BUILD_DIR/fltk" "$BUILD_DIR/sqlite"

echo "==> Configuring FLTK $FLTK_VERSION from $FLTK_SRC"
cmake -S "$FLTK_SRC" -B "$BUILD_DIR/fltk" \
    -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DFLTK_BUILD_SHARED_LIBS=OFF \
    -DFLTK_BUILD_TEST=OFF \
    -DFLTK_BUILD_EXAMPLES=OFF \
    -DFLTK_BUILD_FLUID=OFF \
    -DFLTK_BUILD_FLTK_OPTIONS=OFF \
    -DFLTK_BUILD_GL=OFF \
    -DFLTK_BACKEND_WAYLAND=OFF \
    -DFLTK_BACKEND_X11=ON

echo "==> Compiling FLTK $FLTK_VERSION ($JOBS jobs)"
cmake --build "$BUILD_DIR/fltk" --parallel "$JOBS"

echo "==> Compiling SQLite $SQLITE_VERSION amalgamation"
"$CC" -O2 -DSQLITE_THREADSAFE=1 -DSQLITE_OMIT_LOAD_EXTENSION \
    -I"$SQLITE_SRC" -c "$SQLITE_SRC/sqlite3.c" -o "$BUILD_DIR/sqlite/sqlite3.o"
"$AR" rcs "$BUILD_DIR/sqlite/libsqlite3.a" "$BUILD_DIR/sqlite/sqlite3.o"

FLTK_CONFIG="$BUILD_DIR/fltk/fltk-config"
read -r -a FLTK_CXXFLAGS <<<"$(bash "$FLTK_CONFIG" --cxxflags)"
read -r -a FLTK_LDFLAGS <<<"$(bash "$FLTK_CONFIG" --ldflags)"

CURL_CFLAGS=()
CURL_LIBS=(-lcurl)
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libcurl; then
    read -r -a CURL_CFLAGS <<<"$(pkg-config --cflags libcurl)"
    read -r -a CURL_LIBS <<<"$(pkg-config --libs libcurl)"
fi

SOURCES=(
    main.cpp
    business_layer.cpp
    io_layer.cpp
    sql_layer.cpp
    language.cpp
    government_prices.cpp
    car_calc_ui.cxx
)

echo "==> Linking $OUT"
"$CXX" -O2 -std=c++17 \
    -I"$SQLITE_SRC" "${FLTK_CXXFLAGS[@]}" "${CURL_CFLAGS[@]}" \
    "${SOURCES[@]}" \
    -L"$BUILD_DIR/sqlite" -lsqlite3 \
    "${FLTK_LDFLAGS[@]}" "${CURL_LIBS[@]}" \
    -o "$OUT"

echo "Done: $OUT"
