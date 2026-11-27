#!/usr/bin/env bash
# Cross-compile a 32-bit, Windows 2000+ compatible CarCalc executable.
#
# Usage:
#   ./compile_windows_legacy.sh
#   OUT=~/CarCalc-legacy.exe ./compile_windows_legacy.sh
#
# Optional overrides:
#   CXX, CC, AR - MinGW-w64 i686 cross tools (default: i686-w64-mingw32-*)
#   CLEAN=1     - rebuild the cached legacy FLTK tree from scratch
#   JOBS        - parallel build jobs for FLTK (default: 4)
#
# This script is deliberately isolated from compile_windows.sh: it builds its
# own 32-bit FLTK 1.4.5 static library in .win-legacy-build/, never touches
# .win-deps/ (modern x64 Windows) or .build-full/ (Linux).
#
# Win2000 compatibility measures:
#   - PE32 GUI with subsystem version 5.00 (_WIN32_WINNT=0x0500)
#   - FLTK built without GDI+, OpenGL, print support or fluid
#   - SQLite compiled single-threaded, with a GetTickCount64 shim
#   - libstdc++ condition variables replaced by Win32 event shims

set -euo pipefail
cd "$(dirname "$0")"

CXX="${CXX:-i686-w64-mingw32-g++}"
CC="${CC:-i686-w64-mingw32-gcc}"
AR="${AR:-i686-w64-mingw32-ar}"
CMAKE="${CMAKE:-cmake}"
OUT="${OUT:-$PWD/CarCalc-legacy.exe}"
DEPS="${CARCALC_LEGACY_DEPS:-$PWD/.win-legacy-deps}"
BUILD_DIR="${CARCALC_LEGACY_BUILD:-$PWD/.win-legacy-build}"
FLTK_SOURCE="$PWD/external_libraries/fltk-1.4.5"
SQLITE_DIR="$PWD/external_libraries/sqlite-3.54.1"
JOBS="${JOBS:-4}"

for tool in "$CXX" "$CC" "$AR" "$CMAKE"; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "error: missing tool: $tool" >&2
        echo "Install gcc-mingw-w64-i686 and g++-mingw-w64-i686." >&2
        exit 1
    }
done

if [[ ! -f "$FLTK_SOURCE/FL/Fl.H" ]]; then
    echo "error: missing bundled FLTK source: $FLTK_SOURCE" >&2
    exit 1
fi
if [[ ! -f "$SQLITE_DIR/sqlite3.c" || ! -f "$SQLITE_DIR/sqlite3.h" ]]; then
    echo "error: missing bundled SQLite amalgamation: $SQLITE_DIR" >&2
    exit 1
fi

if [[ "${CLEAN:-0}" == "1" ]]; then
    rm -rf "$DEPS" "$BUILD_DIR"
fi
mkdir -p "$DEPS/gthr" "$BUILD_DIR"

