#!/bin/bash

# Router Reset Script
# Script untuk membatalkan dan mereset konfigurasi router ke kondisi awal

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${RED}================================${NC}"
echo -e "${RED}  Router Configuration Reset${NC}"
echo -e "${RED}================================${NC}"
echo ""
echo -e "${YELLOW}⚠ Script ini akan:${NC}"
echo "  - Menghapus semua konfigurasi router"
echo "  - Uninstall dnsmasq dan iptables-persistent"
echo "  - Reset IP Forwarding ke default"
echo "  - Menghapus semua iptables rules"
echo "  - Restore sysctl.conf ke default"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: Script harus dijalankan sebagai root${NC}"
   exit 1
fi

read -p "Apakah Anda yakin ingin mereset semua konfigurasi? (y/n): " CONFIRM
if [[ $CONFIRM != [yY] ]]; then
    echo -e "${YELLOW}Reset dibatalkan${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}=== MEMULAI RESET ===${NC}"
echo ""

# Step 1: Stop services
echo -e "${YELLOW}[1/6] Menghentikan services...${NC}"
systemctl stop dnsmasq 2>/dev/null || true
systemctl disable dnsmasq 2>/dev/null || true
echo -e "${GREEN}✓ Services dihentikan${NC}"

# Step 2: Uninstall packages
echo -e "${YELLOW}[2/6] Uninstall dnsmasq dan iptables-persistent...${NC}"
apt-get remove -y -qq dnsmasq iptables-persistent > /dev/null 2>&1 || true
apt-get autoremove -y -qq > /dev/null 2>&1 || true
echo -e "${GREEN}✓ Packages dihapus${NC}"

# Step 3: Flush dan reset iptables
echo -e "${YELLOW}[3/6] Reset iptables rules...${NC}"
iptables -t nat -F 2>/dev/null || true
iptables -t nat -X 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -t mangle -X 2>/dev/null || true
iptables -F 2>/dev/null || true
iptables -X 2>/dev/null || true
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -P OUTPUT ACCEPT 2>/dev/null || true
iptables -P FORWARD ACCEPT 2>/dev/null || true

# Restore default iptables
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT

# Save ke rules yang kosong
echo "*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
COMMIT
*mangle
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
COMMIT" > /etc/iptables/rules.v4 2>/dev/null || true

echo -e "${GREEN}✓ iptables rules direset${NC}"

# Step 4: Reset IP Forwarding
echo -e "${YELLOW}[4/6] Reset IP Forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=0 > /dev/null 2>&1
sed -i 's/^net.ipv4.ip_forward=1/#net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p > /dev/null 2>&1
echo -e "${GREEN}✓ IP Forwarding direset${NC}"

# Step 5: Restore dnsmasq config
echo -e "${YELLOW}[5/6] Restore dnsmasq configuration...${NC}"
if [ -f /etc/dnsmasq.conf.backup ]; then
    mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf
    echo -e "${GREEN}✓ Backup dnsmasq dikembalikan${NC}"
elif [ -f /etc/dnsmasq.conf ]; then
    rm -f /etc/dnsmasq.conf
    echo -e "${GREEN}✓ dnsmasq config dihapus${NC}"
fi

# Step 6: Flush IP dari interfaces
echo -e "${YELLOW}[6/6] Reset network interfaces...${NC}"
echo ""
echo "Interface yang tersedia:"
ip link show | grep -E "^\d+:" | awk -F': ' '{print $2}' | head -20
echo ""
echo "Masukkan interface yang ingin di-reset (bisa multiple, pisahkan dengan spasi)"
echo "Contoh: enp1s0 enxc8a362414ac4 wlp2s0"
read -p "Interface: " INTERFACES

for INT in $INTERFACES; do
    if ip link show $INT > /dev/null 2>&1; then
        ip addr flush dev $INT 2>/dev/null || true
        ip link set $INT down 2>/dev/null || true
        echo -e "${GREEN}✓ Interface $INT direset${NC}"
    else
        echo -e "${YELLOW}⚠ Interface $INT tidak ditemukan${NC}"
    fi
done

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Reset Selesai!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Status:${NC}"
echo "✓ Semua services dihentikan"
echo "✓ dnsmasq dan iptables-persistent diuninstall"
echo "✓ iptables rules direset ke default"
echo "✓ IP Forwarding dimatikan"
echo "✓ Network interfaces direset"
echo ""
echo -e "${BLUE}Sistem telah kembali ke kondisi awal sebelum setup router${NC}"
echo ""