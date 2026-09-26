.pragma library

// The row of Session.commandList with this id; an unusable blank if absent.
function find(list, id) {
    return list.find(function (cmd) { return cmd.id === id })
        ?? { id: id, title: "", icon: id, shortcut: "", usable: false }
}

// Every key bound to `cmd`, the first one first; none when it has no key.
function keys(cmd) {
    return cmd.shortcut === "" ? [] : cmd.shortcut.split(" / ")
}

// The window carries out the commands that choose a Theme value itself:
// "theme-" and a mode, "lang-" and a language code. "" for any other.
function themeMode(id) {
    return id.startsWith("theme-") ? id.slice("theme-".length) : ""
}

function language(id) {
    return id.startsWith("lang-") ? id.slice("lang-".length) : ""
}

// The command that chooses each of `languages` (Theme.languages).
function languageIds(languages) {
    return languages.map(function (choice) { return "lang-" + choice.code })
}
