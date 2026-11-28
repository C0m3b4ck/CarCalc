#!/usr/bin/env bash
# Cross-compile CarCalc into a standalone 64-bit Windows .exe from Linux/macOS.
#
# Usage:
#   ./compile_windows.sh                 # produces ./CarCalc.exe
#   OUT=~/CarCalc.exe ./compile_windows.sh
#
# Optional overrides:
#   CXX, CC              - cross compiler (default: derived from WINDOWS_TRIPLE)
#   WINDOWS_TRIPLE       - MinGW target prefix (default: x86_64-w64-mingw32)
#   WINDOWS_PROCESSOR    - CMake processor name (default: x86_64)
#   WINDOWS_WINNT        - _WIN32_WINNT value (default: 0x0600)
#   WINDOWS_SUBSYSTEM_MAJOR/MINOR - PE subsystem version (default: 6/0)
#   FLTK_WIN_DIR         - directory with a matching Windows FLTK 1.4.5 tree
#   SQLITE_AMALGAMATION_DIR - directory containing sqlite3.c and sqlite3.h
#   CARCALC_DEPS         - where cached dependencies are stored (default: ./.win-deps)
#
# SQLite is compiled from the bundled amalgamation in external_libraries/sqlite-3.54.1/
# when available; FLTK 1.4.5 is cross-built from the bundled source into .win-deps/.
#
# Requires: a matching MinGW-w64 cross compiler and CMake.

set -euo pipefail
cd "$(dirname "$0")"

WINDOWS_TRIPLE="${WINDOWS_TRIPLE:-x86_64-w64-mingw32}"
WINDOWS_PROCESSOR="${WINDOWS_PROCESSOR:-x86_64}"
WINDOWS_WINNT="${WINDOWS_WINNT:-0x0600}"
WINDOWS_SUBSYSTEM_MAJOR="${WINDOWS_SUBSYSTEM_MAJOR:-6}"
WINDOWS_SUBSYSTEM_MINOR="${WINDOWS_SUBSYSTEM_MINOR:-0}"
CXX="${CXX:-${WINDOWS_TRIPLE}-g++}"
CC="${CC:-${WINDOWS_TRIPLE}-gcc}"
WINDRES="${WINDRES:-${WINDOWS_TRIPLE}-windres}"
OUT="${OUT:-$PWD/CarCalc.exe}"
DEPS="${CARCALC_DEPS:-$PWD/.win-deps}"

for tool in "$CXX" "$CC" "$WINDRES" cmake; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2
        echo "Install the MinGW-w64 cross compiler for $WINDOWS_TRIPLE and CMake," >&2
        echo "or set CXX/CC/WINDRES to compatible tools." >&2
        exit 1
    }
done

mkdir -p "$DEPS"

# ---------------------------------------------------------------------------
# 1. Windows FLTK 1.4.5 static library + headers
#    The UI is generated with FLUID 1.4.5, so the runtime library must match.
# ---------------------------------------------------------------------------
FLTK_SOURCE="$PWD/external_libraries/fltk-1.4.5"
FLTK_INCLUDES=()

if [[ -n "${FLTK_WIN_DIR:-}" ]]; then
    FLTK_DIR="$FLTK_WIN_DIR"
    FLTK_INCLUDES=(-I"$FLTK_DIR")
    if [[ ! -f "$FLTK_DIR/FL/Fl.H" || ! -f "$FLTK_DIR/lib/libfltk.a" ]]; then
        echo "error: FLTK_WIN_DIR is missing FL/Fl.H or lib/libfltk.a: $FLTK_DIR" >&2
        exit 1
    fi
else
    if [[ "$WINDOWS_TRIPLE" == "x86_64-w64-mingw32" && "$WINDOWS_WINNT" == "0x0600" ]]; then
        FLTK_DIR="$DEPS/fltk-1.4.5"
    else
        FLTK_DIR="$DEPS/fltk-1.4.5-$WINDOWS_TRIPLE-winnt${WINDOWS_WINNT#0x}"
    fi
    FLTK_INCLUDES=(-I"$FLTK_DIR" -I"$FLTK_SOURCE")
    if [[ ! -f "$FLTK_SOURCE/CMakeLists.txt" || ! -f "$FLTK_SOURCE/FL/Fl.H" ]]; then
        echo "error: missing bundled FLTK source: $FLTK_SOURCE" >&2
        exit 1
    fi

    if [[ ! -f "$FLTK_DIR/lib/libfltk.a" ]]; then
        echo "==> Building bundled FLTK 1.4.5 for $WINDOWS_TRIPLE"
        mkdir -p "$DEPS"
        TOOLCHAIN_FILE="$DEPS/toolchain-$WINDOWS_TRIPLE-winnt${WINDOWS_WINNT#0x}.cmake"
        cat > "$TOOLCHAIN_FILE" <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR $WINDOWS_PROCESSOR)
