# Where generated files go, and where they must not.
#
# Refuse in-tree builds; keep moc, rcc, uic and objects under .qmake in the
# shadow build directory.
MATOME_OUTPUT_DIR = $$clean_path($$OUT_PWD)
MATOME_PROJECT_DIR = $$clean_path($$MATOME_PROJECT_DIR)
MATOME_SOURCE_ROOT = $$clean_path($$MATOME_SOURCE_ROOT)

equals(MATOME_OUTPUT_DIR, $$MATOME_SOURCE_ROOT)|equals(MATOME_OUTPUT_DIR, $$MATOME_PROJECT_DIR) {
    error("Building in the source tree is not supported. Use mise run build.")
}

OBJECTS_DIR = $$OUT_PWD/.qmake/obj
MOC_DIR = $$OUT_PWD/.qmake/moc
RCC_DIR = $$OUT_PWD/.qmake/rcc
UI_DIR = $$OUT_PWD/.qmake/ui

win32 {
    OBJECTS_DIR = .qmake/obj
    MOC_DIR = .qmake/moc
    RCC_DIR = .qmake/rcc
    UI_DIR = .qmake/ui
}
