#ifndef BUSINESS_LAYER_H_INCLUDED
#define BUSINESS_LAYER_H_INCLUDED
#include <string>
#include <vector>

struct CarInfoBL {
	std::string model_name;
	std::string engine_name;
	std::string gearbox_name;
	std::string vehicle_class;
	std::string fuel_type;
};
extern CarInfoBL car_info;

void receive_car_info(std::string get_model_name, std::string get_engine_name, std::string get_gearbox_name, std::string get_vehicle_class, std::string get_fuel_type);
float get_from_calculated(std::string what_to_get);
float get_from_values(std::string what_to_get);
std::string get_from_info(std::string what_to_get);
bool get_telemetry_str(std::string telemetry_str);
void load_car_data_from_db();
void set_car_data(float urban_u, float exurban_u, float mixed_u, float co2_e);

// Mediation functions between business and data layers
std::vector<std::string> business_get_all_brands();
std::vector<std::string> business_get_models_by_brand(const std::string &brand);
std::vector<std::string> business_get_engines_by_brand_model(const std::string &brand, const std::string &model);
std::vector<std::string> business_get_gearboxes_by_brand_model(const std::string &brand, const std::string &model);
std::vector<std::string> business_get_fuel_types_by_brand_model(const std::string &brand, const std::string &model);
std::vector<std::string> business_get_vehicle_classes_by_brand_model(const std::string &brand, const std::string &model);
bool business_get_car_consumption_data();

// Calculation functions
void business_calculate(const std::string &urban_str, const std::string &exurban_str, const std::string &mixed_str, const std::string &co2_emission_str, const std::string &price_str, const std::string &distance_str);
std::vector<std::string> business_return_calculate();

#endif // BUSINESS_LAYER_H_INCLUDED
