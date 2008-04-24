#include "io_layer.h" //for saving to file etc.
#include <iostream> //iostream for debug prints
#include "globals.h" //for values such as if debug mode is enabled
#include "io_layer.h" //for file operations
#include "sql_layer.h"
#include <string>

// variables
int car_id = 0; // used for sql lookup, gotten from car name
float urban_u = 0, exurban_u = 0, mixed_u = 0, co2_e = 0;
std::string units = "lkmg"; //litres, kilometers, grams (for Co2)

// mediation between business and data layers
std::vector<std::string> business_get_all_brands()
{
	return get_all_brands();
}

std::vector<std::string> business_get_models_by_brand(const std::string &brand)
{
	return get_models_by_brand(brand);
}

std::vector<std::string> business_get_engines_by_brand_model(const std::string &brand, const std::string &model)
{
	return get_engines_by_brand_model(brand, model);
}

std::vector<std::string> business_get_gearboxes_by_brand_model(const std::string &brand, const std::string &model)
{
	return get_gearboxes_by_brand_model(brand, model);
}

std::vector<std::string> business_get_fuel_types_by_brand_model(const std::string &brand, const std::string &model)
{
	return get_fuel_types_by_brand_model(brand, model);
}

std::vector<std::string> business_get_vehicle_classes_by_brand_model(const std::string &brand, const std::string &model)
{
	return get_vehicle_classes_by_brand_model(brand, model);
}

#include "sql_layer.h"
#include "business_layer.h"
#ifndef CARINFO_DEFINED_EXTERN
#define CARINFO_DEFINED_EXTERN
#endif
bool business_get_car_consumption_data()
{
	return get_car_consumption_data(car_info.model_name, car_info.engine_name, car_info.engine_name, car_info.gearbox_name, urban_u, exurban_u, mixed_u, co2_e);
}

// DTOs - car values, calculated car values, car info
struct CarValues
{
	float urban_usage = 0.0000;
	float exurban_usage = 0.0000;
	float mixed_usage = 0.0000;
	float co2_emission = 0.0000;
	float fuel_price = 0.0000;
	float trip_distance = 0.0000;
};

struct CarCalculated
{
	float urban_burned = 0.0000;
	float exurban_burned = 0.0000;
	float mixed_burned = 0.0000;
	float co2_emitted = 0.0000;
	float average_price_paid = 0.0000;
	float urban_price_paid = 0.0000;
	float exurban_price_paid = 0.0000;
	float mixed_price_paid = 0.0000;
	float distance_driven = 0.0000;
};

/*
struct CarInfo
{
	std::string model_name = "";
	std::string engine_name = "";
	std::string gearbox_name = "";
	std::string vehicle_class = "";
	std::string fuel_type = "";
};
*/

CarValues car_values;
CarCalculated car_calculated;
CarInfo car_info;


// ======== DTO FUNCTIONS =========
void update_model_name(std::string new_model_name) // called by lstBox
{
	car_info.model_name = new_model_name;
}

void update_engine_name(std::string new_engine_name) // called by lstBox
{
	car_info.engine_name = new_engine_name;
}

void update_gearbox_name(std::string new_gearbox_name) // called by lstBox
{
	car_info.gearbox_name = new_gearbox_name;
}

void update_fuel_type(std::string new_fuel_type); // called by cboBox
{
		car_info.fuel_type = new_fuel_type;
}
void update_vehicle_class(std::string new_vehicle_class); // called by cboBox
{
		car_info.vehicle_class = new_vehicle_class;
}

// SQL layer functions
void load_car_data_from_db()
{
	if (DEBUG_PRINT) {std::cout << "Loading car data from SQL database for: " << car_info.model_name << " / " << car_info.engine_name << "\n";}
	if (get_car_consumption_data(car_info.model_name, car_info.engine_name, car_info.engine_name, car_info.gearbox_name, 
	                             car_values.urban_usage, car_values.exurban_usage, car_values.mixed_usage, car_values.co2_emission))
	{
		if (DEBUG_PRINT) {std::cout << "Loaded from DB - urban:" << car_values.urban_usage << " mixed:" << car_values.mixed_usage << " co2:" << car_values.co2_emission << "\n";}
	}
	else
	{
		if (DEBUG_PRINT) {std::cout << "Failed to load from DB, using defaults\n";}
		car_values.urban_usage = 0.0;
		car_values.exurban_usage = 0.0;
		car_values.mixed_usage = 0.0;
		car_values.co2_emission = 0.0;
	}
}

