# Database quality audit

Audited `cars.db`, `cars_en.db`, `cars_pl.db` (and their `ui_v2/` copies) with a
small C++ program using the SQLite C API. No Python is involved.

## Result

| Check | Result |
|---|---|
| Tables | `cars` only, 24 columns, same schema in all three files |
| Rows / distinct `id` | 3604 / 3604 (no duplicate IDs) |
| Duplicate full rows | none |
| Empty `description_commerciale`, `energie`, `marque` | none |
| True mojibake byte sequences (`Ã`, `Â` followed by invalid byte, U+FFFD) | none |
| Control characters in text | none |
| `conso_mixte_min > conso_mixte_max` | none |
| Consumption range | 0.61 – 19.5 L/100 km |
| `prix_vehicule <= 0`, `poids_vide <= 0` | none |
| Gearbox values | `AUTOMATIC`, `MANUAL`, `SINGLE-SPEED (ELECTRIC)`, `CONTINUOUSLY VARIABLE (CVT)` only |

The earlier double-encoded `description_commerciale` values were repaired in
all three databases before this audit. The remaining French `â` characters
(e.g. `châssis`) are correct UTF-8, not mojibake.

## Intentional gaps (not errors)

- 134 rows have **both** `conso_mixte_min` and `conso_mixte_max` NULL/zero. All
  134 are electric vehicles (`ELECTRIC` in `cars.db`/`cars_en.db`,
  `ELEKTRYCZNY` in `cars_pl.db`) — there is no fuel consumption to report.
- A further 64 rows have only one usable bound (mostly plug-in hybrids and a
  few trims). The v2 helper `ui_v2_helpers.cpp` uses the positive bound and
  returns `N/A` only when neither bound is usable.
- `co2_mixte_*` is NULL/zero on the same rows, consistent with the missing fuel
  figures.
- 622 distinct `description_commerciale` + `energie` pairs for 3604 rows are
  trim/option variants, not duplicated records.

## What the app does about it

- `ui_v2_fuel_usage_text()` reads only real `conso_mixte_min/max` values and
  returns `N/A` when absent. It never invents urban/exurban numbers — the DB
  has no urban/exurban columns.
- `ui_v2_energy_text()` shows the exact DB `energie` value, so hybrids are not
  guessed from model names (e.g. Honda Civic rows 1268/2247/3040 are
  `PETROL HYBRID (NON-PLUG-IN)`, with 65 kW as motor power, not a pure EV).
- The dormant government-price module is unrelated to these data gaps and is
  never called from the UI.
