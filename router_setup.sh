#!/bin/bash

# Internet Router Setup Installer
# Script untuk meneruskan internet dari satu interface ke interface lain

set -e

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Header
clear
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Internet Router Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: Script harus dijalankan sebagai root${NC}"
   echo "Gunakan: sudo bash script.sh"
   exit 1
fi

# Tampilkan interface yang tersedia
echo -e "${YELLOW}Interface jaringan yang tersedia:${NC}"
ip link show | grep -E "^\d+:" | awk '{print $2}' | sed 's/:$//'
echo ""

# Input dari user
echo -e "${BLUE}=== KONFIGURASI INTERFACE ===${NC}"
read -p "Masukkan nama interface WiFi (Internet source): " WIFI_INTERFACE
read -p "Masukkan nama interface LAN (untuk komputer lain): " LAN_INTERFACE

echo ""
echo -e "${BLUE}=== KONFIGURASI IP ADDRESS ===${NC}"
read -p "Masukkan IP LAN interface (contoh: 192.168.0.1): " LAN_IP
read -p "Masukkan subnet mask LAN (contoh: 24): " LAN_SUBNET
read -p "Masukkan DNS server 1 (default: 8.8.8.8): " DNS1
read -p "Masukkan DNS server 2 (default: 8.8.4.4): " DNS2
read -p "Masukkan range DHCP awal (contoh: 192.168.0.100): " DHCP_START
read -p "Masukkan range DHCP akhir (contoh: 192.168.0.200): " DHCP_END

# Set default DNS jika kosong
DNS1=${DNS1:-8.8.8.8}
DNS2=${DNS2:-8.8.4.4}

# Ekstrak network dan broadcast dari IP
IFS='.' read -r a b c d <<< "$LAN_IP"
NETWORK="$a.$b.$c.0"
BROADCAST="$a.$b.$c.255"
GATEWAY="$LAN_IP"

echo ""
echo -e "${YELLOW}Verifikasi konfigurasi:${NC}"
echo "WiFi Interface: $WIFI_INTERFACE"
echo "LAN Interface: $LAN_INTERFACE"
echo "LAN IP: $LAN_IP/$LAN_SUBNET"
echo "Network: $NETWORK/$LAN_SUBNET"
echo "Gateway: $GATEWAY"
echo "DNS: $DNS1, $DNS2"
echo "DHCP Range: $DHCP_START - $DHCP_END"
echo ""

read -p "Apakah konfigurasi sudah benar? (y/n): " CONFIRM
if [[ $CONFIRM != [yY] ]]; then
    echo -e "${RED}Setup dibatalkan${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=== MEMULAI INSTALASI ===${NC}"
echo ""

# Step 0: Install dependencies
echo -e "${YELLOW}[0/7] Menginstall dependencies...${NC}"
apt-get update -qq
apt-get install -y -qq iptables iptables-persistent dnsmasq > /dev/null 2>&1
echo -e "${GREEN}✓ Dependencies terinstall${NC}"

# Step 1: Konfigurasi IP di Interface LAN
echo -e "${YELLOW}[1/7] Mengkonfigurasi IP di interface $LAN_INTERFACE...${NC}"
ip addr flush dev $LAN_INTERFACE 2>/dev/null || true
ip addr add $LAN_IP/$LAN_SUBNET brd $BROADCAST dev $LAN_INTERFACE
ip link set $LAN_INTERFACE up
echo -e "${GREEN}✓ IP dikonfigurasi${NC}"

# Step 2: Aktifkan IP Forwarding
echo -e "${YELLOW}[2/7] Mengaktifkan IP Forwarding...${NC}"
sysctl -w net.ipv4.ip_forward=1 > /dev/null

# Buat permanen di /etc/sysctl.conf
if grep -q "net.ipv4.ip_forward" /etc/sysctl.conf; then
    sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sed -i 's/^net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/' /etc/sysctl.conf
else
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi
sysctl -p > /dev/null
echo -e "${GREEN}✓ IP Forwarding diaktifkan${NC}"

