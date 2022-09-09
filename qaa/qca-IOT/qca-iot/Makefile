
include $(TOPDIR)/rules.mk

PKG:=QCA402X_HOST_SDK
PKG_NAME:=qca-IOT
PKG_FOLDER:=CNSS_W.QZ.3.0
PKG_VERSION:=CNSS_W.QZ.3.0-00110-QZHW4024-2

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.bz2
PKG_SOURCE_URL:=http://qcawebsrvr.qualcomm.com/cnss_win/santaclara/dev01/$(PKG_FOLDER)/$(PKG_VERSION)
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
RSTRIP:=true

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=QCA
  CATEGORY:=$(QTI_SOFTWARE_CATEGORY)
  TITLE:=$(1) - QCA402x
  DEPENDS:= @TARGET_ipq_ipq807x||TARGET_ipq_ipq807x_64||TARGET_ipq_ipq60xx||TARGET_ipq_ipq60xx_64 +kmod-tun +@KERNEL_POSIX_MQUEUE
endef

define Package/$(PKG_NAME)/description
  This package contains BLE /Zigbee/ Thread binaries for QCA402x
endef

MAKE_FLAGS="HOST_CROSS_COMPILE=$(SUBTARGET)" \
           "CC=$(TARGET_CC) -Werror -Wall -Wl,-z,now -Wl,-z,relro -fpie -pie"

define Build/Compile
	make -C $(PKG_BUILD_DIR)/exthost/Linux/qapi $(MAKE_FLAGS)
	make -C $(PKG_BUILD_DIR)/exthost/Linux/daemon $(MAKE_FLAGS)
	make -C $(PKG_BUILD_DIR)/exthost/Linux/app/NB_QCLI_demo/build $(MAKE_FLAGS)
	make -C $(PKG_BUILD_DIR)/exthost/Linux/app/diag_demo/build $(MAKE_FLAGS)
endef

define Package/qca-IOT/config
	source "$(SOURCE)/Config.in"
endef

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include/qca-iot
	$(INSTALL_DIR) $(1)/usr/lib
	cp $(PKG_BUILD_DIR)/exthost/Linux/diag/diag_api.h $(1)/usr/include/qca-iot/
	cp $(PKG_BUILD_DIR)/quartz/serializer/framework/common/qsCommon.h $(1)/usr/include/qca-iot/
	cp $(PKG_BUILD_DIR)/quartz/serializer/framework/host/qsHost.h $(1)/usr/include/qca-iot/
	cp $(PKG_BUILD_DIR)/quartz/serializer/framework/OSAL/include/qsOSAL.h $(1)/usr/include/qca-iot/
	cp $(PKG_BUILD_DIR)/quartz/serializer/framework/common/qsPack.h $(1)/usr/include/qca-iot/
	cp $(PKG_BUILD_DIR)/quartz/serializer/framework/common/qsPack.h $(1)/usr/include/qca-iot/
	cp $(PKG_BUILD_DIR)/exthost/Linux/app/diag_demo/build/libdiag_demo.so $(1)/usr/lib/
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/lib
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/exthost/Linux/daemon/output/iotd $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/exthost/Linux/daemon/iotd_config.ini $(1)/usr/bin/iotd_config_dk.ini
	$(INSTALL_BIN) ./files/iotd_config_hk.ini $(1)/usr/bin/iotd_config_hk.ini
	$(INSTALL_BIN) ./files/iotd_config_cp01.ini $(1)/usr/bin/iotd_config_cp01.ini
	$(INSTALL_BIN) ./files/iotd_config_cp02.ini $(1)/usr/bin/iotd_config_cp02.ini
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/exthost/Linux/app/NB_QCLI_demo/build/nb_demo $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/cortex-m0/threadx/ioe_ram_m0_threadx_ipt.mbn ./files/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/quartz/demo/HostedMode_demo/build/gcc/output.cdb/Quartz_HASHED.elf ./files/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/tools/fwupgrade/* ./files/
	python ./files/gen_fw_upgrade_img.py --xml ./files/fw_upgrade.xml --output ./files/Quartz_FW_UP.bin
	$(INSTALL_BIN) ./files/Quartz_FW_UP.bin $(1)/usr/bin/
	$(INSTALL_BIN) ./files/qca-iot.init $(1)/etc/init.d/qca-iot
	$(INSTALL_BIN) ./files/qca402x_flash.sh $(1)/usr/bin/qca402x_flash.sh
	cp $(PKG_BUILD_DIR)/exthost/Linux/app/diag_demo/build/libdiag_demo.so $(1)/usr/lib/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

