#ifndef SQL_LAYER_H_INCLUDED
#define SQL_LAYER_H_INCLUDED

#include <string>
#include <vector>

struct CarDBEntry
{
    int id;
    std::string marque;
    std::string libelle_modele;
    std::string modele;
    std::string groupe;
    std::string description_commerciale;
    std::string energie;
    std::string carrosserie;
    std::string gamme;
    std::string type_boite;
    float conso_mixte_min;
    float conso_mixte_max;
    float co2_mixte_min;
    float co2_mixte_max;
    float prix_vehicule;
};

// Get all distinct car models/brands
std::vector<std::string> get_all_brands();
std::vector<std::string> get_models_by_brand(const std::string &brand);
std::vector<std::string> get_engines_by_brand_model(const std::string &brand, const std::string &model);
std::vector<std::string> get_gearboxes_by_brand_model(const std::string &brand, const std::string &model);
std::vector<std::string> get_fuel_types_by_brand_model(const std::string &brand, const std::string &model);
std::vector<std::string> get_vehicle_classes_by_brand_model(const std::string &brand, const std::string &model);

// Get consumption/emission data for specific car
bool get_car_consumption_data(const std::string &brand, const std::string &model, 
                               const std::string &engine_desc, const std::string &gearbox,
                               float &urban_usage, float &exurban_usage, float &mixed_usage,
                               float &co2_emission);

#endif // SQL_LAYER_H_INCLUDED
