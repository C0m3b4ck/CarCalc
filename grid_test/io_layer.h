#ifndef IO_LAYER_H_INCLUDED
#define IO_LAYER_H_INCLUDED
#include <string>

std::string get_neat_timestamp();
bool make_telemetry_file();
bool save_telemetry_str(const std::string &string_to_save);

#endif // IO_LAYER_H_INCLUDED
