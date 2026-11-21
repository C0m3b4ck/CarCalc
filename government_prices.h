#ifndef GOVERNMENT_PRICES_H_INCLUDED
#define GOVERNMENT_PRICES_H_INCLUDED

#include <optional>
#include <string>

// Dormant government-price lookups. For now Poland is the only supported
// country. These functions are deliberately not called anywhere in the app.

struct GovernmentFuelPrices
{
    double pb95_pln_per_l = 0.0;
    double pb98_pln_per_l = 0.0;
    double diesel_pln_per_l = 0.0;
    std::string source_url;
    std::string effective_period;
};

struct GovernmentPrices
{
    GovernmentFuelPrices fuel;
    double electricity_pln_per_mwh = 0.0;
    double gas_pln_per_mwh = 0.0;
    std::string electricity_source_url;
    std::string gas_source_url;
    std::string electricity_period;
    std::string gas_period;
};

// PB95, PB98 and diesel maximal retail prices from Poland's Ministry of Energy.
std::optional<GovernmentFuelPrices> get_fuel_price_for_country(const std::string &country);

// Electricity and gas averages from URE plus PB95/PB98 from the Ministry.
std::optional<GovernmentPrices> get_government_prices_for_country(const std::string &country);

#endif // GOVERNMENT_PRICES_H_INCLUDED
