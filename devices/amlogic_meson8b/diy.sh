#!/bin/bash

shopt -s extglob

SHELL_FOLDER=$(dirname $(readlink -f "$0"))

#bash $SHELL_FOLDER/../common/kernel_6.1.sh

#rm -rf package/kernel/mac80211

#git_clone_path c640f7b93736621b4d56627e4f6ab824093f9c3d https://github.com/openwrt/openwrt package/kernel/mac80211

sed -i 's/Os/O2/g' include/target.mk

git_clone_path master https://github.com/coolsnowwolf/lede target/linux/amlogic

install -m 0755 "$SHELL_FOLDER/gen_aml_emmc_img.sh" \
	target/linux/amlogic/image/gen_aml_emmc_img.sh

# Only import OpenClash. Scanning the entire op-packages feed pulls thousands of
# unrelated packages and currently fails on malformed package metadata.
git_clone_path main https://github.com/kiddin9/op-packages luci-app-openclash
mkdir -p package/openclash
mv luci-app-openclash package/openclash/

# Pin stable AdGuard Home/OpenWrt integration revisions for reproducible builds.
git_clone_path 2a621bc4473b0e4efeff563dfa281a06eb3e0af7 \
	https://github.com/openwrt/packages net/adguardhome
rm -rf feeds/packages/net/adguardhome
mv net/adguardhome feeds/packages/net/
rmdir net

git_clone_path 42d72f79cd8f057f241595abc761b39dab2d9f07 \
	https://github.com/openwrt/luci applications/luci-app-adguardhome
rm -rf feeds/luci/applications/luci-app-adguardhome
mv applications/luci-app-adguardhome feeds/luci/applications/
rmdir applications

# PassWall's latest stable LuCI release, with only the packages needed by the
# nftables/Xray configuration selected in this target's config fragment.
mkdir -p package/passwall-luci package/passwall-packages
(
	cd package/passwall-luci
	git_clone_path 548a6e454ec805c5d8c8135740028cd70fe909d8 \
		https://github.com/Openwrt-Passwall/openwrt-passwall luci-app-passwall
)
(
	cd package/passwall-packages
	git_clone_path e13e4631699ef9f0e826d36d3be56a67a82924c9 \
		https://github.com/Openwrt-Passwall/openwrt-passwall-packages \
		chinadns-ng dns2socks ipt2socks microsocks tcping xray-core
)

mv -f target/linux/amlogic/patches-6.6 target/linux/amlogic/patches-6.12
mv -f target/linux/amlogic/config-6.6 target/linux/amlogic/config-6.12
mv -f target/linux/amlogic/meson8b/config-6.6 target/linux/amlogic/meson8b/config-6.12

sed -i -e "s/KERNEL_PATCHVER:=6.6/KERNEL_PATCHVER:=6.12/" \
       -e "/KERNEL_TESTING_PATCHVER/d" \
       -e "/autocore-arm/d" \
	   -e "s/ pci pcie//" \
target/linux/amlogic/Makefile

rm -rf target/linux/amlogic/patches-6.12/{001-dts-s905d-fix-high-load.patch,902-use-system-LED-for-OpenWrt.patch}
