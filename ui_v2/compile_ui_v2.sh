#!/usr/bin/env bash
# Build the isolated v2 GUI. The existing root UI (car_calc_ui.fl/.cxx/.h)
# is intentionally NOT compiled or modified by this script.
set -euo pipefail
cd "$(dirname "$0")"

ROOT="$PWD/.."
OUT="${OUT:-$PWD/CarCalc_v2}"
FLUID="${FLUID:-fluid}"

command -v "$FLUID" >/dev/null 2>&1 || {
    echo "error: missing FLUID tool: $FLUID" >&2
    echo "Set FLUID to a FLUID 1.3/1.4 executable." >&2
    exit 1
}

echo "==> Generating v2 UI from car_calc_ui_v2.fl"
if [[ -n "${FLUID_WORK_DIR:-}" ]]; then
    WORK_DIR="$FLUID_WORK_DIR"
    TEMP_WORK=0
else
    WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/carcalc-ui-v2-fluid.XXXXXX")"
    TEMP_WORK=1
fi
cleanup() {
    if [[ "$TEMP_WORK" == "1" ]]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

mkdir -p "$WORK_DIR"
cp car_calc_ui_v2.fl "$WORK_DIR/"
(cd "$WORK_DIR" && "$FLUID" -c car_calc_ui_v2.fl)
cp "$WORK_DIR/car_calc_ui_v2.cxx" .
cp "$WORK_DIR/car_calc_ui_v2.h" .

echo "==> Linking $OUT"
g++ -std=c++17 -O2 -I"$ROOT" -I. \
    main_v2.cpp car_calc_ui_v2.cxx ui_v2_helpers.cpp \
    "$ROOT/business_layer.cpp" "$ROOT/io_layer.cpp" "$ROOT/sql_layer.cpp" \
    "$ROOT/language.cpp" "$ROOT/government_prices.cpp" \
    -lsqlite3 -lcurl $(fltk-config --cxxflags) $(fltk-config --ldflags) \
    -o "$OUT"

# The app reads DBs and translations relative to the working directory.
for db in cars.db cars_en.db cars_pl.db; do
    if [[ -f "$ROOT/$db" && ! -f "$PWD/$db" ]]; then
        cp "$ROOT/$db" "$PWD/$db"
    fi
done
if [[ -d "$ROOT/translations" && ! -d "$PWD/translations" ]]; then
    cp -r "$ROOT/translations" "$PWD/translations"
fi

echo "Done: $OUT"
