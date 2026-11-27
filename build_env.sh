#!/usr/bin/env bash
# Internal helper for CarCalc build scripts. Source it; do not execute directly.
#
# It resolves the bundled FLTK 1.4.5 / SQLite 3.54.1 build tree and exports the
# compiler/linker flags needed by every local build. Using the same FLTK version
# as car_calc_ui.fl (generated with FLUID 1.4.5) is required - mixing in a system
# FLTK 1.3.x produces corrupted widget geometry and overlapping labels.

CARCALC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARCALC_BUILD_DIR="${BUILD_DIR:-$CARCALC_ROOT/.build-full}"
CARCALC_FLTK_SRC="$CARCALC_ROOT/external_libraries/fltk-1.4.5"
CARCALC_SQLITE_SRC="$CARCALC_ROOT/external_libraries/sqlite-3.54.1"
CARCALC_FLTK_CONFIG="$CARCALC_BUILD_DIR/fltk/fltk-config"
CARCALC_SQLITE_LIB="$CARCALC_BUILD_DIR/sqlite/libsqlite3.a"

build_env_read_flags() {
    if [[ ! -x "$CARCALC_FLTK_CONFIG" || ! -f "$CARCALC_SQLITE_LIB" ]]; then
        echo "error: bundled FLTK/SQLite build tree not found in $CARCALC_BUILD_DIR" >&2
        echo "       run: CLEAN=0 ./build_full.sh" >&2
        return 1
    fi

    read -r -a FLTK_CXXFLAGS <<<"$(bash "$CARCALC_FLTK_CONFIG" --cxxflags)"
    read -r -a FLTK_LDFLAGS <<<"$(bash "$CARCALC_FLTK_CONFIG" --ldflags)"

    SQLITE_CFLAGS=(-I"$CARCALC_SQLITE_SRC")
    SQLITE_LIBS=(-L"$CARCALC_BUILD_DIR/sqlite" -lsqlite3)

    CURL_CFLAGS=()
    CURL_LIBS=(-lcurl)
    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libcurl; then
        read -r -a CURL_CFLAGS <<<"$(pkg-config --cflags libcurl)"
        read -r -a CURL_LIBS <<<"$(pkg-config --libs libcurl)"
    fi
}

build_env_ensure_deps() {
    if [[ ! -x "$CARCALC_FLTK_CONFIG" || ! -f "$CARCALC_SQLITE_LIB" ]]; then
        echo "==> Bundled dependencies missing; building them from external_libraries/"
        (
            cd "$CARCALC_ROOT"
            export BUILD_DIR="$CARCALC_BUILD_DIR"
            export CLEAN=0
            export DEPS_ONLY=1
            ./build_full.sh
        )
    fi
    build_env_read_flags
}
