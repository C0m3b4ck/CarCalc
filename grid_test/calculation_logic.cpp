#include <iostream>
#include "globals.h"

float calculate_fuel_usage(float volume_per_distance, float distance)
{
    float fuel_usage = volume_per_distance * distance;
    return fuel_usage;
}
