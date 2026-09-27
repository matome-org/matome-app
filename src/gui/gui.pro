MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$clean_path($$PWD/../..)
include($$PWD/../../qmake/layout.pri)

QT       += core gui qml quick network
CONFIG   += c++17 qmltypes
CONFIG   -= app_bundle

QML_IMPORT_NAME = matome
QML_IMPORT_MAJOR_VERSION = 1

TEMPLATE  = app
TARGET    = matome-studio
DESTDIR   = $$OUT_PWD/../../bin
MATOME_APP_VERSION = $$cat($$MATOME_SOURCE_ROOT/version.txt, lines)
VERSION = $$MATOME_APP_VERSION

INCLUDEPATH += $$PWD/../core

HEADERS += Languages.h Theme.h Session.h OrgModel.h SpaceModel.h FolderModel.h DocumentModel.h ViewModel.h \
           EntryModel.h FolderTreeModel.h JsonList.h
SOURCES += main.cpp Theme.cpp Session.cpp SessionActions.cpp OrgModel.cpp SpaceModel.cpp FolderModel.cpp \
           DocumentModel.cpp ViewModel.cpp EntryModel.cpp FolderTreeModel.cpp
RESOURCES += resources.qrc
include($$PWD/i18n/i18n.pri)

# The browser's file picker (QWasmLocalFileAccess) and page objects
# (qstdweb) are Qt private API.
wasm: QT += gui-private

LIBS           += -L$$OUT_PWD/../core -lmatomecore
PRE_TARGETDEPS += $$OUT_PWD/../core/libmatomecore.a

android {
    DESTDIR =
    ANDROID_PACKAGE_SOURCE_DIR = $$PWD/../../packaging/android
    ANDROID_ABIS = x86_64
    ANDROID_MIN_SDK_VERSION = 28
    ANDROID_TARGET_SDK_VERSION = 36
    ANDROID_VERSION_NAME = $$MATOME_APP_VERSION
    ANDROID_VERSION_CODE = $$MATOME_ANDROID_VERSION_CODE
    isEmpty(ANDROID_VERSION_CODE): error("MATOME_ANDROID_VERSION_CODE is required")
    LIBS -= -lmatomecore
    LIBS += -lmatomecore_x86_64
    PRE_TARGETDEPS -= $$OUT_PWD/../core/libmatomecore.a
    PRE_TARGETDEPS += $$OUT_PWD/../core/libmatomecore_x86_64.a
}
