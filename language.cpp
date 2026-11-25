#include "language.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <unordered_map>

namespace {

struct BuiltinEntry
{
    const char *source;
    const char *polish;
};

const BuiltinEntry BUILTIN_LABELS[] = {
    {"Calculate", "Oblicz"},
    {"Select Car", "Wybierz samochód"},
    {"<- Select Car", "<- Wybierz samochód"},
    {"Settings", "Ustawienia"},
    {"File", "Plik"},
    {"Help", "Pomoc"},
    {"HELP", "POMOC"},
    {"About", "Informacje"},
    {"Exit", "Wyjście"},
    {"Select Car Model", "Wybierz model samochodu"},
    {"Select Car Engine", "Wybierz silnik"},
    {"Select Car Gearbox", "Wybierz skrzynię biegów"},
    {"SEARCH", "SZUKAJ"},
    {"Proceed with Car ->", "Przejdź z samochodem ->"},
    {"Clear Car", "Wyczyść samochód"},
    {"Calculate Fuel-Related", "Obliczenia paliwowe"},
    {"Calculate!", "Oblicz!"},
    {"Urban:", "Miejskie:"},
    {"Exurban:", "Pozamiejskie:"},
    {"Mixed:", "Mieszane:"},
    {"Co2 emission:", "Emisja CO2:"},
    {"Price:", "Cena:"},
    {"Trip distance:", "Dystans:"},
    {"Car Info", "Informacje o samochodzie"},
    {"Model name:", "Model:"},
    {"Engine:", "Silnik:"},
    {"Gearbox:", "Skrzynia:"},
    {"Class:", "Klasa:"},
    {"Fuel:", "Paliwo:"},
    {"Fuel type:", "Typ paliwa:"},
    {"Gov. fuel price:", "Cena paliwa:"},
    {"Fuel usage:", "Zużycie paliwa:"},
    {"Energy:", "Energia:"},
    {"Brand", "Marka"},
    {"Model", "Model"},
    {"Gearbox", "Skrzynia biegów"},
    {"Car details", "Szczegóły samochodu"},
    {"Trip inputs", "Dane trasy"},
    {"Fuel price", "Cena paliwa"},
    {"Language", "Język"},
    {"Selected file", "Wybrany plik"},
    {"Download", "Pobieranie"},
    {"Units: ", "Jednostki: "},
    {"Units:", "Jednostki:"},
    {"Trip Info", "Informacje o trasie"},
    {"Exurban price:", "Cena pozamiejska:"},
    {"Mixed price:", "Cena mieszana:"},
    {"Urban price:", "Cena miejska:"},
    {"Language:", "Język:"},
    {"Data", "Dane"},
    {"Download selected database", "Pobierz wybraną bazę danych"},
    {"Download data", "Pobierz dane"},
    {"Selected file:", "Wybrany plik:"},
    {"Choose destination and download", "Wybierz miejsce i pobierz"},
    {"Back", "Wstecz"},
    {"Ready", "Gotowe"},
    {"N/A", "N/D"},
    {"PLN/l", "zł/l"},
    {"Do you want to leave CarCalc?", "Czy chcesz zamknąć CarCalc?"},
    {"Leave", "Zamknij"},
    {"Stay", "Zostań"},
    {"Some options are not selected. Do you want to continue anyway?",
     "Nie wybrano wszystkich opcji. Kontynuować mimo to?"},
    {"This is fine", "To jest OK"},
    {"Go back and select", "Wróć i wybierz"},
    {"Database file not found: ", "Nie znaleziono pliku bazy: "},
    {"Choose where to save the database", "Wybierz miejsce zapisu bazy danych"},
    {"Download cancelled", "Pobieranie anulowane"},
    {"The database is already in that location", "Baza już jest w tej lokalizacji"},
    {"Saved: ", "Zapisano: "},
    {"Download failed: ", "Pobieranie nie powiodło się: "}};

std::vector<LanguageInfo> languages;
int current_index = 0;
std::unordered_map<std::string, std::string> canonical_map;

std::string trim(const std::string &text)
{
    const std::size_t first = text.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return "";
    const std::size_t last = text.find_last_not_of(" \t\r\n");
    return text.substr(first, last - first + 1);
}

std::string trim_left(const std::string &text)
{
    const std::size_t first = text.find_first_not_of(" \t\r\n");
    return first == std::string::npos ? "" : text.substr(first);
}

std::string lower(std::string text)
{
    for (char &c : text)
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return text;
}

std::string file_stem(const std::filesystem::path &path)
{
    std::string stem = path.stem().string();
    if (stem.empty()) return "unknown";
    stem[0] = static_cast<char>(std::toupper(static_cast<unsigned char>(stem[0])));
    return stem;
}

bool is_trs_file(const std::filesystem::path &path)
{
    return lower(path.extension().string()) == ".trs";
}

void set_or_add(TranslationEntry &entry, const std::string &text, int size)
{
    entry.text = text;
    if (size > 0) entry.size = size;
}

TranslationEntry *find_entry(LanguageInfo &language, const std::string &source)
{
    for (TranslationEntry &entry : language.translations)
    {
        if (entry.source == source) return &entry;
    }
    return nullptr;
}

const TranslationEntry *find_entry(const LanguageInfo &language, const std::string &source)
{
    for (const TranslationEntry &entry : language.translations)
    {
        if (entry.source == source) return &entry;
    }
    return nullptr;
}

void add_builtin_languages()
{
    LanguageInfo english;
    english.id = "english";
    english.name = "English";
    english.database = "cars_en.db";
    english.source = "built-in";
    for (const BuiltinEntry &item : BUILTIN_LABELS)
    {
        TranslationEntry entry;
        entry.source = item.source;
        entry.text = item.source;
        english.translations.push_back(entry);
    }
    languages.push_back(english);

    LanguageInfo polish;
    polish.id = "polski";
    polish.name = "Polski";
    polish.database = "cars_pl.db";
    polish.source = "built-in";
    for (const BuiltinEntry &item : BUILTIN_LABELS)
    {
        TranslationEntry entry;
        entry.source = item.source;
        entry.text = item.polish;
        polish.translations.push_back(entry);
    }
    languages.push_back(polish);
}

std::vector<std::string> split_value(const std::string &value)
{
    std::vector<std::string> parts;
    std::string current;
    for (std::size_t i = 0; i < value.size(); ++i)
    {
        const char c = value[i];
        if (c == '\\' && i + 1 < value.size() && value[i + 1] == '|')
        {
            current += '|';
            ++i;
        }
        else if (c == '|')
        {
            parts.push_back(current);
            current.clear();
        }
        else
        {
            current += c;
        }
    }
    parts.push_back(current);
    return parts;
}

int parse_size(const std::string &text)
{
    if (text.empty()) return -1;
    for (char c : text)
    {
        if (!std::isdigit(static_cast<unsigned char>(c))) return -1;
    }
    try
    {
        return std::stoi(text);
    }
    catch (...)
    {
        return -1;
    }
}

LanguageInfo parse_trs_file(const std::filesystem::path &path)
{
    LanguageInfo language;
    language.id = lower(file_stem(path));
    language.name = file_stem(path);
    language.database = "cars.db";
    language.source = path.generic_string();

    std::ifstream input(path);
    if (!input) return language;

    std::string section;
    std::string line;
    while (std::getline(input, line))
    {
        const std::string text = trim(line);
        if (text.empty() || text[0] == '#' || text[0] == ';') continue;

        if (text.front() == '[' && text.back() == ']')
        {
            section = lower(trim(text.substr(1, text.size() - 2)));
            continue;
        }

        const std::size_t equals = text.find('=');
        if (equals == std::string::npos) continue;

        const std::string key = trim_left(text.substr(0, equals));
        const std::string raw_value = trim(text.substr(equals + 1));
        if (key.empty() || raw_value.empty()) continue;

        if (section == "language")
        {
            const std::string lower_key = lower(key);
            if (lower_key == "name") language.name = raw_value;
            else if (lower_key == "database") language.database = raw_value;
            else if (lower_key == "id") language.id = lower(raw_value);
        }
        else if (section == "labels")
        {
            const std::vector<std::string> parts = split_value(raw_value);
            const std::string translated = trim(parts[0]);
            const int size = parts.size() > 1 ? parse_size(trim(parts[1])) : -1;
            if (translated.empty()) continue;

            TranslationEntry entry;
            entry.source = key;
            entry.text = translated;
            entry.size = size;
            language.translations.push_back(entry);
        }
    }
    return language;
}

void merge_translations(LanguageInfo &target, const LanguageInfo &source)
{
    if (!source.name.empty()) target.name = source.name;
    if (!source.database.empty()) target.database = source.database;
    if (!source.source.empty()) target.source = source.source;

    for (const TranslationEntry &incoming : source.translations)
    {
        TranslationEntry *existing = find_entry(target, incoming.source);
        if (existing) set_or_add(*existing, incoming.text, incoming.size);
        else target.translations.push_back(incoming);
    }
}

void add_or_merge_language(const LanguageInfo &parsed)
{
    for (LanguageInfo &language : languages)
    {
        if (language.id == parsed.id)
        {
            merge_translations(language, parsed);
            return;
        }
    }
    languages.push_back(parsed);
}

void rebuild_canonical_map()
{
    canonical_map.clear();
    for (const LanguageInfo &language : languages)
    {
        canonical_map[language.name] = language.name;
        for (const TranslationEntry &entry : language.translations)
        {
            canonical_map[entry.source] = entry.source;
            canonical_map[entry.text] = entry.source;
        }
    }
}

const TranslationEntry *current_entry(const std::string &source)
{
    if (current_index < 0 || current_index >= static_cast<int>(languages.size())) return nullptr;
    return find_entry(languages[static_cast<std::size_t>(current_index)], source);
}

} // namespace