void set_car_data(float urban_u, float exurban_u, float mixed_u, float co2_e)
{
	car_values.urban_usage = urban_u;
	car_values.exurban_usage = exurban_u;
	car_values.mixed_usage = mixed_u;
	car_values.co2_emission = co2_e;
}

// receive car_info DTO values
void receive_car_info(std::string get_model_name, std::string get_engine_name, std::string get_gearbox_name, std::string get_vehicle_class, std::string get_fuel_type)
{
		car_info.model_name = get_model_name;
		car_info.engine_name = get_engine_name;
		car_info.gearbox_name = get_gearbox_name;
		car_info.fuel_type = get_fuel_type;
		car_info.vehicle_class = get_vehicle_class;
		if (DEBUG_PRINT) {std::cout << "Received car_info DTO: " << get_model_name << " " << get_engine_name << " " << get_gearbox_name << " " << get_fuel_type << " " << get_vehicle_class << "\n";}
		load_car_data_from_db();
}
// function called externally to get data from car_calculated struct
float get_from_calculated(std::string what_to_get)
{
	if (what_to_get == "urban_burned")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.urban_burned << "\n";}
		return car_calculated.urban_burned;
	}
	else if (what_to_get == "exurban_burned")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.exurban_burned << "\n";}
		return car_calculated.exurban_burned;
	}
	else if (what_to_get == "mixed_burned")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.mixed_burned << "\n";}
		return car_calculated.mixed_burned;
	}
	else if (what_to_get == "co2_emitted")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.co2_emitted << "\n";}
		return car_calculated.co2_emitted;
	}
	else if (what_to_get == "average_price_paid")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.average_price_paid << "\n";}
		return car_calculated.average_price_paid;
	}
	else if (what_to_get == "urban_price_paid")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.urban_price_paid << "\n";}
		return car_calculated.urban_price_paid;
	}
	else if (what_to_get == "exurban_price_paid")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.exurban_price_paid << "\n";}
		return car_calculated.exurban_price_paid;
	}
	else if (what_to_get == "mixed_price_paid")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.mixed_price_paid << "\n";}
		return car_calculated.mixed_price_paid;
	}
	else if (what_to_get == "distance_driven")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.distance_driven << "\n";}
		return car_calculated.distance_driven;
	}

	else
	{
		if (DEBUG_PRINT) {std::cout << "Programmer error - invalid argument passed to get_from_calculated function \n";}
		if (DEBUG_PRINT) {std::cout << "Please report this \n";}
		return -1.000;
	}
}

// function called externally to get data from car_values struct
float get_from_values(std::string what_to_get)
{
	if (what_to_get == "urban_usage")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_values.urban_usage << "\n";}
		return car_values.urban_usage;
	}
	else if (what_to_get == "exurban_usage")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_values.exurban_usage << "\n";}
		return car_values.exurban_usage;
	}
	else if (what_to_get == "mixed_usage")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_values.mixed_usage << "\n";}
		return car_values.mixed_usage;
	}
	else if (what_to_get == "co2_emission")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_values.co2_emission << "\n";}
		return car_values.co2_emission;
	}
	else if (what_to_get == "fuel_price")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_values.fuel_price << "\n";}
		return car_values.fuel_price;
	}
	else if (what_to_get == "trip_distance")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_values.trip_distance << "\n";}
		return car_values.trip_distance;
	}

	else
	{
		if (DEBUG_PRINT) {std::cout << "Programmer error - invalid argument passed to get_from_values function \n";}
		if (DEBUG_PRINT) {std::cout << "Please report this \n";}
		return -1.000;
	}
}
// function called externally to get data from car_info struct
std::string get_from_info(std::string what_to_get)
{
	if (what_to_get == "model_name")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_info.model_name << "\n";}
		return car_info.model_name;
	}
	else if (what_to_get == "engine_name")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_info.engine_name << "\n";}
		return car_info.engine_name;
	}
	else if (what_to_get == "gearbox_name")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_info.gearbox_name << "\n";}
		return car_info.gearbox_name;
	}
	else if (what_to_get == "fuel_type")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_info.fuel_type << "\n";}
		return car_info.fuel_type;
	}
	else if (what_to_get == "vehicle_class")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_info.vehicle_class << "\n";}
		return car_info.vehicle_class;
	}
	else
	{
		if (DEBUG_PRINT) {std::cout << "Programmer error - invalid argument passed to get_from_info function \n";}
		if (DEBUG_PRINT) {std::cout << "Please report this \n";}
		return "";
	}
}

#include <cstdlib>
#include <sstream>

