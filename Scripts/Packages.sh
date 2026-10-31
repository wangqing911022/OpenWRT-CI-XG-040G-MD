#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"

#补齐上游源码缺失的 libffi（python3、glib2 等编译依赖）
if [ ! -d "./libs/libffi" ] && [ ! -d "./libffi" ]; then
	mkdir -p ./libffi
	cp -f "$GITHUB_WORKSPACE/Packages/libffi/Makefile" ./libffi/
	echo "libffi has been added!"
fi

#设备监控（本机 + 局域网设备，Web 端口 7752）
if [ ! -d "./luci-app-systemmon" ]; then
	cp -rf "$GITHUB_WORKSPACE/Packages/luci-app-systemmon" ./
	echo "systemmon has been added!"
fi

#iStore 商店（含 taskd、luci-lib-taskd、luci-lib-xterm）
if [ ! -d "./luci-app-store" ]; then
	git clone -q --depth=1 --single-branch --branch main https://github.com/istoreos/istore.git ./istore-src
	cp -rf ./istore-src/luci/luci-app-store ./istore-src/luci/luci-lib-taskd ./istore-src/luci/luci-lib-xterm ./istore-src/luci/taskd ./
	rm -rf ./istore-src
	echo "istore has been added!"
fi

#Quickstart 首页（iStoreOS 后端 + 官方中文前端）
if [ ! -d "./quickstart" ]; then
	git clone -q --depth=1 --single-branch --branch master https://github.com/linkease/nas-packages.git ./nas-packages-src
	cp -rf ./nas-packages-src/network/services/quickstart ./
	rm -rf ./nas-packages-src
	echo "quickstart backend has been added!"
fi
if [ ! -d "./luci-app-quickstart" ]; then
	git clone -q --depth=1 --single-branch --branch main https://github.com/linkease/nas-packages-luci.git ./nas-luci-src
	cp -rf ./nas-luci-src/luci/luci-app-quickstart ./
	rm -rf ./nas-luci-src
	#修复 apk 不接受 0.12.10-r1 这种版本号
	sed -i 's/^PKG_VERSION:=0.12.10-r1$/PKG_VERSION:=0.12.10\nPKG_RELEASE:=1/' ./luci-app-quickstart/Makefile
	#移除 Quickstart 的 S.M.A.R.T. 和磁盘阵列菜单
	sed -i '/"nas", "smart"/d; /"nas", "raid"/d' ./luci-app-quickstart/luasrc/controller/quickstart.lua
	echo "official quickstart UI has been added!"
fi

#注入 PON 温度环形卡片（普通橙色）
if [ -d "./luci-app-quickstart" ]; then
	cp -f "$GITHUB_WORKSPACE/Packages/quickstart-pon-temp.js" ./luci-app-quickstart/htdocs/luci-static/quickstart/pon-temp.js
	QS_MAIN=./luci-app-quickstart/luasrc/view/quickstart/main.htm
	if [ -f "$QS_MAIN" ] && ! grep -q 'pon-temp.js' "$QS_MAIN"; then
		awk -v v="$WRT_DATE" '{ if ($0 ~ /<%\+footer%>/) print "<script src=\"/luci-static/quickstart/pon-temp.js?v=" v "\"></script>"; print }' "$QS_MAIN" > "$QS_MAIN.new" && mv "$QS_MAIN.new" "$QS_MAIN"
	fi
	echo "quickstart PON temperature card has been added!"
fi

#ONU 配置插件（naoki66/OpenWrt_ONU_CONFIG）
if [ ! -d "./luci-app-onu" ]; then
	git clone -q --depth=1 --single-branch --branch main https://github.com/naoki66/OpenWrt_ONU_CONFIG.git ./onu-config-src
	cp -rf ./onu-config-src/luci-app-onu ./
	rm -rf ./onu-config-src
	echo "luci-app-onu has been added!"
fi
#当前内核源没有 kmod-nf-conntrack-bridge，移除该可选依赖
sed -i 's/ +kmod-nf-conntrack-bridge//' ./luci-app-onu/Makefile

