indicatorsprefs_CFLAGS += -Wno-incomplete-umbrella
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = indicatorsprefs
indicatorsprefs_FILES = $(wildcard *.m)
indicatorsprefs_LIBRARIES = DeusPrefs colorpicker
indicatorsprefs_INSTALL_PATH = $(THEOS_PACKAGE_INSTALL_PREFIX)/Library/PreferenceBundles
indicatorsprefs_FRAMEWORKS = UIKit
indicatorsprefs_PRIVATE_FRAMEWORKS = Preferences
indicatorsprefs_EXTRA_FRAMEWORKS = Cephei CepheiPrefs Alderis
indicatorsprefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
