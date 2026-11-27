#!/usr/bin/env bash
# Quick incremental Linux build using the bundled FLTK 1.4.5 tree from
# build_full.sh (never the system FLTK 1.3.x, which breaks the generated UI).
set -euo pipefail
cd "$(dirname "$0")"
source ./build_env.sh

build_env_ensure_deps

CXX="${CXX:-g++}"
"$CXX" -O2 -std=c++17 -o prog \
    "${SQLITE_CFLAGS[@]}" "${FLTK_CXXFLAGS[@]}" "${CURL_CFLAGS[@]}" \
    main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp language.cpp \
    government_prices.cpp car_calc_ui.cxx \
    "${SQLITE_LIBS[@]}" "${FLTK_LDFLAGS[@]}" "${CURL_LIBS[@]}"