#Homebox / netspeedtest
if [ ! -d "./homebox" ]; then
	git clone -q --depth=1 --single-branch --branch main https://github.com/sirpdboy/netspeedtest.git ./netspeedtest-src
	cp -rf ./netspeedtest-src/homebox ./netspeedtest-src/luci-app-netspeedtest ./netspeedtest-src/ookla-speedtest ./
	rm -rf ./netspeedtest-src
	echo "netspeedtest/homebox has been added!"
fi
#修复当前软件源不存在的 python3 子包依赖
sed -i 's/ +python3-pkg-resources//; s/ +python3-email//' ./luci-app-netspeedtest/Makefile
#修复 Homebox 保存/开机自启权限
NETSPEED_ACL="./luci-app-netspeedtest/root/usr/share/rpcd/acl.d/luci-app-netspeedtest.json"
if [ -f "$NETSPEED_ACL" ]; then
	jq '.read.uci = ["netspeedtest"] | .write.uci = ["netspeedtest"] | .read.file["/etc/init.d/netspeedtest"] = ["exec"] | .write.file["/etc/config/netspeedtest"] = ["write"] | .write.file["/etc/init.d/netspeedtest"] = ["exec"]' "$NETSPEED_ACL" > "$NETSPEED_ACL.tmp" && mv "$NETSPEED_ACL.tmp" "$NETSPEED_ACL"
fi
#点击启动/停止时同时保存自动启动状态
sed -i "s|controlService(action, state.port)|saveConfiguration(state.port, action === 'start').then(function() { return controlService(action, state.port); })|" ./luci-app-netspeedtest/htdocs/luci-static/resources/view/netspeedtest/homebox.js

#任务计划
if [ ! -d "./luci-app-taskplan" ]; then
	git clone -q --depth=1 --single-branch --branch main https://github.com/sirpdboy/luci-app-taskplan.git ./taskplan-src
	cp -rf ./taskplan-src/luci-app-taskplan ./
	rm -rf ./taskplan-src
	echo "luci-app-taskplan has been added!"
fi

#流量统计（LuCI + 后端）
if [ ! -d "./luci-app-wrtbwmon" ]; then
	git clone -q --depth=1 --single-branch --branch master https://github.com/brvphoenix/luci-app-wrtbwmon.git ./wrtbwmon-src
	cp -rf ./wrtbwmon-src/luci-app-wrtbwmon ./
	rm -rf ./wrtbwmon-src
	echo "luci-app-wrtbwmon has been added!"
fi
if [ ! -d "./wrtbwmon" ]; then
	git clone -q --depth=1 --single-branch --branch master https://github.com/brvphoenix/wrtbwmon.git ./wrtbwmon-backend-src
	cp -rf ./wrtbwmon-backend-src/wrtbwmon ./
	rm -rf ./wrtbwmon-backend-src
	echo "wrtbwmon backend has been added!"
fi

#官方 Argon 主题 v3.1.1（自带配置页面和 bg1.webp 默认登录背景）
UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "v3.1.1"
if [ -f "./luci-theme-argon/root/etc/config/argon" ]; then
	sed -i "s/option font_weight '.*'/option font_weight 'normal'/" ./luci-theme-argon/root/etc/config/argon
	grep -q "option font_weight" ./luci-theme-argon/root/etc/config/argon || sed -i "/option mode 'normal'/a\\\toption font_weight 'normal'" ./luci-theme-argon/root/etc/config/argon
	sed -i "s/option online_wallpaper '.*'/option online_wallpaper 'none'/" ./luci-theme-argon/root/etc/config/argon
fi

#UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
#UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
#UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
#UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

#UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

#UPDATE_PACKAGE "athena-led" "unraveloop/JDC-AX6600-Athena-LED-Controller" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
#UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
#UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
#UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
#UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
#UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
#UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
#UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
#UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
#UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
#UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
#UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "gecoosac luci-app-timewol luci-app-wolplus"
#UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"
UPDATE_PACKAGE "luci-app-airoha-npu" "luanmuc/luci-app-airoha-npu" "main"
UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"
UPDATE_PACKAGE "luci-app-tailscale-community" "Tokisaki-Galaxy/luci-app-tailscale-community" "master" "" "luci-app-tailscale-community"

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
UPDATE_VERSION "sing-box"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
