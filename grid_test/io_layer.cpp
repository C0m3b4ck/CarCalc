#include <iostream> // for error reporting
#include <fstream> // for file i/o
#include "globals.h" // for global values, such as debug prints

#include <ctime>
#include <iostream>
#include <fstream>
#include <string>

std::ofstream telemetry_file; // shared handle

bool make_telemetry_file(); //pre-definition

bool start_telemetry()
{
    if (!(make_telemetry_file()))
    {

        for (short start_telemetry_inc = 0; start_telemetry_inc < RETRY_AMMOUNT; start_telemetry_inc++)
        {
            if (!(make_telemetry_file()))
            {

            }
        }
    }
}

std::string get_neat_timestamp()
{
    time_t timestamp;
    time(&timestamp);

    struct tm *t = localtime(&timestamp);
    char buf[64];
    strftime(buf, sizeof(buf), "%Y_%m_%d_%H_%M_%S", t);
    return std::string(buf);
}

bool make_telemetry_file() // open (make) telemetry file
{
    std::string filename = get_neat_timestamp() + ".log";
    telemetry_file.open(filename, std::ios::out);
    if (!telemetry_file.is_open()) return false;
    return true;
}

bool save_telemetry_str(const std::string &string_to_save) // saves the single string into the file
{
    if (!telemetry_file.is_open())
    {
        if (DEBUG_PRINT) {std::cout << "File is not open, failed to save telemetry line - io layer\n";}
        return false;
    }
    telemetry_file << string_to_save << '\n';
    if (DEBUG_PRINT) {std::cout << "Succesfully saved telemetry line: " << string_to_save << "\n";}
    return true;
}
