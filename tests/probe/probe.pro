# A Qt generic plugin the real matome-studio loads in the smoke test
# (QT_QPA_GENERIC_PLUGINS=matomeprobe). Test-only: nothing ships it.
MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$clean_path($$PWD/../..)
include($$PWD/../../qmake/layout.pri)

QT       += core gui qml quick
CONFIG   += plugin c++17
TEMPLATE  = lib
TARGET    = matomeprobe
DESTDIR   = $$OUT_PWD/plugins/generic

SOURCES += Probe.cpp
OTHER_FILES += probe.json
HEADERS += Wiring.h
