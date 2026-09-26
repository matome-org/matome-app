# One core, one front end. `core` is a static library with no Quick; `gui` is
# the studio window on top of it.
MATOME_PROJECT_DIR = $$PWD
MATOME_SOURCE_ROOT = $$PWD
include($$PWD/qmake/layout.pri)

TEMPLATE = subdirs
CONFIG  += ordered

SUBDIRS = \
    src/core \
    src/gui

core.subdir   = src/core
gui.subdir    = src/gui
gui.depends   = core
