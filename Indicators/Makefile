# --- roothide + Logos fixes ---
export THEOS_PACKAGE_SCHEME = roothide

# Do NOT let Logos turn warnings into fatal errors

ifdef SIM
	export ARCHS = x86_64
	TARGET = simulator:clang:latest:8.0
else
	export ARCHS = arm64e
endif

INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Indicators
Indicators_FILES = $(wildcard *.x)
Indicators_LIBRARIES = colorpicker
Indicators_PRIVATE_FRAMEWORKS = CoreMedia
Indicators_EXTRA_FRAMEWORKS += Cephei Alderis
Indicators_CFLAGS = -fobjc-arc -Wno-error
Indicators_LOGOSFLAGS += -Wno-error

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += indicatorsprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

sim::
	@$(MAKE) SIM=1
	@echo "Copying dylib and plist to /opt/simject..."
	@cp -R .theos/obj/iphone_simulator/debug/x86_64/$(TWEAK_NAME).dylib /opt/simject/
	@cp -R $(TWEAK_NAME).plist /opt/simject/
	@echo "Restarting simulator..."
	@$(RESPRING)

# Build with THEOS_PACKAGE_SCHEME=roothide for RootHide packaging.
