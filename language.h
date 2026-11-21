#ifndef LANGUAGE_H_INCLUDED
#define LANGUAGE_H_INCLUDED

#include <string>
#include <vector>

// Kept for source compatibility with older call sites.
enum class AppLanguage
{
    English,
    Polish
};

struct TranslationEntry
{
    std::string source; // English label/key
    std::string text;   // translated label
    int size = -1;      // labelsize(); -1 means keep the widget's current size
};

struct LanguageInfo
{
    std::string id;       // stable id, normally the .trs filename stem
    std::string name;     // display name in the language dropdown
    std::string database; // database used when this language is active
    std::string source;   // "built-in" or the .trs path
    std::vector<TranslationEntry> translations;
};

// Loads built-in languages, then autodetects *.trs files in translations/ and
// the application root. Files in translations/ win when both locations define
// the same id. Safe to call more than once.
void load_languages();

const std::vector<LanguageInfo> &available_languages();
const LanguageInfo *current_language();
int current_language_index();
void set_language_by_index(int index);

// Returns the English key for a label in any loaded language, so switching
// back from a translated label still resolves correctly.
std::string canonical_text(const std::string &text);

// Translation lookups. The *_cstr variants return stable pointers suitable
// for FLTK labels/menu items.
std::string translate_text(const std::string &english);
const char *translate_cstr(const char *english);
int translation_size(const char *english);

std::string database_path_for_current_language();
std::string active_translation_status();

// Legacy helpers.
AppLanguage get_app_language();
void set_app_language(AppLanguage language);
bool is_polish_language();
const char *tr(const char *english, const char *polish);
std::string database_path_for_language(AppLanguage language);

#endif // LANGUAGE_H_INCLUDED
