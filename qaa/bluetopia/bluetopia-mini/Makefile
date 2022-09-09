include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_SOURCE_NAME:=bluetopia
PKG_NAME:=bluetopia-mini
PKG_VERSION:=4.2.1.c1_26
PKG_DIST_VERSION:=4.2.1.c1
PKG_RELEASE:=1
PKG_FOLDER=BLUETOPIA

PKG_SOURCE:=$(PKG_SOURCE_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/cnss_win/santaclara/dev01/$(PKG_FOLDER)/
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_DIST_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_DIST_VERSION)
PKG_MD5SUM:=ad1a200e30c51254bf1f63b948134037

# Bluetopia Root Paths
export BLUETOPIA_SOURCE_PATH:=$(PKG_BUILD_DIR)/bt_host/Build
export BLUETOPIAPM_SOURCE_PATH:=$(PKG_BUILD_DIR)/bt_host_pm/Build
export BLUETOPIA_ROOT_PATH:=$(PKG_DIST_DIR)/Bluetopia_Dist
export BTPM_DIST_PATH:=$(PKG_DIST_DIR)/BluetopiaPM_Dist

# Bluetopia Core Include and Library Path
BLUETOPIA_INCLUDE_PATH:=$(BLUETOPIA_ROOT_PATH)/include
export BLUETOPIA_LIB_PATH:=$(BLUETOPIA_ROOT_PATH)/lib

# Bluetopia Debug Include and Library Path
BLUETOPIA_DEBUG_INCLUDE_PATH:=$(BLUETOPIA_ROOT_PATH)/debug/include
BLUETOPIA_DEBUG_LIB_PATH:=$(BLUETOPIA_ROOT_PATH)/debug/lib

# Bluetopia Profiles Root Path
export BLUETOPIA_PROFILE_ROOT_PATH:=$(BLUETOPIA_ROOT_PATH)/profiles

# Bluetopia VSER Include and Library Path
BLUETOPIA_VSER_INCLUDE_PATH:=$(BLUETOPIA_ROOT_PATH)/VSER/include
BLUETOPIA_VSER_LIB_PATH:=$(BLUETOPIA_ROOT_PATH)/VSER/lib

# Bluetopia VNET Include and Library Path
BLUETOPIA_VNET_INCLUDE_PATH:=$(BLUETOPIA_ROOT_PATH)/VNET/include
BLUETOPIA_VNET_LIB_PATH:=$(BLUETOPIA_ROOT_PATH)/VNET/lib

# Bluetopia SBC Include and Library Path
BLUETOPIA_SBC_INCLUDE_PATH:=$(BLUETOPIA_ROOT_PATH)/SBC/include
BLUETOPIA_SBC_LIB_PATH:=$(BLUETOPIA_ROOT_PATH)/SBC/lib

# Bluetopia Simple XML Parser Path
export BLUETOPIA_XML_PATH:=$(BLUETOPIA_ROOT_PATH)/XML/SS1SXMLP

# Bluetopia Distribution Path
export BLUETOPIA_PATH:=$(BLUETOPIA_ROOT_PATH)


include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QTI
  CATEGORY:=QTI software
  TITLE:=$(1) - QTI mini-Bluetopia
  DEPENDS:=+libpthread +libopenssl
endef

define Package/$(PKG_NAME)/description
  This package contains mini-Bluetopia PM and mini-Bluetopia binaries
endef

SOC=DK07
ifneq (, $(findstring $(SUBTARGET), ipq50xx ipq50xx_64))
    SOC=Maple
endif

TARGET_CFLAGS += -Werror -Wall

MAKE_FLAGS="CC=$$(TARGET_CC)" \
	   "GLOBLDFLAGS=$$(TARGET_LDFLAGS)" \
	   "GLOBCFLAGS=$$(TARGET_CFLAGS)" \
	   "GLOBLDLIBS= -lssl -lcrypto"

MAKE_KWFLAG_BTPSKRNL="CC=$$(TARGET_CC)" \
           "GLOBLDFLAGS=$$(TARGET_LDFLAGS)" \
           "GLOBCFLAGS=$$(TARGET_CFLAGS) -DBTPS_KERNEL_USE_C_RUN_TIME_IMPLEMENTATION=0"

INCLDIRS = -I$(BLUETOPIA_INCLUDE_PATH)        \
	   -I$(BLUETOPIA_DEBUG_INCLUDE_PATH)  \
	   -I$(BLUETOPIA_VSER_INCLUDE_PATH)   \
	   -I$(BLUETOPIA_VNET_INCLUDE_PATH)   \
	   -I$(BLUETOPIA_SBC_INCLUDE_PATH)

LIBDIRS = -L$(BLUETOPIA_LIB_PATH)          \
	  -L$(BLUETOPIA_DEBUG_LIB_PATH)    \
	  -L$(BLUETOPIA_VSER_LIB_PATH)     \
	  -L$(BLUETOPIA_VNET_LIB_PATH)     \
	  -L$(BLUETOPIA_SBC_LIB_PATH)

PM_MAKE_FLAGS="CC=$$(TARGET_CC)" \
	   "GLOBLDFLAGS=$$(TARGET_LDFLAGS)" \
	   "GLOBCFLAGS=$$(TARGET_CFLAGS)" \
	   "BLUETOPIA_INCLUDE_PATH=$$(BLUETOPIA_ROOT_PATH)/include" \
	   "GLOBLDLIBS= -lssl -lcrypto"

