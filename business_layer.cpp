#include "io_layer.h" //for saving to file etc.
#include <iostream> //iostream for debug prints
#include "globals.h" //for values such as if debug mode is enabled
#include "io_layer.h" //for file operations
#include <string>

// DTOs - car values, calculated car values, car info
struct car_values
{
	float urban_usage = 0.0000;
	float exurban_usage = 0.0000;
	float mixed_usage = 0.0000;
	float co2_emission = 0.0000;
	float fuel_price = 0.0000;
	float trip_distance = 0.0000;
	std::string units = "lkmg"; //litres, kilometers, grams (for Co2)
}

struct car_calculated
{
	float urban_burned = 0.0000;
	float exurban_burned = 0.0000;
	float mixed_usage = 0.0000;
	float co2_emitted = 0.0000;
	float price_paid = 0.0000;
	float distance_driven = 0.0000;
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
