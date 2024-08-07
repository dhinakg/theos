# Variables that are common to all Darwin-based targets.
TARGET_EXE_EXT :=
TARGET_LIB_EXT := .dylib
TARGET_AR_EXT := .a

TARGET_LDFLAGS_DYNAMICLIB = -dynamiclib -install_name "$(LOCAL_INSTALL_PATH)/$(1)"
TARGET_CFLAGS_DYNAMICLIB =

_THEOS_TARGET_SUPPORTS_BUNDLES := 1

_THEOS_TARGET_CC := clang
_THEOS_TARGET_CXX := clang++
_THEOS_TARGET_SWIFTC := swiftc
_THEOS_TARGET_ARG_ORDER := 1 2
ifeq ($(__THEOS_TARGET_ARG_1),clang)
	_THEOS_TARGET_ARG_ORDER := 2 3
else ifeq ($(__THEOS_TARGET_ARG_1),gcc)
	_THEOS_TARGET_ARG_ORDER := 2 3
endif

_THEOS_TARGET_DEFAULT_PACKAGE_FORMAT ?= deb

ifeq ($(_THEOS_TARGET_PLATFORM_IS_SIMULATOR),$(_THEOS_TRUE))
	# _THEOS_TARGET_LOGOS_DEFAULT_GENERATOR := internal

	# TARGET_CODESIGN ?= codesign
	# TARGET_CODESIGN_FLAGS ?= --sign 'Apple Development'
	THEOS_PACKAGE_INSTALL_PREFIX = /opt/simject
else
	TARGET_INSTALL_REMOTE ?= $(_THEOS_TRUE)

ifeq ($(TARGET_CODESIGN),)
# Determine the path to ldid. If it can’t be found, just use “ldid” so there’s an understandable
# “no such file or directory” error.
ifeq ($(call __executable,ldid),$(_THEOS_TRUE))
	TARGET_CODESIGN = ldid
else ifeq ($(call __executable,$(SDKBINPATH)/ldid),$(_THEOS_TRUE))
	TARGET_CODESIGN = $(SDKBINPATH)/ldid
else
	TARGET_CODESIGN = ldid
endif
endif

	TARGET_CODESIGN_FLAGS ?= -S
endif

# __invocation returns the command-line invocation for the tool specified as its argument.
ifneq ($(PREFIX),)
	# Linux, Cygwin
	__invocation = $(PREFIX)$(1)
else ifeq ($(_THEOS_PLATFORM_HAS_XCODE),$(_THEOS_TRUE))
	# macOS
	__invocation = $(shell xcrun -sdk $(_THEOS_TARGET_PLATFORM_NAME) -f $(1) 2>/dev/null)
else
	# iOS
	__invocation = $(1)
endif

# give precedence to Swift toolchains located at SWIFTBINPATH
ifeq ($(call __exists,$(SWIFTBINPATH)),$(_THEOS_TRUE))
	__invocation_swift = $(SWIFTBINPATH)/$(1)
else
	__invocation_swift = $(call __invocation,$(1))
endif

ifeq ($(_THEOS_IS_MAKE_GT_4_0),)
# Make 3 has a bug where __simplify ends up truncating text sometimes
# (root cause presently unknown). Only use __simplify for targets on
# Make >= 4
	__target_simplify = $(2)
else
	__target_simplify = $(call __simplify,$(1),$(2))
endif

TARGET_CC ?= $(call __target_simplify,TARGET_CC,$(call __invocation,$(_THEOS_TARGET_CC)))
TARGET_CXX ?= $(call __target_simplify,TARGET_CXX,$(call __invocation,$(_THEOS_TARGET_CXX)))
TARGET_LD ?= $(call __target_simplify,TARGET_LD,$(call __invocation,$(_THEOS_TARGET_CC)))
TARGET_LIPO ?= $(call __target_simplify,TARGET_LIPO,$(call __invocation,lipo))
TARGET_STRIP ?= $(call __target_simplify,TARGET_STRIP,$(call __invocation,strip))
TARGET_CODESIGN_ALLOCATE ?= $(call __target_simplify,TARGET_CODESIGN_ALLOCATE,$(call __invocation,codesign_allocate))
TARGET_LIBTOOL ?= $(call __target_simplify,TARGET_LIBTOOL,$(call __invocation,libtool))
TARGET_XCODEBUILD ?= $(call __target_simplify,TARGET_XCODEBUILD,$(call __invocation,xcodebuild))
TARGET_XCPRETTY ?= $(call __target_simplify,TARGET_XCPRETTY,$(call __invocation,xcpretty))
TARGET_SWIFTC ?= $(call __target_simplify,TARGET_SWIFTC,$(call __invocation_swift,$(_THEOS_TARGET_SWIFTC)))

