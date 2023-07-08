OpenWrt/LEDE LuCI for HAProxy-TCP
===

简介
---

本软件包是 HAProxy-TCP 的 LuCI 控制界面,

软件包文件结构:
```
/
├── etc/
│   ├── config/
│   │   └── haproxy-tcp                            // UCI 配置文件
│   │── init.d/
│   │   └── haproxy-tcp                            // init 脚本
│   └── uci-defaults/
│       └── luci-haproxy-tcp                       // uci-defaults 脚本
└── usr/
    └── lib/
        └── lua/
            └── luci/                          // LuCI 部分
                ├── controller/
                │   └── haproxy-tcp.lua            // LuCI 菜单配置
                ├── i18n/                      // LuCI 语言文件目录
                │   └── haproxy-tcp.zh-cn.lmo
                └── model/
                    └── cbi/
                        └── haproxy-tcp.lua         // LuCI 基本设置
```

依赖
---

软件包的正常使用需要依赖 `haproxy` .  

预览
---
![preview](https://github.com/chenhw2/luci-app-haproxy-tcp/blob/master/preview.png)

配置
---

软件包的配置文件路径: `/etc/config/haproxy-tcp`  
此文件为 UCI 配置文件, 配置方式可参考 [Wiki -> Use-UCI-system][Use-UCI-system] 和 [OpenWrt Wiki][uci]  

编译
---

从 OpenWrt 的 [SDK][openwrt-sdk] 编译  
```bash
# 解压下载好的 SDK
tar xjf OpenWrt-SDK-ar71xx-for-linux-x86_64-gcc-4.8-linaro_uClibc-0.9.33.2.tar.bz2
cd OpenWrt-SDK-ar71xx-*
# Clone 项目
git clone https://github.com/chenhw2/luci-app-haproxy-tcp.git package/feeds/luci-app-haproxy-tcp
# 编译 po2lmo (如果有po2lmo可跳过)
pushd package/feeds/luci-app-haproxy-tcp/tools/po2lmo
make && sudo make install
popd
# 选择要编译的包 LuCI -> 3. Applications
make menuconfig
# 开始编译
make package/feeds/luci-app-haproxy-tcp/compile V=s
```

 [openwrt-sdk]: https://wiki.openwrt.org/doc/howto/obtain.firmware.sdk
 [Use-UCI-system]: https://github.com/shadowsocks/luci-app-shadowsocks/wiki/Use-UCI-system
 [uci]: https://wiki.openwrt.org/doc/uci
