#!/bin/bash
cd $GITHUB_WORKSPACE/openwrt

# ====================== 1.创建WED控制面板自定义插件 ======================
mkdir -p package/custom/wedctrl

cat > package/custom/wedctrl/luci-controller-wedctrl.lua << 'EOF'
module("luci.controller.wedctrl", package.seeall)
function index()
    entry({"admin", "services", "wedctrl"}, cbi("wedctrl"), "WED硬件加速控制", 60).dependent=false
end
EOF

cat > package/custom/wedctrl/luci-model-cbi-wedctrl.lua << 'EOF'
local m = Map("firewall", "WED硬件加速开关控制")
local s = m:section(NamedSection, "defaults", "firewall")
s:option(Flag, "flow_offloading_hw", "启用WED硬件NAT加速")
return m
EOF

cat > package/custom/wedctrl/Makefile << 'EOF'
include $(TOPDIR)/rules.mk
LUCI_TITLE:=WED硬件加速控制面板
LUCI_DEPENDS:=
include $(TOPDIR)/feeds/luci/luci.mk
# call BuildPackage - OpenWrt buildroot signature
EOF

# ====================== 2.内置自动切换脚本到/root ======================
mkdir -p files/root
cat > files/root/wed_auto_switch.sh << 'EOF'
#!/bin/bash
AUTO_WED_ENABLE=$(uci get firewall.@wed_auto[0].enable 2>/dev/null)
[ -z "$AUTO_WED_ENABLE" ] && AUTO_WED_ENABLE=1
if [ "$AUTO_WED_ENABLE" -eq 0 ];then
    exit 0
fi
CLASH_RUN=$(pgrep -f clash)
DAE_RUN=$(pgrep -f dae)
HW_OFFLOAD=$(uci get firewall.@defaults[0].flow_offloading_hw)
if [ -n "$CLASH_RUN" ] || [ -n "$DAE_RUN" ];then
    if [ "$HW_OFFLOAD" = "1" ];then
        uci set firewall.@defaults[0].flow_offloading_hw='0'
        uci commit firewall
        /etc/init.d/firewall restart
        logger "WED自动切换:检测代理运行，关闭硬件加速"
    fi
else
    if [ "$HW_OFFLOAD" = "0" ];then
        uci set firewall.@defaults[0].flow_offloading_hw='1'
        uci commit firewall
        /etc/init.d/firewall restart
        logger "WED自动切换:无代理，开启硬件加速"
    fi
fi
EOF
chmod +x files/root/wed_auto_switch.sh

# ====================== 3.硬件自检脚本 ======================
cat > files/root/bpi_check.sh << 'EOF'
#!/bin/bash
echo "=============================================="
echo "    BPI‑R4‑PRO‑8X ImmortalWrt 自检工具"
echo "=============================================="
echo "[存储]"
lsblk
echo "[温度]"
cat /sys/class/thermal/thermal_zone0/temp
echo "[进程检查]"
pgrep clash
pgrep dae
echo "[防火墙硬件加速]"
uci get firewall.@defaults[0].flow_offloading_hw
echo "自检完成"
EOF
chmod +x files/root/bpi_check.sh

# ====================== 4.预置LAN IP：192.168.55.1 ======================
mkdir -p files/etc/config
cat > files/etc/config/network << 'EOF'
config interface 'loopback'
        option proto 'static'
        option ipaddr '127.0.0.1'
        option netmask '255.0.0.0'

config globals 'globals'
        option ula_prefix 'fd55:5555:5555::/48'

config interface 'lan'
        option type 'bridge'
        option proto 'static'
        option ipaddr '192.168.55.1'
        option netmask '255.255.255.0'
        option ip6assign '60'
EOF

# ====================== 全部第三方插件，git clone拉取到package目录 ======================
cd package
# QModem 5G模组
git clone --depth 1 https://github.com/FUjr/QModem.git qmodem
# OpenClash
git clone --depth 1 https://github.com/vernesong/OpenClash.git openclash
# DAE内核转发
git clone --depth 1 https://github.com/daeuniverse/dae-openwrt.git dae
# Argon主题
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git argon-theme
# Argon设置面板
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git argon-config
# CPU温度挂件
git clone --depth 1 https://github.com/gSpotx2f/luci-app-temp-status.git tempstatus
# PWM风扇
git clone --depth 1 https://github.com/openwrt-packages/luci-app-pwm-fan.git pwmfan

cd ..