// Calculation functions
void business_calculate(const std::string &urban_str, const std::string &exurban_str, const std::string &mixed_str, const std::string &co2_emission_str, const std::string &price_str, const std::string &distance_str)
{
	float urban_usage_val = car_values.urban_usage;
	float exurban_usage_val = car_values.exurban_usage;
	float mixed_usage_val = car_values.mixed_usage;
	float co2_emission_val = car_values.co2_emission;
	float fuel_price_val = car_values.fuel_price;
	float trip_distance_val = car_values.trip_distance;
	
	if (!urban_str.empty()) urban_usage_val = atof(urban_str.c_str());
	if (!exurban_str.empty()) exurban_usage_val = atof(exurban_str.c_str());
	if (!mixed_str.empty()) mixed_usage_val = atof(mixed_str.c_str());
	if (!co2_emission_str.empty()) co2_emission_val = atof(co2_emission_str.c_str());
	if (!price_str.empty()) fuel_price_val = atof(price_str.c_str());
	if (!distance_str.empty()) trip_distance_val = atof(distance_str.c_str());
	
	car_values.urban_usage = urban_usage_val;
	car_values.exurban_usage = exurban_usage_val;
	car_values.mixed_usage = mixed_usage_val;
	car_values.co2_emission = co2_emission_val;
	car_values.fuel_price = fuel_price_val;
	car_values.trip_distance = trip_distance_val;
	
	// Calculate burned fuel and costs
	car_calculated.urban_burned = urban_usage_val * trip_distance_val; // / 100.0f;
	car_calculated.exurban_burned = exurban_usage_val * trip_distance_val; // / 100.0f;
	car_calculated.mixed_burned = mixed_usage_val * trip_distance_val; // / 100.0f;
	car_calculated.co2_emitted = co2_emission_val * trip_distance_val; // / 1000.0f;
	car_calculated.average_price_paid = (car_calculated.urban_burned + car_calculated.exurban_burned + car_calculated.mixed_burned) / 3.0f * fuel_price_val;
	if (car_calculated.average_price_paid == 0 && mixed_usage_val > 0)
	{
		car_calculated.average_price_paid = mixed_usage_val * trip_distance_val / 100.0f * fuel_price_val;
	}
	car_calculated.urban_price_paid = car_calculated.urban_burned * fuel_price_val * trip_distance_val;
	car_calculated.exurban_price_paid = car_calculated.exurban_burned * fuel_price_val * trip_distance_val;
	car_calculated.mixed_price_paid = car_calculated.mixed_burned * fuel_price_val * trip_distance_val;
	car_calculated.distance_driven = trip_distance_val;
}

std::vector<std::string> business_return_calculate()
{
	std::vector<std::string> result;
	std::stringstream ss1; ss1 << car_calculated.urban_burned; result.push_back(ss1.str());
	std::stringstream ss2; ss2 << car_calculated.exurban_burned; result.push_back(ss2.str());
	std::stringstream ss3; ss3 << car_calculated.mixed_burned; result.push_back(ss3.str());
	std::stringstream ss4; ss4 << car_calculated.co2_emitted; result.push_back(ss4.str());
	std::stringstream ss5; ss5 << car_calculated.average_price_paid; result.push_back(ss5.str());
	std::stringstream ss6; ss6 << car_calculated.urban_price_paid; result.push_back(ss6.str());
	std::stringstream ss7; ss7 << car_calculated.average_price_paid; result.push_back(ss7.str());
	std::stringstream ss8; ss8 << car_calculated.average_price_paid; result.push_back(ss8.str());
	std::stringstream ss9; ss9 << car_calculated.distance_driven; result.push_back(ss9.str());
	return result;
}

// function to get string into telemetry buffer, then save it
bool get_telemetry_str(std::string telemetry_str)
{
    if (save_telemetry_str(telemetry_str) != true) //if save_telemetry_str (io layer) returned false (failed)
    {
        if (DEBUG_PRINT) {std::cout << "Saving telemetry failed - business layer retrying!\n";}
        for (short get_telemetry_inc = 0; get_telemetry_inc < RETRY_AMMOUNT; get_telemetry_inc++) //retry saving this string
        {
            if (save_telemetry_str(telemetry_str) != true)
            {
                if (DEBUG_PRINT) {std::cout << "Saving telemetry failed - business layer retrying " << get_telemetry_inc << "\n";}
            }
            else
            {
                if (DEBUG_PRINT) {std::cout << "Try " << get_telemetry_inc << " worked succesfully - line saved.\n";}
                return true;
                break;
            }
        }
        return false;
    }
    return true;
}
