# CarCalc translation files (`.trs`)

CarCalc automatically detects every `*.trs` file in this folder and in the application root. A detected file becomes a selectable language in **Settings -> Language**. Files in this folder take precedence over same-named files in the root.

## Format

```ini
# comments start with # or ;

[language]
name=Deutsch
database=cars_de.db

[labels]
Calculate=Berechnen|14
Settings=Einstellungen|20
N/A=N/V
```

- `name` is shown in the language dropdown. If omitted, the filename is used.
- `database` is the DB loaded when the language is selected. If omitted, `cars.db` is used.
- Each `[labels]` entry is `English label=translated label|font-size`.
- `|font-size` is optional. When present it sets the widget's `labelsize()`.
- Use `\|` to include a literal pipe in a translation.

English and Polski are built in, so a `.trs` file may contain only the labels you want to override.