TARGET_SWIFT_SUPPORT_BIN ?= $(THEOS_VENDOR_SWIFT_SUPPORT_PATH)/.theos_build/release
TARGET_ORION_BIN ?= $(THEOS_VENDOR_ORION_PATH)/.theos_build/release

TARGET_STRIP_FLAGS ?= -x

ifeq ($(TARGET_DSYMUTIL),)
	TARGET_DSYMUTIL := $(call __invocation,dsymutil)
	ifneq ($(call __executable,$(TARGET_DSYMUTIL)),$(_THEOS_TRUE))
		TARGET_DSYMUTIL := $(call __invocation,llvm-dsymutil)
		ifneq ($(call __executable,$(TARGET_DSYMUTIL)),$(_THEOS_TRUE))
			TARGET_DSYMUTIL :=
		endif
	endif
endif

_THEOS_TARGET_CC_VERSION = $(shell $(TARGET_CC) -dumpversion)

# A version specified as a target argument overrides all previous definitions.
_SDKVERSION := $(or $(__THEOS_TARGET_ARG_$(word 1,$(_THEOS_TARGET_ARG_ORDER))),$(SDKVERSION_$(THEOS_CURRENT_ARCH)),$(SDKVERSION))
_THEOS_TARGET_SDK_VERSION := $(or $(_SDKVERSION),latest)
_THEOS_TARGET_INCLUDE_SDK_VERSION := $(or $(INCLUDE_SDKVERSION),$(INCLUDE_SDKVERSION_$(THEOS_CURRENT_ARCH)),same)

_UNSORTED_SDKS := $(patsubst $(THEOS_SDKS_PATH)/$(_THEOS_TARGET_PLATFORM_SDK_NAME)%.sdk,%,$(wildcard $(THEOS_SDKS_PATH)/$(_THEOS_TARGET_PLATFORM_SDK_NAME)*.sdk))

ifneq ($(THEOS_PLATFORM_SDK_ROOT),)
	_XCODE_SDK_DIR := $(THEOS_PLATFORM_SDK_ROOT)/Platforms/$(_THEOS_TARGET_PLATFORM_SDK_NAME).platform/Developer/SDKs
	_UNSORTED_SDKS += $(patsubst $(_XCODE_SDK_DIR)/$(_THEOS_TARGET_PLATFORM_SDK_NAME)%.sdk,%,$(wildcard $(_XCODE_SDK_DIR)/$(_THEOS_TARGET_PLATFORM_SDK_NAME)*.sdk))
endif

ifeq ($(words $(_UNSORTED_SDKS)),0)
before-all::
ifeq ($(_XCODE_SDK_DIR),)
	$(ERROR_BEGIN)"You do not have any SDKs in $(THEOS_SDKS_PATH)."$(ERROR_END)
else
	$(ERROR_BEGIN)"You do not have any SDKs in $(_XCODE_SDK_DIR) or $(THEOS_SDKS_PATH)."$(ERROR_END)
endif
endif

_SORTED_SDKS = $(call __simplify,_SORTED_SDKS,$(shell echo $(_UNSORTED_SDKS) | tr ' ' $$'\n' | sort -t. -k 1,1n -k 2,2n))
_LATEST_SDK = $(call __simplify,_LATEST_SDK,$(lastword $(_SORTED_SDKS)))

ifeq ($(_THEOS_TARGET_SDK_VERSION),latest)
	override _THEOS_TARGET_SDK_VERSION := $(_LATEST_SDK)
endif

ifeq ($(_THEOS_TARGET_INCLUDE_SDK_VERSION),latest)
	override _THEOS_TARGET_INCLUDE_SDK_VERSION := $(_LATEST_SDK)
else ifeq ($(_THEOS_TARGET_INCLUDE_SDK_VERSION),same)
	override _THEOS_TARGET_INCLUDE_SDK_VERSION := $(_THEOS_TARGET_SDK_VERSION)
endif

# Can't be := since _THEOS_TARGET_DEFAULT_OS_DEPLOYMENT_VERSION isn't assigned until iphone.mk.
_THEOS_TARGET_OS_DEPLOYMENT_VERSION = $(or $(__THEOS_TARGET_ARG_$(word 2,$(_THEOS_TARGET_ARG_ORDER))),$(TARGET_OS_DEPLOYMENT_VERSION_$(THEOS_CURRENT_ARCH)),$(TARGET_OS_DEPLOYMENT_VERSION),$(_SDKVERSION),$(_THEOS_TARGET_DEFAULT_OS_DEPLOYMENT_VERSION))

ifeq ($(_THEOS_TARGET_OS_DEPLOYMENT_VERSION),latest)
	override _THEOS_TARGET_OS_DEPLOYMENT_VERSION = $(_LATEST_SDK)
endif
