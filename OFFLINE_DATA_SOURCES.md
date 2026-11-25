# Offline vehicle-data sources

CarCalc reads a local SQLite file at runtime and never needs a network
connection. The sources below can be downloaded once, converted to the existing
`cars` table schema, and shipped next to the executable. Pick the database with
the `database=` line of the active `translations/*.trs` file.

## 1. ADEME / data.gouv.fr (already used by CarCalc)

- Dataset: <https://www.data.gouv.fr/datasets/emissions-de-co2-et-de-polluants-des-vehicules-commercialises-en-france/>
- API metadata: <https://www.data.gouv.fr/api/1/datasets/emissions-de-co2-et-de-polluants-des-vehicules-commercialises-en-france/>
- Example stable download (2015 edition): <https://www.data.gouv.fr/api/1/datasets/r/bc42c2e3-d24c-4499-a966-d35656c6cfc1>
- Licence: **Licence Ouverte / Open Licence 2.0** (French open-data licence).
- Format: annual ZIP/CSV files, 2001–2015 (latest resource metadata updated
  December 2025). Fields include `marque`, `libelle_modele`,
  `description_commerciale`, `energie`, `type_boite`, `conso_mixte_min/max`,
  `co2_mixte_min/max`, `prix_vehicule`, `bonus_malus`.

This is the closest match to the bundled DB — the column names and French
energy labels are already aligned. Use it to refresh or extend `cars.db`
without changing the importer.

## 2. EPA / FuelEconomy.gov (United States)

- Bulk CSV: <https://www.fueleconomy.gov/feg/epadata/vehicles.csv.zip>
- Unzipped CSV: <https://www.fueleconomy.gov/feg/epadata/vehicles.csv>
- Field documentation: <https://www.fueleconomy.gov/feg/ws/index.shtml#vehicle>
- Coverage: model years 1984–2026 (updated 20 November 2026).
- Licence: U.S. government data, public domain in the U.S.
- Useful fields: `make`, `model`, `year`, `fuelType1`, `fuelType2`, `atvtype`,
  `city08`, `highway08`, `comb08`, `co2`, `trany`, `evMotor`.

`comb08` is combined miles per US gallon. Convert to the unit CarCalc displays
with `L/100 km = 235.214583 / comb08` (use `comb08U` for unrounded values).
Fuel-type labels differ from the French ones, so map `Gasoline`/`Diesel`/
`Electricity`/`Hybrid` to the `energie` vocabulary before import.

## 3. European Environment Agency — passenger-car CO₂ monitoring

- Dataset record: <https://www.eea.europa.eu/en/datahub/datahubitem-view/fa8b1229-3db6-495d-b18e-9c9b3267c02b>
- Catalogue API record: <https://sdi.eea.europa.eu/catalogue/datahub/api/records/b4044b06-2e6b-4f8e-a6e6-66e0e98bb0dd>
- Discodata API docs: <https://discodata.eea.europa.eu/Help.html>
- Direct query example (JSON, paginate with `p` and `nrOfHits`):
  <https://discodata.eea.europa.eu/sql?query=SELECT%20TOP%20100%20*%20FROM%20%5BCO2Emission%5D.%5Blatest%5D.%5Bco2cars_2025Pv31%5D&p=1&nrOfHits=100>
- Format: CSV/TXT/SQL via the EEA Discodata endpoint; years 2010–2025.
- Licence: **CC-BY 4.0**, copyright DG CLIMA.
- Coverage: EU-27, Iceland (since 2018), Norway (since 2019). Manufacturer,
  type/variant/version, fuel type, WLTP CO₂, mass, engine size/power.

Good for Europe-wide CO₂ and fleet data. It does **not** publish L/100 km per
vehicle, so do not derive consumption from CO₂ unless you document the
conversion and its assumptions — CarCalc only shows values present in the DB.

## Usage notes

- Download once while online; after that all lookups are local SQLite queries.
- Keep the `cars` table column names identical to `cars_en.db` so the existing
  `sql_layer.cpp` and `ui_v2_helpers.cpp` queries keep working.
- When adding a new language, add `translations/<name>.trs` with `database=` set
  to the new file; the language dropdown picks it up automatically.
- Never invent urban/exurban figures: none of these sources provides the exact
  urban/exurban split used by the original French schema (EPA does provide
  city/highway MPG, which should be stored in clearly named new columns).
