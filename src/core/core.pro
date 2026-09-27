# Shared core library. No window, no Quick. HTTP lives here, not in QML.
MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$clean_path($$PWD/../..)
include($$PWD/../../qmake/layout.pri)

QT       += core network
QT       -= gui
CONFIG   += c++17 staticlib
CONFIG   -= app_bundle
TEMPLATE  = lib
TARGET    = matomecore

HEADERS += Client.h
SOURCES += Client.cpp