# ---------------------------------------------------------------------------
# 1. Cross toolchain and Win2000 compatibility shims
# ---------------------------------------------------------------------------
cat > "$DEPS/toolchain-i686-w2k.cmake" <<'EOF'
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86)
set(CMAKE_C_COMPILER i686-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER i686-w64-mingw32-g++)
set(CMAKE_RC_COMPILER i686-w64-mingw32-windres)
set(CMAKE_FIND_ROOT_PATH /usr/i686-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

cat > "$DEPS/win2000_sqlite_shim.h" <<'EOF'
#ifndef CARCALC_WIN2000_SQLITE_SHIM_H
#define CARCALC_WIN2000_SQLITE_SHIM_H
#include <windows.h>
ULONGLONG WINAPI carcalc_GetTickCount64(void);
#define GetTickCount64 carcalc_GetTickCount64
#endif
EOF

cat > "$DEPS/win2000_sqlite_shim.c" <<'EOF'
#include "win2000_sqlite_shim.h"

/* Windows 2000 has no GetTickCount64. SQLite calls it through its syscall
   table, so wrap GetTickCount and carry the 32-bit overflow explicitly. */
ULONGLONG WINAPI carcalc_GetTickCount64(void) {
    static DWORD high = 0;
    static DWORD previous = 0;
    DWORD now = GetTickCount();
    if (now < previous) ++high;
    previous = now;
    return ((ULONGLONG)high << 32) | now;
}
EOF

cat > "$DEPS/win2000_gthr_shim.cxx" <<'EOF'
#include <time.h>
#include <windows.h>

/* MinGW-w64's default gthread condition variables import Vista APIs.
   This shim uses only Win2000 APIs and is linked before libgcc so the
   Vista-based gthr-win32-cond.o is never pulled in. */
extern "C" {

struct CarCalcCondVar {
    void *Ptr;
};

struct CarCalcCriticalSection {
    void *DebugInfo;
    int LockCount;
    int RecursionCount;
    void *OwningThread;
    void *LockSemaphore;
    void *SpinCount;
};

void __gthr_win32_cond_init_function(CarCalcCondVar *cond) {
    if (!cond) return;
    cond->Ptr = CreateEventA(nullptr, FALSE, FALSE, nullptr);
}

int __gthr_win32_cond_broadcast(CarCalcCondVar *cond) {
    return cond && cond->Ptr && SetEvent(static_cast<HANDLE>(cond->Ptr)) ? 0 : -1;
}

int __gthr_win32_cond_signal(CarCalcCondVar *cond) {
    return cond && cond->Ptr && SetEvent(static_cast<HANDLE>(cond->Ptr)) ? 0 : -1;
}

int __gthr_win32_cond_wait(CarCalcCondVar *cond, CarCalcCriticalSection *mutex) {
    if (!cond || !cond->Ptr || !mutex) return -1;
    LeaveCriticalSection(reinterpret_cast<CRITICAL_SECTION *>(mutex));
    DWORD result = WaitForSingleObject(static_cast<HANDLE>(cond->Ptr), INFINITE);
    EnterCriticalSection(reinterpret_cast<CRITICAL_SECTION *>(mutex));
    return result == WAIT_OBJECT_0 ? 0 : -1;
}

int __gthr_win32_cond_timedwait(CarCalcCondVar *cond, CarCalcCriticalSection *mutex,
                                const timespec *abs_time) {
    if (!cond || !cond->Ptr || !mutex || !abs_time) return -1;

    FILETIME filetime = {};
    GetSystemTimeAsFileTime(&filetime);
    ULARGE_INTEGER now = {};
    now.LowPart = filetime.dwLowDateTime;
    now.HighPart = filetime.dwHighDateTime;

    ULARGE_INTEGER target = {};
    target.QuadPart = (static_cast<ULONGLONG>(abs_time->tv_sec) + 11644473600ULL) * 10000000ULL
                    + static_cast<ULONGLONG>(abs_time->tv_nsec) / 100ULL;

    DWORD wait_ms = 0;
    if (target.QuadPart > now.QuadPart)
        wait_ms = static_cast<DWORD>((target.QuadPart - now.QuadPart) / 10000ULL);

    LeaveCriticalSection(reinterpret_cast<CRITICAL_SECTION *>(mutex));
    DWORD result = WaitForSingleObject(static_cast<HANDLE>(cond->Ptr), wait_ms);
    EnterCriticalSection(reinterpret_cast<CRITICAL_SECTION *>(mutex));
    return result == WAIT_OBJECT_0 ? 0 : 1;
}

} // extern "C"
EOF

LIBGCC="$("$CXX" -print-file-name=libgcc.a)"
if [[ ! -f "$LIBGCC" ]]; then
    echo "error: libgcc not found: $LIBGCC" >&2
    exit 1
fi
if [[ ! -f "$DEPS/gthr/gthr-win32.o" ]]; then
    echo "==> Extracting non-Vista gthread object from $LIBGCC"
    (cd "$DEPS/gthr" && "$AR" x "$LIBGCC" gthr-win32.o)
fi

# ---------------------------------------------------------------------------
# 2. 32-bit FLTK 1.4.5 static library
# ---------------------------------------------------------------------------
FLTK_BUILD="$BUILD_DIR/fltk"
if [[ ! -f "$FLTK_BUILD/lib/libfltk.a" ]]; then
    echo "==> Configuring 32-bit FLTK 1.4.5 for Windows 2000"
    "$CMAKE" -S "$FLTK_SOURCE" -B "$FLTK_BUILD" \
        -DCMAKE_TOOLCHAIN_FILE="$DEPS/toolchain-i686-w2k.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS=-D_WIN32_WINNT=0x0500 \
        -DCMAKE_CXX_FLAGS=-D_WIN32_WINNT=0x0500 \
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

    echo "==> Building 32-bit FLTK 1.4.5"
    "$CMAKE" --build "$FLTK_BUILD" --parallel "$JOBS" --target fltk
fi

# ---------------------------------------------------------------------------
# 3. SQLite and shims
# ---------------------------------------------------------------------------
echo "==> Compiling SQLite 3.54.1 with Win2000 shims"
"$CC" -O2 -D_WIN32_WINNT=0x0500 -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION \
    -include "$DEPS/win2000_sqlite_shim.h" -I"$SQLITE_DIR" \
    -c "$SQLITE_DIR/sqlite3.c" -o "$DEPS/sqlite3.o"

"$CC" -O2 -D_WIN32_WINNT=0x0500 -I"$DEPS" \
    -c "$DEPS/win2000_sqlite_shim.c" -o "$DEPS/win2000_sqlite_shim.o"

"$CXX" -O2 -D_WIN32_WINNT=0x0500 \
    -c "$DEPS/win2000_gthr_shim.cxx" -o "$DEPS/win2000_gthr_shim.o"

# ---------------------------------------------------------------------------
# 4. Link the application
# ---------------------------------------------------------------------------
echo "==> Linking $OUT"
"$CXX" -O2 -std=c++17 -static -static-libgcc -static-libstdc++ -mwindows \
    -D_WIN32_WINNT=0x0500 -DWIN32 -DUSE_OPENGL32 \
    -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 \
    -I"$FLTK_BUILD" -I"$FLTK_SOURCE" -I"$SQLITE_DIR" \
    "$DEPS/gthr/gthr-win32.o" "$DEPS/win2000_gthr_shim.o" \
    main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp language.cpp \
    government_prices.cpp car_calc_ui.cxx \
    "$DEPS/sqlite3.o" "$DEPS/win2000_sqlite_shim.o" \
    "$FLTK_BUILD/lib/libfltk.a" \
    -Wl,--major-subsystem-version,5 -Wl,--minor-subsystem-version,0 \
    -lole32 -luuid -lcomctl32 -lws2_32 -lwinspool \
    -lgdi32 -luser32 -lkernel32 -lshell32 -lwinhttp \
    -o "$OUT"

OUT_DIR="$(dirname "$OUT")"
for db in cars.db cars_en.db cars_pl.db; do
    if [[ -f "$db" && ! -f "$OUT_DIR/$db" ]]; then
        cp "$db" "$OUT_DIR/$db"
        echo "==> Copied $db next to $OUT"
    fi
done

if [[ -d translations && ! -d "$OUT_DIR/translations" ]]; then
    cp -r translations "$OUT_DIR/translations"
    echo "==> Copied translations/ next to $OUT"
fi

if [[ -f THIRD_PARTY_LICENSES.md && "$OUT_DIR" != "$PWD" ]]; then
    mkdir -p "$OUT_DIR/licenses"
    cp -u THIRD_PARTY_LICENSES.md "$OUT_DIR/"
    cp -u licenses/* "$OUT_DIR/licenses/"
    echo "==> Copied license notices next to $OUT"
fi

echo "Done: $OUT"
file "$OUT" || true