define Build/Prepare
	$(TAR) xjvf $(TOPDIR)/dl/$(PKG_SOURCE) -C $(PKG_BUILD_DIR)
	$(Build/Patch)
	$(CP) $(PKG_BUILD_DIR)/bt_host/Build/Ports/Platform/$(SOC)/* $(PKG_BUILD_DIR)/bt_host/Build/Linux/
ifeq ($(SOC), DK07)
	$(CP) $(PKG_BUILD_DIR)/bt_host/Build/Ports/Common/btpssec/openssl/* $(PKG_BUILD_DIR)/bt_host/Build/Linux/btpssec/
endif
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/btpscert  -f BTPSCERT.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/btpsfile  -f BTPSFILE.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/btpskrnl  -f BTPSKRNL.mak all $(MAKE_KWFLAG_BTPSKRNL)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/btpsvend  -f BTPSVEND.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/btpssec -f BTPSSEC.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/debug/SS1BTDBG   -f SS1BTDBG.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/hcidrv_lin  -f HCIDRV.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/ss1btps  -f SS1BTPS.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/ss1btle  -f SS1BTPS.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/VSER/SS1SER  -f SS1SER.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/VSER/SS1VSER  -f SS1VSER.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/VNET/SS1VNET  -f SS1VNET.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/XML/SS1SXMLP  -f SS1SXMLP.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/profiles/GATT -f SS1BTGAT.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/profiles/GATT -f SS1BTGAT_LE.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/profiles_gatt/GAPS -f SS1BTGAP.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/profiles_gatt/DIS -f SS1BTDIS.mak all $(MAKE_FLAGS)

ifeq ($(SOC), DK07)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/profiles_gatt/sample/LinuxSPPLE -f LinuxSPPLE.mak all $(MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host/Build/Linux/sample/LinuxSPP -f LinuxSPP.mak all $(MAKE_FLAGS)
endif

	echo 'creating mini-Bluetopia Dist area'
	/bin/sh $(PKG_BUILD_DIR)/bt_host/Build/MakeFull_win.sh /d $(BLUETOPIA_ROOT_PATH) /s $(BLUETOPIA_SOURCE_PATH)
	echo 'done creating mini-Bluetopia Dist area'

	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmcert -f BTPMCERT.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmdbg -f BTPMDBG.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmerr -f BTPMERR.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmset -f BTPMSET.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmipc/client -f BTPMIPC.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmipc/server -f BTPMIPC.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmmodc/client -f BTPMMODC.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmmodc/server -f BTPMMODC.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmscom/client -f BTPMSCOM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmscom/server -f BTPMSCOM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmsppm/client -f BTPMSPPM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmsppm/server -f BTPMSPPM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmgatm/client -f BTPMGATM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmgatm/server -f BTPMGATM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmdevm/client -f BTPMDEVM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/btpmdevm/server -f BTPMDEVM.mak all $(PM_MAKE_FLAGS)

	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/ss1btpml/client -f SS1BTPML.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/ss1btpml/server -f SS1BTPML.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/ss1btpm/client -f SS1BTPM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/ss1btpm/server -f SS1BTPM.mak all $(PM_MAKE_FLAGS)

ifeq ($(SOC), Maple)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/sample/LinuxSPPLE_PM -f LinuxSPPLE_PM.mak all $(PM_MAKE_FLAGS)
	$(MAKE) -C $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/sample/LinuxSPPM -f LinuxSPPM.mak all $(PM_MAKE_FLAGS)
endif

	echo 'creating mini-BluetopiaPM Dist area with default interval 20sec'
	/bin/sh $(PKG_BUILD_DIR)/bt_host_pm/Build/MakeFull.sh /d $(BTPM_DIST_PATH) /s $(BLUETOPIAPM_SOURCE_PATH)
	echo 'done creating mini-Bluetopia Dist area'
endef


define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin

ifeq ($(SOC), DK07)
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_DIR) $(1)/etc/init.d $(1)/etc/profile.d
	$(INSTALL_BIN) ./files/PS_KEY_CSR8811.txt $(1)/usr/bin
	$(INSTALL_BIN) ./files/bluetopia.init $(1)/etc/init.d/bluetopia
	$(INSTALL_BIN) ./files/bt_env.sh $(1)/etc/profile.d/bt_env.sh
	$(INSTALL_BIN) \
	    $(PKG_BUILD_DIR)/bt_host/Build/Linux/profiles_gatt/sample/LinuxSPPLE/LinuxSPPLE $(1)/usr/bin
	$(INSTALL_BIN) \
	    $(PKG_BUILD_DIR)/bt_host/Build/Linux/sample/LinuxSPP/LinuxSPP  $(1)/usr/bin
endif

ifeq ($(SOC), Maple)
	$(INSTALL_BIN) \
	    $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/ss1btpm/server/SS1BTPM  $(1)/usr/bin
	$(INSTALL_BIN) \
	    $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/sample/LinuxSPPLE_PM/LinuxSPPLE_PM  $(1)/usr/bin
	$(INSTALL_BIN) \
	    $(PKG_BUILD_DIR)/bt_host_pm/Build/Linux/sample/LinuxSPPM/LinuxSPPM  $(1)/usr/bin
endif
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
