TARGET := iphone:clang:15.2:15.2


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = assemblerwrite

assemblerwrite_FILES = Tweak.xm
assemblerwrite_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
