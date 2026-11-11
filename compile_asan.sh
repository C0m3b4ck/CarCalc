#!/bin/bash
# Build CarCalc with AddressSanitizer + LeakSanitizer and run it using the
# suppressions in lsan.supp (known-benign leaks from fltk and sqlite3).
#
# Usage: ./compile_asan.sh          build, then run (if a display is available)
#        ./compile_asan.sh --build  build only
#
# The plain, non-ASan binary stays untouched in ./prog (see compile_app.sh).

set -euo pipefail
cd "$(dirname "$0")"

OUT=prog_asan

g++ -o "$OUT" main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp car_calc_ui.cxx \
    -lsqlite3 \
    $(fltk-config --cxxflags) $(fltk-config --ldflags) \
    -fsanitize=address -fno-omit-frame-pointer -g -O1

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
