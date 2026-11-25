#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

CXX="${CXX:-g++}"
"$CXX" -fsanitize=address -g -o prog main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp language.cpp government_prices.cpp car_calc_ui.cxx -lsqlite3 -lcurl $(fltk-config --cxxflags) $(fltk-config --ldflags)
