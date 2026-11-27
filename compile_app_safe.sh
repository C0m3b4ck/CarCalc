#!/usr/bin/env bash
# AddressSanitizer build that keeps the normal binary name ./prog.
set -euo pipefail
cd "$(dirname "$0")"
source ./build_env.sh

build_env_ensure_deps

CXX="${CXX:-g++}"
"$CXX" -fsanitize=address -fno-omit-frame-pointer -g -O1 -std=c++17 -o prog \
    "${SQLITE_CFLAGS[@]}" "${FLTK_CXXFLAGS[@]}" "${CURL_CFLAGS[@]}" \
    main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp language.cpp \
    government_prices.cpp car_calc_ui.cxx \
    "${SQLITE_LIBS[@]}" "${FLTK_LDFLAGS[@]}" "${CURL_LIBS[@]}"
