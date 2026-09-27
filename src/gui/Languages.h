#pragma once

namespace matome {

/// One interface language: its code (a BCP 47 tag, the `.ts` suffix with
/// `-` as `_`), its mark in the landing's switcher, and its name in itself.
struct Language
{
    const char *code;
    const char *mark;
    const char *name;
};

/// The languages the interface speaks, in switcher order. The Auth switcher,
/// the account menu, and the `lang-*` commands all list these; English is
/// the source and the fallback.
inline constexpr Language kLanguages[] = {
        {"pt-BR", "PT", "Português"},
        {"en", "EN", "English"},
        {"ja", "日本語", "日本語"},
};

/// The language the interface is written in, and falls back to.
inline constexpr char kSourceLanguage[] = "en";

/// Where a language command's id starts: `lang-pt-BR` chooses `pt-BR`.
inline constexpr char kLanguageCommand[] = "lang-";

} // namespace matome
