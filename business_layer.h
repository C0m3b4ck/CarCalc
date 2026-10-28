#ifndef BUSINESS_LAYER_H_INCLUDED
#define BUSINESS_LAYER_H_INCLUDED
#include <string>

void receive_car_info(std::string get_model_name, std::string get_engine_name, std::string get_gearbox_name, std::string get_vehicle_class, std::string get_fuel_type);
float get_from_calculated(std::string what_to_get);
float get_from_values(std::string what_to_get);
std::string get_from_info(std::string what_to_get);
bool get_telemetry_str(std::string telemetry_str);
void load_car_data_from_db();
void set_car_data(float urban_u, float exurban_u, float mixed_u, float co2_e);

#endif // BUSINESS_LAYER_H_INCLUDED
