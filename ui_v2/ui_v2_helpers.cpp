#include "ui_v2_helpers.h"

#include "../sql_layer.h"

#include <sqlite3.h>

#include <algorithm>
#include <iomanip>
#include <sstream>
#include <string>

namespace {

struct CarEnergyRow
{
    bool found = false;
    std::string energy;
    double mixed_min = 0.0;
    double mixed_max = 0.0;
};

void bind_text(sqlite3_stmt *stmt, int index, const std::string &value)
{
    sqlite3_bind_text(stmt, index, value.c_str(), -1, SQLITE_TRANSIENT);
}

bool read_row(sqlite3_stmt *stmt, CarEnergyRow &row)
{
    if (sqlite3_step(stmt) != SQLITE_ROW) return false;

    const unsigned char *energy = sqlite3_column_text(stmt, 0);
    if (energy) row.energy = reinterpret_cast<const char *>(energy);
    if (sqlite3_column_type(stmt, 1) != SQLITE_NULL)
        row.mixed_min = sqlite3_column_double(stmt, 1);
    if (sqlite3_column_type(stmt, 2) != SQLITE_NULL)
        row.mixed_max = sqlite3_column_double(stmt, 2);
    row.found = true;
    return true;
}

CarEnergyRow lookup(const std::string &brand,
                    const std::string &model,
                    const std::string &gearbox,
                    const std::string &energy)
{
    CarEnergyRow row;

    sqlite3 *db = nullptr;
    if (sqlite3_open(get_database_path().c_str(), &db) != SQLITE_OK)
    {
        sqlite3_close(db);
        return row;
    }

    // Most specific: honour every selection the user made.
    const char *sql =
        "SELECT energie, conso_mixte_min, conso_mixte_max FROM cars "
        "WHERE marque = ? AND description_commerciale = ? "
        "AND (? = '' OR type_boite = ?) "
        "AND (? = '' OR energie = ?) "
        "ORDER BY id LIMIT 1";

    sqlite3_stmt *stmt = nullptr;
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, nullptr) == SQLITE_OK)
    {
        bind_text(stmt, 1, brand);
        bind_text(stmt, 2, model);
        bind_text(stmt, 3, gearbox);
        bind_text(stmt, 4, gearbox);
        bind_text(stmt, 5, energy);
        bind_text(stmt, 6, energy);
        read_row(stmt, row);
        sqlite3_finalize(stmt);
    }

    // Fall back to brand + model only when the combination does not exist.
    if (!row.found)
    {
        const char *fallback =
            "SELECT energie, conso_mixte_min, conso_mixte_max FROM cars "
            "WHERE marque = ? AND description_commerciale = ? "
            "ORDER BY id LIMIT 1";
        if (sqlite3_prepare_v2(db, fallback, -1, &stmt, nullptr) == SQLITE_OK)
        {
            bind_text(stmt, 1, brand);
            bind_text(stmt, 2, model);
            read_row(stmt, row);
            sqlite3_finalize(stmt);
        }
    }

    sqlite3_close(db);
    return row;
}

double average_positive(double a, double b)
{
    if (a > 0.0 && b > 0.0) return (a + b) / 2.0;
    if (a > 0.0) return a;
    if (b > 0.0) return b;
    return 0.0;
}

} // namespace

std::string ui_v2_fuel_usage_text(const std::string &brand,
                                  const std::string &model,
                                  const std::string &gearbox,
                                  const std::string &energy)
{
    const CarEnergyRow row = lookup(brand, model, gearbox, energy);
    const double mixed = average_positive(row.mixed_min, row.mixed_max);
    if (mixed <= 0.0) return "N/A";

    std::ostringstream out;
    out << std::fixed << std::setprecision(2) << mixed << " L/100 km";
    return out.str();
}

std::string ui_v2_energy_text(const std::string &brand,
                              const std::string &model,
                              const std::string &gearbox,
                              const std::string &energy)
{
    const CarEnergyRow row = lookup(brand, model, gearbox, energy);
    return row.found ? row.energy : std::string();
}
