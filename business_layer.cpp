#include "io_layer.h" //for saving to file etc.
#include <iostream> //iostream for debug prints
#include "globals.h" //for values such as if debug mode is enabled
#include "io_layer.h" //for file operations
#include <string>

// variables
int car_id = 0; // used for sql lookup, gotten from car name
std::string units = "lkmg"; //litres, kilometers, grams (for Co2)

// DTOs - car values, calculated car values, car info
struct car_values
{
	float urban_usage = 0.0000;
	float exurban_usage = 0.0000;
	float mixed_usage = 0.0000;
	float co2_emission = 0.0000;
	float fuel_price = 0.0000;
	float trip_distance = 0.0000;
}

struct car_calculated
{
	float urban_burned = 0.0000;
	float exurban_burned = 0.0000;
	float mixed_usage = 0.0000;
	float co2_emitted = 0.0000;
	float price_paid = 0.0000;
}

struct car_info
{
	std::string model_name = "";
	std::string engine_name = "";
	std::string gearbox_name = "";
	std::string fuel_type = "":
	std::string vehicle_class = "";
}

// ======== DTO FUNCTIONS =========
// receive car_info DTO 
void receive_car_info(std::string get_model_name, std::string get_engine_name, std::string get_gearbox_name, std::string get_fuel_type, std::string get_vehicle_class)
{
		
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
	else if (what_to_get == "price_paid")
	{
		if (DEBUG_PRINT) {std::cout << "Returned " << car_calculated.price_paid << "\n";}
		return car_calculated.price_paid;
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
		return "";
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
		return "";
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
}