void load_languages()
{
    // Read state directly. Calling current_language() here would recurse back
    // into load_languages() while languages is still empty.
    const bool had_languages = !languages.empty();
    const std::string previous_id =
        (current_index >= 0 && current_index < static_cast<int>(languages.size()))
            ? languages[static_cast<std::size_t>(current_index)].id
            : std::string("english");

    languages.clear();
    canonical_map.clear();
    add_builtin_languages();

    for (const char *directory : {"translations", "."})
    {
        std::error_code error;
        if (!std::filesystem::is_directory(directory, error)) continue;

        std::vector<std::filesystem::path> files;
        for (const std::filesystem::directory_entry &entry :
             std::filesystem::directory_iterator(directory, error))
        {
            if (error) break;
            const std::filesystem::path &path = entry.path();
            if (entry.is_regular_file() && is_trs_file(path)) files.push_back(path);
        }
        std::sort(files.begin(), files.end());

        for (const std::filesystem::path &path : files)
            add_or_merge_language(parse_trs_file(path));
    }

    rebuild_canonical_map();

    current_index = 0;
    for (std::size_t i = 0; i < languages.size(); ++i)
    {
        if (languages[i].id == previous_id)
        {
            current_index = static_cast<int>(i);
            break;
        }
    }
    if (!had_languages) current_index = 0;
}

