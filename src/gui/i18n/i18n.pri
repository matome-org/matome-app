# The interface's translations. lrelease compiles them into :/i18n/ on every
# build, so desktop, WebAssembly, and Android carry the same words. English
# is the source language and has no file. `mise run i18n` refreshes them.
TRANSLATIONS = $$PWD/matome_pt_BR.ts $$PWD/matome_ja.ts
CONFIG += lrelease embed_translations

# The scripts export MATOME_LRELEASE (.scripts/linguist.sh finds it).
MATOME_LRELEASE = $$(MATOME_LRELEASE)
isEmpty(MATOME_LRELEASE): MATOME_LRELEASE = $$[QT_HOST_BINS]/lrelease
!exists($$MATOME_LRELEASE): \
    error("lrelease is missing at $$MATOME_LRELEASE; mise run deps says how to install it.")
QT_TOOL.lrelease.binary = $$MATOME_LRELEASE
