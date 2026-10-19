g++ -o prog main.cpp business_layer.cpp io_layer.cpp car_calc_ui.cxx $(fltk-config --cxxflags) $(fltk-config --ldflags)
