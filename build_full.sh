#!/bin/bash
g++ -o prog main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp car_calc_ui.cxx -lsqlite3 $(fltk-config --cxxflags) $(fltk-config --ldflags)
