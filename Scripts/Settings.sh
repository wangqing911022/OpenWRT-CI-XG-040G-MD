#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#设置 argon 为默认主题
sed -i "s|option mediaurlbase '/luci-static/bootstrap'|option mediaurlbase '/luci-static/$WRT_THEME'|" ./feeds/luci/modules/luci-base/root/etc/config/luci 2>/dev/null || true
find ./package/luci-theme-argon -type f -path '*/uci-defaults/*' -exec sed -i '/luci\.main\.mediaurlbase/d' {} + 2>/dev/null || true
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#默认时区上海，默认关闭防火墙流量分载（保留 LuCI 手动开启选项）
mkdir -p ./package/base-files/files/etc/uci-defaults
cat > ./package/base-files/files/etc/uci-defaults/99-custom-defaults <<'EOF'
#!/bin/sh
uci -q set system.@system[0].timezone='CST-8'
uci -q set system.@system[0].zonename='Asia/Shanghai'
uci -q commit system
uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci -q commit firewall
#清理全部旧主题，仅保留重新拉取的 argon
for t in $(uci -q show luci.themes | cut -d. -f3 | cut -d= -f1); do uci -q delete luci.themes.$t; done
uci -q set luci.themes.Argon='/luci-static/argon'
uci -q set luci.main.mediaurlbase='/luci-static/argon'
#清除 argon 自定义登录背景设置，恢复主题默认背景
uci -q delete argon.@global[0].background
uci -q delete argon.@global[0].background_path
uci -q set argon.@global[0].online_wallpaper='none'
uci -q set argon.@global[0].primary='#5e72e4'
uci -q set argon.@global[0].transparency='0.2'
uci -q set argon.@global[0].font_weight='600'
uci -q commit luci
uci -q commit argon
uci -q batch <<-USBWAN_EOF
delete network.usbwan
set network.usbwan=interface
set network.usbwan.proto='dhcp'
set network.usbwan.device='usb0'
set network.usbwan.metric='50'
commit network
USBWAN_EOF
if ! uci -q get firewall.usbwan >/dev/null 2>&1; then
	uci -q batch <<-USBWAN_EOF
set firewall.usbwan=zone
set firewall.usbwan.name='usbwan'
set firewall.usbwan.input='REJECT'
set firewall.usbwan.output='ACCEPT'
set firewall.usbwan.forward='REJECT'
set firewall.usbwan.masq='1'
set firewall.usbwan.mtu_fix='1'
set firewall.usbwan.network='usbwan'
add firewall forwarding
set firewall.@forwarding[-1].src='lan'
set firewall.@forwarding[-1].dest='usbwan'
commit firewall
USBWAN_EOF
fi
exit 0
EOF
chmod +x ./package/base-files/files/etc/uci-defaults/99-custom-defaults

#USB 网络共享自动配置（RNDIS/ECM/NCM）
mkdir -p ./package/base-files/files/etc/hotplug.d/net
cat > ./package/base-files/files/etc/hotplug.d/net/40-usb-tethering <<'USB_TETH_EOF'
#!/bin/sh
[ "$ACTION" = "add" ] || exit 0
[ -n "$INTERFACE" ] || exit 0
[ -e "/sys/class/net/$INTERFACE/device" ] || exit 0
DEVPATH=$(readlink -f "/sys/class/net/$INTERFACE/device" 2>/dev/null)
case "$DEVPATH" in
	*usb*) ;;
	*) exit 0 ;;
esac
uci -q get network.usbwan >/dev/null 2>&1 || {
	uci -q set network.usbwan=interface
	uci -q set network.usbwan.proto='dhcp'
	uci -q set network.usbwan.metric='50'
}
uci -q set network.usbwan.device="$INTERFACE"
uci -q commit network
/etc/init.d/network reload
/etc/init.d/firewall reload
exit 0
USB_TETH_EOF
chmod +x ./package/base-files/files/etc/hotplug.d/net/40-usb-tethering

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	#其他调整
	echo "CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y" >> ./.config

	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

#调整网口顺序
sed -i 's/ucidef_set_interface_lan "lan1 lan2 lan3 lan4"/ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" "lan4"/g' target/linux/airoha/an7581/base-files/etc/board.d/02_network
sed -i 's/interrupts.*//g' target/linux/airoha/dts/an7581-nokia_xg-040g-md-common.dtsi

