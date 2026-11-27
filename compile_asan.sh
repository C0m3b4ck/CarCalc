#!/bin/bash
# Build CarCalc with AddressSanitizer + LeakSanitizer and run it using the
# suppressions in lsan.supp (known-benign leaks from fltk and sqlite3).
#
# Usage: ./compile_asan.sh          build, then run (if a display is available)
#        ./compile_asan.sh --build  build only
#
# The plain, non-ASan binary stays untouched in ./prog (see compile_app.sh).
# FLTK 1.4.5 from the bundled build tree is used - system FLTK 1.3.x produces
# corrupted widget geometry with the FLUID 1.4.5 generated UI.

set -euo pipefail
cd "$(dirname "$0")"
source ./build_env.sh

build_env_ensure_deps

OUT=prog_asan

CXX="${CXX:-g++}"
"$CXX" -o "$OUT" \
    "${SQLITE_CFLAGS[@]}" "${FLTK_CXXFLAGS[@]}" "${CURL_CFLAGS[@]}" \
    main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp language.cpp \
    government_prices.cpp car_calc_ui.cxx \
    "${SQLITE_LIBS[@]}" "${FLTK_LDFLAGS[@]}" "${CURL_LIBS[@]}" \
    -fsanitize=address -fno-omit-frame-pointer -g -O1 -std=c++17

echo "Built ./$OUT (AddressSanitizer + LeakSanitizer)"

if [ "${1:-}" = "--build" ]; then
    echo "Skipping run (--build given). Start it manually with:"
    echo "  LSAN_OPTIONS=suppressions=lsan.supp ./$OUT"
    exit 0
fi

if [ ! -f lsan.supp ]; then
    echo "Warning: lsan.supp not found, leak reports will not be filtered." >&2
fi

if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    echo "Running with LSAN_OPTIONS=suppressions=lsan.supp ..."
    LSAN_OPTIONS="suppressions=lsan.supp" ./"$OUT"
else
    echo "No display available, skipping run. Start it manually with:"
    echo "  LSAN_OPTIONS=suppressions=lsan.supp ./$OUT"
fi
