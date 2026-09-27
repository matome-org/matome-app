MATOME_CONFIG_HEADER = $$OUT_PWD/MatomeBuildConfig.h
MATOME_CONFIG_TARGET = linux
win32: MATOME_CONFIG_TARGET = windows
macx: MATOME_CONFIG_TARGET = macos
android: MATOME_CONFIG_TARGET = android
wasm: MATOME_CONFIG_TARGET = web
MATOME_TEST_BUILD = $$(MATOME_TEST_BUILD)
contains(CONFIG, matome_test): MATOME_CONFIG_MODE = --test
equals(MATOME_TEST_BUILD, 1): MATOME_CONFIG_MODE = --test
!system(python "$$MATOME_SOURCE_ROOT/scripts/generate-build-config.py" "$$MATOME_SOURCE_ROOT/app.toml" "$$MATOME_CONFIG_HEADER" $$MATOME_CONFIG_TARGET $$MATOME_CONFIG_MODE): error("Could not generate MatomeBuildConfig.h from app.toml")
INCLUDEPATH += $$OUT_PWD
HEADERS += $$MATOME_CONFIG_HEADER