const std::vector<LanguageInfo> &available_languages()
{
    if (languages.empty()) load_languages();
    return languages;
}

const LanguageInfo *current_language()
{
    if (languages.empty()) load_languages();
    if (current_index < 0 || current_index >= static_cast<int>(languages.size())) return nullptr;
    return &languages[static_cast<std::size_t>(current_index)];
}

int current_language_index()
{
    return current_index;
}

void set_language_by_index(int index)
{
    if (languages.empty()) load_languages();
    if (index < 0 || index >= static_cast<int>(languages.size())) return;
    current_index = index;
}

std::string canonical_text(const std::string &text)
{
    if (languages.empty()) load_languages();
    const auto it = canonical_map.find(text);
    return it == canonical_map.end() ? text : it->second;
}

std::string translate_text(const std::string &english)
{
    const TranslationEntry *entry = current_entry(english);
    return entry ? entry->text : english;
}

const char *translate_cstr(const char *english)
{
    if (!english) return "";
    const TranslationEntry *entry = current_entry(english);
    return entry ? entry->text.c_str() : english;
}

int translation_size(const char *english)
{
    if (!english) return -1;
    const TranslationEntry *entry = current_entry(english);
    return entry ? entry->size : -1;
}

std::string database_path_for_current_language()
{
    const LanguageInfo *language = current_language();
    return language ? language->database : std::string("cars.db");
}

std::string active_translation_status()
{
    const LanguageInfo *language = current_language();
    if (!language) return "";
    if (language->source == "built-in") return language->name + " (built-in)";
    return language->name + " - " + language->source;
}

AppLanguage get_app_language()
{
    const LanguageInfo *language = current_language();
    return language && language->id == "polski" ? AppLanguage::Polish : AppLanguage::English;
}

void set_app_language(AppLanguage language)
{
    const std::string id = language == AppLanguage::Polish ? "polski" : "english";
    const std::vector<LanguageInfo> &all = available_languages();
    for (std::size_t i = 0; i < all.size(); ++i)
    {
        if (all[i].id == id)
        {
            set_language_by_index(static_cast<int>(i));
            return;
        }
    }
}

bool is_polish_language()
{
    return get_app_language() == AppLanguage::Polish;
}

const char *tr(const char *english, const char *polish)
{
    if (!english) return "";
    const TranslationEntry *entry = current_entry(english);
    if (entry) return entry->text.c_str();
    if (is_polish_language() && polish) return polish;
    return english;
}

std::string database_path_for_language(AppLanguage language)
{
    return language == AppLanguage::Polish ? "cars_pl.db" : "cars_en.db";
}
