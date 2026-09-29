MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$clean_path($$PWD/..)
include($$PWD/../qmake/layout.pri)

QT       += core gui qml quick network testlib qmltest
CONFIG   += testcase c++17 console qmltypes
CONFIG   += matome_test
include($$PWD/../qmake/build-config.pri)
CONFIG   -= app_bundle
TEMPLATE  = app
TARGET    = tst_studio

QML_IMPORT_NAME = matome
QML_IMPORT_MAJOR_VERSION = 1

INCLUDEPATH += $$PWD $$PWD/probe $$PWD/../src/core $$PWD/../src/gui

SOURCES += \
    tst_studio.cpp \
    ../src/core/Client.cpp \
    ../src/gui/Session.cpp \
    ../src/gui/SessionActions.cpp \
    ../src/gui/OrgAdmin.cpp \
    ../src/gui/OrgModel.cpp \
    ../src/gui/SpaceModel.cpp \
    ../src/gui/FolderModel.cpp \
    ../src/gui/DocumentModel.cpp \
    ../src/gui/ViewModel.cpp \
    ../src/gui/EntryModel.cpp \
    ../src/gui/FolderTreeModel.cpp \
    ../src/gui/Theme.cpp

HEADERS += \
    FakeCore.h \
    probe/Wiring.h \
    ../src/core/Client.h \
    ../src/gui/Session.h \
    ../src/gui/OrgAdmin.h \
    ../src/gui/OrgModel.h \
    ../src/gui/SpaceModel.h \
    ../src/gui/FolderModel.h \
    ../src/gui/DocumentModel.h \
    ../src/gui/ViewModel.h \
    ../src/gui/EntryModel.h \
    ../src/gui/FolderTreeModel.h \
    ../src/gui/JsonList.h \
    ../src/gui/Languages.h \
    ../src/gui/Theme.h

RESOURCES += ../src/gui/resources.qrc
include($$PWD/../src/gui/i18n/i18n.pri)

QMAKE_CXXFLAGS += -O0 -g --coverage
QMAKE_LFLAGS += --coverage
