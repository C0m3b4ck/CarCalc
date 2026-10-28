#include "sql_layer.h"
#include <sqlite3.h>
#include <iostream>
#include <vector>
#include <string>
#include <cstdlib>

static std::string db_path = "cars.db";

std::vector<std::string> get_all_brands()
{
    std::vector<std::string> brands;
    sqlite3 *db;
    sqlite3_stmt *stmt;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK)
    {
        sqlite3_close(db);
        return brands;
    }
    const char *sql = "SELECT DISTINCT marque FROM cars ORDER BY marque";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, 0) == SQLITE_OK)
    {
        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            const unsigned char *text = sqlite3_column_text(stmt, 0);
            if (text)
            {
                brands.push_back(std::string(reinterpret_cast<const char*>(text)));
            }
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return brands;
}

std::vector<std::string> get_models_by_brand(const std::string &brand)
{
    std::vector<std::string> models;
    sqlite3 *db;
    sqlite3_stmt *stmt;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK)
    {
        sqlite3_close(db);
        return models;
    }
    const char *sql = "SELECT DISTINCT description_commerciale FROM cars WHERE marque = ? ORDER BY description_commerciale";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, 0) == SQLITE_OK)
    {
        sqlite3_bind_text(stmt, 1, brand.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            const unsigned char *text = sqlite3_column_text(stmt, 0);
            if (text)
            {
                models.push_back(std::string(reinterpret_cast<const char*>(text)));
            }
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return models;
}

std::vector<std::string> get_engines_by_brand_model(const std::string &brand, const std::string &model)
{
    std::vector<std::string> engines;
    sqlite3 *db;
    sqlite3_stmt *stmt;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK)
    {
        sqlite3_close(db);
        return engines;
    }
    const char *sql = "SELECT DISTINCT description_commerciale, cylindree, puissance_max, puissance_nominale_elec, energie FROM cars WHERE marque = ? AND description_commerciale = ? ORDER BY description_commerciale";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, 0) == SQLITE_OK)
    {
        sqlite3_bind_text(stmt, 1, brand.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, model.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            const unsigned char *text = sqlite3_column_text(stmt, 0);
            if (text)
            {
                std::string engine = std::string(reinterpret_cast<const char*>(text));
                engines.push_back(engine);
            }
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return engines;
}

std::vector<std::string> get_gearboxes_by_brand_model(const std::string &brand, const std::string &model)
{
    std::vector<std::string> gearboxes;
    sqlite3 *db;
    sqlite3_stmt *stmt;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK)
    {
        sqlite3_close(db);
        return gearboxes;
    }
    const char *sql = "SELECT DISTINCT type_boite FROM cars WHERE marque = ? AND description_commerciale = ? ORDER BY type_boite";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, 0) == SQLITE_OK)
    {
        sqlite3_bind_text(stmt, 1, brand.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, model.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            const unsigned char *text = sqlite3_column_text(stmt, 0);
            if (text)
            {
                gearboxes.push_back(std::string(reinterpret_cast<const char*>(text)));
            }
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return gearboxes;
}

std::vector<std::string> get_fuel_types_by_brand_model(const std::string &brand, const std::string &model)
{
    std::vector<std::string> fuels;
    sqlite3 *db;
    sqlite3_stmt *stmt;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK)
    {
        sqlite3_close(db);
        return fuels;
    }
    const char *sql = "SELECT DISTINCT energie FROM cars WHERE marque = ? AND description_commerciale = ? ORDER BY energie";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, 0) == SQLITE_OK)
    {
        sqlite3_bind_text(stmt, 1, brand.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, model.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            const unsigned char *text = sqlite3_column_text(stmt, 0);
            if (text)
            {
                fuels.push_back(std::string(reinterpret_cast<const char*>(text)));
            }
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return fuels;
}

std::vector<std::string> get_vehicle_classes_by_brand_model(const std::string &brand, const std::string &model)
{
    std::vector<std::string> classes;
    sqlite3 *db;
    sqlite3_stmt *stmt;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK)
    {
        sqlite3_close(db);
        return classes;
    }
    const char *sql = "SELECT DISTINCT carrosserie FROM cars WHERE marque = ? AND description_commerciale = ? ORDER BY carrosserie";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, 0) == SQLITE_OK)
    {
        sqlite3_bind_text(stmt, 1, brand.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, model.c_str(), -1, SQLITE_STATIC);
        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            const unsigned char *text = sqlite3_column_text(stmt, 0);
            if (text)
            {
                classes.push_back(std::string(reinterpret_cast<const char*>(text)));
            }
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return classes;
}

bool get_car_consumption_data(const std::string &brand, const std::string &model, 
                               const std::string &engine_desc, const std::string &gearbox,
                               float &urban_usage, float &exurban_usage, float &mixed_usage,
                               float &co2_emission)
{
    sqlite3 *db;
    sqlite3_stmt *stmt;
    if (sqlite3_open(db_path.c_str(), &db) != SQLITE_OK)
    {
        sqlite3_close(db);
        return false;
    }
    // Try to get mixed consumption and CO2 - approximate urban/exurban from mixed if not available
    const char *sql = "SELECT conso_mixte_min, conso_mixte_max, co2_mixte_min, co2_mixte_max FROM cars WHERE marque = ? AND description_commerciale = ? ORDER BY id LIMIT 1";
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, 0) == SQLITE_OK)
    {
        sqlite3_bind_text(stmt, 1, brand.c_str(), -1, SQLITE_STATIC);
        sqlite3_bind_text(stmt, 2, model.c_str(), -1, SQLITE_STATIC);
        if (sqlite3_step(stmt) == SQLITE_ROW)
        {
            float conso_mixte_min = sqlite3_column_type(stmt, 0) != SQLITE_NULL ? (float)sqlite3_column_double(stmt, 0) : 0.0f;
            float conso_mixte_max = sqlite3_column_type(stmt, 1) != SQLITE_NULL ? (float)sqlite3_column_double(stmt, 1) : 0.0f;
            float co2_mixte_min = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? (float)sqlite3_column_double(stmt, 2) : 0.0f;
            float co2_mixte_max = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? (float)sqlite3_column_double(stmt, 3) : 0.0f;
            mixed_usage = (conso_mixte_min + conso_mixte_max) / 2.0f;
            if (mixed_usage == 0.0f && conso_mixte_min != 0.0f) mixed_usage = conso_mixte_min;
            if (mixed_usage == 0.0f && conso_mixte_max != 0.0f) mixed_usage = conso_mixte_max;
            urban_usage = mixed_usage * 1.2f; // approximation
            exurban_usage = mixed_usage * 0.8f; // approximation
            co2_emission = (co2_mixte_min + co2_mixte_max) / 2.0f;
            if (co2_emission == 0.0f && co2_mixte_min != 0.0f) co2_emission = co2_mixte_min;
            if (co2_emission == 0.0f && co2_mixte_max != 0.0f) co2_emission = co2_mixte_max;
            sqlite3_finalize(stmt);
            sqlite3_close(db);
            return true;
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return false;
}
