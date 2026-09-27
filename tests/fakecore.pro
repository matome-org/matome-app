MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$clean_path($$PWD/..)
include($$PWD/../qmake/layout.pri)

QT       += core network
QT       -= gui
CONFIG   += c++17 console
CONFIG   -= app_bundle
TEMPLATE  = app
TARGET    = fakecore

SOURCES += fakecore_main.cpp
HEADERS += FakeCore.h
