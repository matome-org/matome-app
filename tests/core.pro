MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$clean_path($$PWD/..)
include($$PWD/../qmake/layout.pri)

QT       += core network qml testlib
QT       -= gui
CONFIG   += testcase c++17 console
CONFIG   += matome_test
include($$PWD/../qmake/build-config.pri)
CONFIG   -= app_bundle
TEMPLATE  = app
TARGET    = tst_core

INCLUDEPATH += $$PWD $$PWD/../src/core $$PWD/../src/gui

SOURCES += \
    tst_core.cpp \
    ../src/core/Client.cpp \
    ../src/gui/Session.cpp \
    ../src/gui/SessionActions.cpp \
    ../src/gui/OrgModel.cpp \
    ../src/gui/SpaceModel.cpp \
    ../src/gui/FolderModel.cpp \
    ../src/gui/DocumentModel.cpp \
    ../src/gui/ViewModel.cpp \
    ../src/gui/EntryModel.cpp \
    ../src/gui/FolderTreeModel.cpp

HEADERS += \
    FakeCore.h \
    ../src/core/Client.h \
    ../src/gui/Session.h \
    ../src/gui/OrgModel.h \
    ../src/gui/SpaceModel.h \
    ../src/gui/FolderModel.h \
    ../src/gui/DocumentModel.h \
    ../src/gui/ViewModel.h \
    ../src/gui/EntryModel.h \
    ../src/gui/FolderTreeModel.h \
    ../src/gui/JsonList.h \
    ../src/gui/Languages.h

QMAKE_CXXFLAGS += -O0 -g --coverage
QMAKE_LFLAGS += --coverage
