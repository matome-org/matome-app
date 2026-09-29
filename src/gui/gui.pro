MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$clean_path($$PWD/../..)
include($$PWD/../../qmake/layout.pri)
include($$PWD/../../qmake/build-config.pri)

QT       += core gui qml quick network
CONFIG   += c++17 qmltypes
win32: CONFIG -= debug_and_release build_all
!macx: CONFIG -= app_bundle

QML_IMPORT_NAME = matome
QML_IMPORT_MAJOR_VERSION = 1

TEMPLATE  = app
TARGET    = matome-studio
macx: TARGET = Matome
DESTDIR   = $$OUT_PWD/../../bin
MATOME_APP_VERSION = $$cat($$MATOME_SOURCE_ROOT/version.txt, lines)
VERSION = $$MATOME_APP_VERSION

INCLUDEPATH += $$PWD/../core

HEADERS += OrgAdmin.h Languages.h Theme.h Session.h OrgModel.h SpaceModel.h FolderModel.h DocumentModel.h ViewModel.h \
           EntryModel.h FolderTreeModel.h JsonList.h
SOURCES += OrgAdmin.cpp main.cpp Theme.cpp Session.cpp SessionActions.cpp OrgModel.cpp SpaceModel.cpp FolderModel.cpp \
           DocumentModel.cpp ViewModel.cpp EntryModel.cpp FolderTreeModel.cpp
RESOURCES += resources.qrc
include($$PWD/i18n/i18n.pri)

# The browser's file picker (QWasmLocalFileAccess) and page objects
# (qstdweb) are Qt private API.
wasm: QT += gui-private

LIBS           += -L$$OUT_PWD/../core -lmatomecore
PRE_TARGETDEPS += $$OUT_PWD/../core/libmatomecore.a

win32 {
    LIBS -= -L$$OUT_PWD/../core -lmatomecore
    PRE_TARGETDEPS -= $$OUT_PWD/../core/libmatomecore.a
    CONFIG(release, debug|release): MATOME_CORE_LIB = $$OUT_PWD/../core/release/matomecore.lib
    CONFIG(debug, debug|release): MATOME_CORE_LIB = $$OUT_PWD/../core/debug/matomecore.lib
    LIBS += $$MATOME_CORE_LIB
    PRE_TARGETDEPS += $$MATOME_CORE_LIB
}

android {
    DESTDIR =
    ANDROID_PACKAGE_SOURCE_DIR = $$PWD/../../packaging/android
    MATOME_ANDROID_OPENSSL_DIR = $$(MATOME_ANDROID_OPENSSL_DIR)
    isEmpty(MATOME_ANDROID_OPENSSL_DIR): error("MATOME_ANDROID_OPENSSL_DIR is required")
    ANDROID_EXTRA_LIBS += $$MATOME_ANDROID_OPENSSL_DIR/libcrypto_3.so \
                          $$MATOME_ANDROID_OPENSSL_DIR/libssl_3.so
    isEmpty(MATOME_ANDROID_ABI): MATOME_ANDROID_ABI = x86_64
    ANDROID_ABIS = $$MATOME_ANDROID_ABI
    ANDROID_MIN_SDK_VERSION = 28
    ANDROID_TARGET_SDK_VERSION = 36
    ANDROID_VERSION_NAME = $$MATOME_APP_VERSION
    ANDROID_VERSION_CODE = $$MATOME_ANDROID_VERSION_CODE
    isEmpty(ANDROID_VERSION_CODE): error("MATOME_ANDROID_VERSION_CODE is required")
    LIBS -= -lmatomecore
    LIBS += -lmatomecore_$${MATOME_ANDROID_ABI}
    PRE_TARGETDEPS -= $$OUT_PWD/../core/libmatomecore.a
    PRE_TARGETDEPS += $$OUT_PWD/../core/libmatomecore_$${MATOME_ANDROID_ABI}.a
}