# Step 3: Konfigurasi NAT dengan iptables
echo -e "${YELLOW}[3/7] Mengkonfigurasi NAT...${NC}"
iptables -t nat -D POSTROUTING -o $WIFI_INTERFACE -j MASQUERADE 2>/dev/null || true
iptables -D FORWARD -i $LAN_INTERFACE -o $WIFI_INTERFACE -j ACCEPT 2>/dev/null || true
iptables -D FORWARD -i $WIFI_INTERFACE -o $LAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true

iptables -t nat -A POSTROUTING -o $WIFI_INTERFACE -j MASQUERADE
iptables -A FORWARD -i $LAN_INTERFACE -o $WIFI_INTERFACE -j ACCEPT
iptables -A FORWARD -i $WIFI_INTERFACE -o $LAN_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
echo -e "${GREEN}✓ NAT dikonfigurasi${NC}"

# Step 4: Simpan iptables
echo -e "${YELLOW}[4/7] Menyimpan konfigurasi iptables...${NC}"
if ! command -v iptables-save &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq iptables-persistent > /dev/null 2>&1
fi
netfilter-persistent save > /dev/null 2>&1 || iptables-save > /etc/iptables/rules.v4
echo -e "${GREEN}✓ Konfigurasi iptables disimpan${NC}"

# Step 5: Install dan konfigurasi DHCP Server
echo -e "${YELLOW}[5/7] Menginstall dan mengkonfigurasi DHCP Server...${NC}"
if ! command -v dnsmasq &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq dnsmasq > /dev/null 2>&1
fi

# Backup konfigurasi lama
cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true

# Buat konfigurasi dnsmasq
cat > /etc/dnsmasq.conf << EOF
interface=$LAN_INTERFACE
dhcp-range=$DHCP_START,$DHCP_END,12h
dhcp-option=option:router,$GATEWAY
dhcp-option=option:dns-server,$DNS1,$DNS2
no-resolv
server=$DNS1
server=$DNS2
EOF

systemctl restart dnsmasq
systemctl enable dnsmasq > /dev/null 2>&1
echo -e "${GREEN}✓ DHCP Server dikonfigurasi${NC}"

# Step 6: Verifikasi
echo -e "${YELLOW}[6/7] Memverifikasi konfigurasi...${NC}"
sleep 1

# Check IP Forwarding
if sysctl -n net.ipv4.ip_forward | grep -q "1"; then
    echo -e "${GREEN}✓ IP Forwarding: ON${NC}"
else
    echo -e "${RED}✗ IP Forwarding: OFF${NC}"
fi

# Check iptables
if iptables -t nat -L | grep -q "MASQUERADE"; then
    echo -e "${GREEN}✓ NAT Rules: Aktif${NC}"
else
    echo -e "${RED}✗ NAT Rules: Tidak aktif${NC}"
fi

# Check dnsmasq
if systemctl is-active --quiet dnsmasq; then
    echo -e "${GREEN}✓ DHCP Server: Berjalan${NC}"
else
    echo -e "${RED}✗ DHCP Server: Tidak berjalan${NC}"
fi

# Check LAN interface IP
if ip addr show $LAN_INTERFACE | grep -q $LAN_IP; then
    echo -e "${GREEN}✓ LAN Interface IP: $LAN_IP${NC}"
else
    echo -e "${RED}✗ LAN Interface IP: Error${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Setup Selesai!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Informasi Router:${NC}"
echo "WiFi Interface: $WIFI_INTERFACE (Internet Source)"
echo "LAN Interface: $LAN_INTERFACE (Gateway: $GATEWAY)"
echo "DHCP Range: $DHCP_START - $DHCP_END"
echo "DNS: $DNS1, $DNS2"
echo ""
echo -e "${YELLOW}Langkah selanjutnya:${NC}"
echo "1. Hubungkan komputer lain ke interface $LAN_INTERFACE"
echo "2. Set IP ke DHCP atau manual dengan gateway: $GATEWAY"
echo "3. Test: ping 8.8.8.8"
echo ""
echo -e "${YELLOW}Untuk membatalkan setup, jalankan:${NC}"
echo "  sudo bash reset_router.sh"
echo ""