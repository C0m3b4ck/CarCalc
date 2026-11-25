#ifndef UI_V2_HELPERS_H_INCLUDED
#define UI_V2_HELPERS_H_INCLUDED

#include <string>

// Read the mixed consumption figure stored in the active database for the
// currently selected car. The DB has no urban/exurban columns, so this is the
// only fuel-usage value that can be reported accurately.
//
// brand/model/gearbox/energy are the strings shown in the v2 car-selection
// widgets. Empty gearbox/energy values mean "do not filter on that column".
// Returns "N/A" when the DB has no usable figure (e.g. electric cars).
std::string ui_v2_fuel_usage_text(const std::string &brand,
                                  const std::string &model,
                                  const std::string &gearbox,
                                  const std::string &energy);

// Returns the exact `energie` value from the DB so the user can see how the
// source data classifies the car (e.g. "PETROL HYBRID (NON-PLUG-IN)").
std::string ui_v2_energy_text(const std::string &brand,
                              const std::string &model,
                              const std::string &gearbox,
                              const std::string &energy);

#endif // UI_V2_HELPERS_H_INCLUDED