set(CMAKE_C_COMPILER $CC)
set(CMAKE_CXX_COMPILER $CXX)
set(CMAKE_RC_COMPILER $WINDRES)
set(CMAKE_FIND_ROOT_PATH /usr/$WINDOWS_TRIPLE)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
        cmake -S "$FLTK_SOURCE" -B "$FLTK_DIR" \
            -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_FLAGS=-D_WIN32_WINNT=$WINDOWS_WINNT \
            -DCMAKE_CXX_FLAGS=-D_WIN32_WINNT=$WINDOWS_WINNT \
            -DFLTK_BUILD_SHARED_LIBS=OFF \
            -DFLTK_BUILD_FLUID=OFF \
            -DFLTK_BUILD_TEST=OFF \
            -DFLTK_BUILD_EXAMPLES=OFF \
            -DFLTK_BUILD_FLTK_OPTIONS=OFF \
            -DFLTK_BUILD_FORMS=OFF \
            -DFLTK_BUILD_GL=OFF \
            -DFLTK_GRAPHICS_GDIPLUS=OFF \
            -DFLTK_OPTION_PRINT_SUPPORT=OFF \
            -DFLTK_USE_SYSTEM_LIBJPEG=OFF \
            -DFLTK_USE_SYSTEM_LIBPNG=OFF \
            -DFLTK_USE_SYSTEM_ZLIB=OFF
        cmake --build "$FLTK_DIR" --parallel "${JOBS:-4}" --target fltk
    fi
fi

# ---------------------------------------------------------------------------
# 2. SQLite amalgamation (compiled into the .exe, no sqlite3.dll needed)
# ---------------------------------------------------------------------------
EXTERNAL_SQLITE="$PWD/external_libraries/sqlite-3.54.1"
SQLITE_DIR="$DEPS/sqlite"
if [[ -f "$EXTERNAL_SQLITE/sqlite3.c" && -f "$EXTERNAL_SQLITE/sqlite3.h" ]]; then
    SQLITE_DIR="$EXTERNAL_SQLITE"
    echo "==> Using bundled SQLite 3.54.1 from $SQLITE_DIR"
else
    if [[ ! -f "$SQLITE_DIR/sqlite3.c" || ! -f "$SQLITE_DIR/sqlite3.h" ]]; then
        echo "==> Preparing SQLite amalgamation in $SQLITE_DIR"
        mkdir -p "$SQLITE_DIR"

        sqlite_candidates=()
        if [[ -n "${SQLITE_AMALGAMATION_DIR:-}" ]]; then
            sqlite_candidates+=("$SQLITE_AMALGAMATION_DIR")
        fi
        sqlite_candidates+=("$DEPS/sqlite" "$DEPS/sqlite-amalgamation-3540100")
        if [[ -n "${HOME:-}" ]]; then
            sqlite_candidates+=("$HOME/.cache/carcalc/sqlite-3.54.1")
        fi

        found_amalgamation=""
        for candidate in "${sqlite_candidates[@]}"; do
            if [[ -f "$candidate/sqlite3.c" && -f "$candidate/sqlite3.h" ]]; then
                found_amalgamation="$candidate"
                break
            fi
        done

        if [[ -n "$found_amalgamation" ]]; then
            echo "    using amalgamation from $found_amalgamation"
            cp "$found_amalgamation/sqlite3.c" "$found_amalgamation/sqlite3.h" "$SQLITE_DIR/"
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
"$CXX" -O2 -std=c++17 -static -static-libgcc -static-libstdc++ -mwindows \
    "${FLTK_INCLUDES[@]}" -I"$SQLITE_DIR" \
    -D_WIN32_WINNT=$WINDOWS_WINNT -DWIN32 -DUSE_OPENGL32 \
    -Wl,--major-subsystem-version,$WINDOWS_SUBSYSTEM_MAJOR \
    -Wl,--minor-subsystem-version,$WINDOWS_SUBSYSTEM_MINOR \
    -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 \
    main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp language.cpp government_prices.cpp car_calc_ui.cxx \
    "$DEPS/sqlite3.o" "$FLTK_DIR/lib/libfltk.a" \
    -lole32 -luuid -lcomctl32 -lws2_32 -lwinspool \
    -lgdi32 -luser32 -lkernel32 -lshell32 -lwinhttp \
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
