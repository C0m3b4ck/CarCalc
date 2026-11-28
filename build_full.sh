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
#
# CARCALC_EXTRA_CFLAGS / CARCALC_EXTRA_CXXFLAGS / CARCALC_EXTRA_LDFLAGS add
# target-specific flags to cross builds (CMake, SQLite and the final link).
# CARCALC_FLTK_BACKEND_X11 selects the FLTK backend; macOS cross builds set it
# to OFF so FLTK compiles the Cocoa Objective-C++ sources.

set -euo pipefail
cd "$(dirname "$0")"
source ./build_env.sh

ROOT="$CARCALC_ROOT"
OUT="${OUT:-$ROOT/prog}"
BUILD_DIR="$CARCALC_BUILD_DIR"
FLTK_SRC="$CARCALC_FLTK_SRC"
SQLITE_SRC="$CARCALC_SQLITE_SRC"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"
CLEAN="${CLEAN:-1}"

CC="${CC:-gcc}"
CXX="${CXX:-g++}"
AR="${AR:-ar}"

# Optional cross-build support. Stage scripts can point these at a toolchain
# file and extra flags without changing the normal host build.
CMAKE_TOOLCHAIN_ARGS=()
if [[ -n "${CARCALC_CMAKE_TOOLCHAIN_FILE:-}" ]]; then
    CMAKE_TOOLCHAIN_ARGS=(-DCMAKE_TOOLCHAIN_FILE="$CARCALC_CMAKE_TOOLCHAIN_FILE")
fi
EXTRA_CFLAGS=()
if [[ -n "${CARCALC_EXTRA_CFLAGS:-}" ]]; then
    read -r -a EXTRA_CFLAGS <<<"$CARCALC_EXTRA_CFLAGS"
fi
EXTRA_CXXFLAGS=()
if [[ -n "${CARCALC_EXTRA_CXXFLAGS:-}" ]]; then
    read -r -a EXTRA_CXXFLAGS <<<"$CARCALC_EXTRA_CXXFLAGS"
fi
EXTRA_OBJCXXFLAGS=()
if [[ -n "${CARCALC_EXTRA_OBJCXXFLAGS:-}" ]]; then
    read -r -a EXTRA_OBJCXXFLAGS <<<"$CARCALC_EXTRA_OBJCXXFLAGS"
fi
EXTRA_LDFLAGS=()
if [[ -n "${CARCALC_EXTRA_LDFLAGS:-}" ]]; then
    read -r -a EXTRA_LDFLAGS <<<"$CARCALC_EXTRA_LDFLAGS"
fi
CMAKE_FLAG_ARGS=()
[[ "${#EXTRA_CFLAGS[@]}" -eq 0 ]] || CMAKE_FLAG_ARGS+=("-DCMAKE_C_FLAGS=${EXTRA_CFLAGS[*]}")
[[ "${#EXTRA_CXXFLAGS[@]}" -eq 0 ]] || CMAKE_FLAG_ARGS+=("-DCMAKE_CXX_FLAGS=${EXTRA_CXXFLAGS[*]}")
[[ "${#EXTRA_OBJCXXFLAGS[@]}" -eq 0 ]] || CMAKE_FLAG_ARGS+=("-DCMAKE_OBJCXX_FLAGS=${EXTRA_OBJCXXFLAGS[*]}")
[[ "${#EXTRA_LDFLAGS[@]}" -eq 0 ]] || CMAKE_FLAG_ARGS+=("-DCMAKE_EXE_LINKER_FLAGS=${EXTRA_LDFLAGS[*]}")

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
    "${CMAKE_TOOLCHAIN_ARGS[@]}" \
    "${CMAKE_FLAG_ARGS[@]}" \
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
    -DFLTK_BACKEND_X11="${CARCALC_FLTK_BACKEND_X11:-ON}"

echo "==> Compiling FLTK $FLTK_VERSION ($JOBS jobs)"
cmake --build "$BUILD_DIR/fltk" --parallel "$JOBS"

echo "==> Compiling SQLite $SQLITE_VERSION amalgamation"
"$CC" -O2 "${EXTRA_CFLAGS[@]}" -DSQLITE_THREADSAFE=1 -DSQLITE_OMIT_LOAD_EXTENSION \
    -I"$SQLITE_SRC" -c "$SQLITE_SRC/sqlite3.c" -o "$BUILD_DIR/sqlite/sqlite3.o"
"$AR" rcs "$BUILD_DIR/sqlite/libsqlite3.a" "$BUILD_DIR/sqlite/sqlite3.o"

build_env_read_flags

if [[ "${DEPS_ONLY:-0}" == "1" ]]; then
    echo "Done: bundled dependency tree at $BUILD_DIR"
    exit 0
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
"$CXX" -O2 -std=c++17 "${EXTRA_CXXFLAGS[@]}" \
    -I"$SQLITE_SRC" "${FLTK_CXXFLAGS[@]}" "${CURL_CFLAGS[@]}" \
    "${SOURCES[@]}" \
    -L"$BUILD_DIR/sqlite" "${EXTRA_LDFLAGS[@]}" -lsqlite3 \
    "${FLTK_LDFLAGS[@]}" "${CURL_LIBS[@]}" \
    -o "$OUT"

echo "Done: $OUT"
