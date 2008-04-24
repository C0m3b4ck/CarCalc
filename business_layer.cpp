#include "io_layer.h" //for saving to file etc.
#include <iostream> //iostream for debug prints
#include "globals.h" //for values such as if debug mode is enabled
#include "io_layer.h" //for file operations
#include <string>

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
