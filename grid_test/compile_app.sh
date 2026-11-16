g++ -o prog main.cpp business_layer.cpp io_layer.cpp sql_layer.cpp grid_test.cxx -lsqlite3 $(fltk-config --cxxflags) $(fltk-config --ldflags)
