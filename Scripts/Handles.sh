#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	#修复 Argon 首页内存/磁盘/网络进度条显示异常（新版 LuCI 状态页不使用 conic-gradient 标记）
	for ARGON_CSS in ./htdocs/luci-static/argon/css/cascade.css ./luci-theme-argon/htdocs/luci-static/argon/css/cascade.css; do
		if [ -f "$ARGON_CSS" ]; then
			sed -i '/^body\[data-page="admin-status-overview"\] \.cbi-progressbar,$/,/^#modal_overlay {$/{/^#modal_overlay {$/!d}' "$ARGON_CSS"
			cat >> "$ARGON_CSS" <<'ARGON_PROGRESS_FIX'
/* Align status page memory/storage percentage text inside the progress bar */
[data-page="admin-status-overview"] .cbi-progressbar,
[data-page="admin-status"] .cbi-progressbar {
  display: block;
  position: relative;
  width: 100%;
  min-width: 0;
  height: 1.3rem;
  min-height: 1.3rem;
  margin: 0.15rem 0;
  background: var(--progress-bg, #eee);
  border-radius: var(--radius-pill, 999px);
  overflow: hidden;
}
[data-page="admin-status-overview"] .cbi-progressbar::before,
[data-page="admin-status"] .cbi-progressbar::before {
  display: none;
}
[data-page="admin-status-overview"] .cbi-progressbar > div,
[data-page="admin-status"] .cbi-progressbar > div {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background-color: var(--progress-fill, var(--primary, #5e72e4));
  border-radius: inherit;
}
[data-page="admin-status-overview"] .cbi-progressbar::after,
[data-page="admin-status"] .cbi-progressbar::after {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 0.4rem;
  font-size: 0.7rem;
  line-height: 1;
  color: var(--progressbar-font-color, var(--text-strong, #2e2b60));
  text-align: center;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  direction: ltr;
  unicode-bidi: isolate;
  z-index: 2;
}
ARGON_PROGRESS_FIX
		fi
	done
	for ARGON_DARK in ./htdocs/luci-static/argon/css/dark.css ./luci-theme-argon/htdocs/luci-static/argon/css/dark.css; do
		[ -f "$ARGON_DARK" ] && sed -i '/^body\[data-page="admin-status-overview"\] \.cbi-progressbar/,/^}$/d' "$ARGON_DARK"
	done

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi

#修复 LuCI 批量 RPC 只在 requestAnimationFrame 回调里发送导致的页面卡死
#（后台标签页、被遮挡的窗口或 WebView 中 rAF 被浏览器停掉时，所有 ubus 请求不会发出，
# 页面会一直停在“加载视图中…”）
LUCI_JS=$(find ../feeds/luci/ -maxdepth 8 -type f -path "*/htdocs/luci-static/resources/luci.js" | head -n 1)
if [ -n "$LUCI_JS" ] && [ -f "$LUCI_JS" ]; then
	echo " "

	sed -i 's/requestAnimationFrame(flushRequestQueue)/setTimeout(flushRequestQueue,0)/g' "$LUCI_JS"

	grep -q 'setTimeout(flushRequestQueue,0)' "$LUCI_JS" && echo "luci.js request batching has been fixed!"
fi
