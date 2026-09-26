# The browser suite's eyes (window.matomeE2E), linked whole into the e2e
# WASM build by .scripts/e2e.sh. Test-only: nothing ships it.
MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$clean_path($$PWD/../../../..)
include($$PWD/../../../../qmake/layout.pri)

QT       += core gui qml quick
CONFIG   += staticlib c++17
TEMPLATE  = lib
TARGET    = webprobe

SOURCES += WebProbe.cpp
INCLUDEPATH += $$PWD/../../../probe
HEADERS += ../../../probe/Wiring.h
