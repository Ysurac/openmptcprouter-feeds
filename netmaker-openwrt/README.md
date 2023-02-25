# Netmaker-OpenWRT

[Netmaker](https://github.com/gravitl/netmaker) is a platform for creating and managing fast, secure, and dynamic virtual overlay networks using WireGuard. This project offers OpenWRT packages for Netmaker.

## Installing package

Download the prebuild package and copy it onto your OpenWRT installation, preferably into the `/tmp` folder.

Then install the ipk package file:

```bash
opkg install netmaker_*.ipk
```

Now start `netclient` of Netmaker:

```bash
/etc/init.d/netclient start
```

## Compiling from Sources

To include Netmaker into your OpenWRT image or to create an `.ipk` package (equivalent to Debians .deb files), you have to build an OpenWRT image.

Now prepare OpenWRT:

```bash
git clone https://github.com/openwrt/openwrt
cd openwrt

./scripts/feeds update -a
./scripts/feeds install -a
```

To build Netmaker for OpenWRT, you need to have Golang with OpenWRT build envirment. Then, you can insert the Netmaker package using a package feed or add the package manually.

### Add package by feed

A feed is the standard way packages are made available to the OpenWRT build system.

Put this line in your feeds list file (e.g. feeds.conf.default)

```bash
src-git netmaker http://github.com/sbilly/netmaker-openwrt.git
```

Update and install the new feed

```bash
./scripts/feeds update netmaker
./scripts/feeds install netmaker
```

Now continue with the building packages section.

## Building Packages

Configure packages:

```bash
make menuconfig
```

Now select the appropiate "Target System" and "Target Profile" depending on what target chipset/router you want to build for. Also mark the Netmaker package under  `Network ---> VPN ---> <*> netmaker`.

Now compile/build everything:

```bash
make
```

The images and all *.ipk packages are now inside the bin/ folder, including the netmaker package. You can install the Netmaker .ipk on the target device using opkg install <ipkg-file>.

For details please check the OpenWRT documentation.

## Build bulk packages

For a release, it is useful the build packages at a bulk for multiple targets:

```shell
#!/bin/sh

# dump-target-info.pl is used to get all targets configurations:
# https://git.openwrt.org/?p=openwrt/openwrt.git;a=blob;f=scripts/dump-target-info.pl

./scripts/dump-target-info.pl architectures | while read pkgarch target1 rest; do
  echo "CONFIG_TARGET_${target1%/*}=y" > .config
  echo "CONFIG_TARGET_${target1%/*}_${target1#*/}=y" >> .config
  echo "CONFIG_PACKAGE_example1=y" >> .config

  # Debug output
  echo "pkgarch: $pkgarch, target1: $target1"

  make defconfig
  make -j4 tools/install
  make -j4 toolchain/install

  # Build package
  make package/netmaker/{clean,compile}

  # Free space (optional)
  rm -rf build_dir/target-*
  rm -rf build_dir/toolchain-*
done
```

## Thanks

- [netmaker](https://github.com/gravitl/netmaker)
- [zerotier-openwrt](https://github.com/mwarning/zerotier-openwrt)
- [openwrt-golang-package-test-feed](https://github.com/jefferyto/openwrt-golang-package-test-feed)
