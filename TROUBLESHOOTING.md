# 🔧 Troubleshooting Guide

Panduan lengkap untuk mengatasi berbagai masalah yang mungkin terjadi saat setup router.

---

## 📋 Daftar Isi

- [General Issues](#general-issues)
- [DHCP Issues](#dhcp-issues)
- [Network Connectivity](#network-connectivity)
- [DNS Issues](#dns-issues)
- [Performance Issues](#performance-issues)
- [Advanced Debugging](#advanced-debugging)
- [FAQ](#faq)

---

## 🚨 General Issues

### ❌ Script tidak berjalan / Permission Denied

**Problem:**

```
bash: ./router_setup.sh: Permission denied
```

**Solution:**

```bash
# Berikan execute permission
chmod +x router_setup.sh reset_router.sh

# Atau jalankan dengan bash langsung
sudo bash router_setup.sh
```

---

### ❌ Script harus dijalankan sebagai root

**Problem:**

```
Error: Script harus dijalankan sebagai root
```

**Solution:**

```bash
# Jalankan dengan sudo
sudo bash router_setup.sh

# ATAU dengan sudo -i (login root)
sudo -i
bash router_setup.sh
exit
```

---

### ❌ apt-get: command not found

**Problem:**

```
apt-get: command not found
```

**Solution:**

Anda sedang menggunakan distro non-Debian (CentOS, Fedora, Arch). Gunakan package manager yang sesuai:

```bash
# CentOS/RHEL/Fedora
sudo yum install iptables-persistent dnsmasq

# Arch Linux
sudo pacman -S iptables dnsmasq
```

---

## 🌐 DHCP Issues

### ❌ Client tidak dapat DHCP IP

**Problem:**
Client device tidak mendapatkan IP address dari DHCP server.

**Diagnosis:**

```bash
# 1. Cek status dnsmasq
sudo systemctl status dnsmasq

# 2. Lihat dnsmasq log
sudo journalctl -u dnsmasq -n 50

# 3. Lihat active leases
cat /var/lib/dnsmasq/dnsmasq.leases
```

**Solutions:**

**Step 1: Verifikasi interface LAN aktif**

```bash
ip link show enp1s0
```

Harus menunjukkan: `<BROADCAST,MULTICAST,UP,LOWER_UP>`

Jika tidak:

```bash
sudo ip link set enp1s0 up
```

**Step 2: Verifikasi IP LAN sudah ter-set**

```bash
ip addr show enp1s0
```

Harus ada: `inet 192.168.0.1/24`

Jika tidak:

```bash
sudo ip addr add 192.168.0.1/24 dev enp1s0
```

**Step 3: Verifikasi dnsmasq config**

```bash
# Check config
cat /etc/dnsmasq.conf | grep -v "^#" | grep -v "^$"
```

Harus ada:

```
interface=enp1s0
dhcp-range=192.168.0.100,192.168.0.200,12h
```

**Step 4: Restart dnsmasq**

```bash
sudo systemctl restart dnsmasq
```

**Step 5: Monitor DHCP requests**

```bash
# Terminal 1: Monitor dnsmasq
sudo tail -f /var/log/syslog | grep dnsmasq

# Terminal 2: Trigger DHCP request dari client
# (dari client device)
sudo dhclient -v
```

---

### ❌ DHCP IP range tidak sesuai

**Problem:**
Client mendapat IP dari range yang berbeda.

**Solution:**

```bash
# Cek current range
cat /etc/dnsmasq.conf | grep dhcp-range

# Edit jika perlu
sudo nano /etc/dnsmasq.conf

# Restart dnsmasq
sudo systemctl restart dnsmasq
```

---

## 🔌 Network Connectivity

### ❌ Client bisa connect tapi tidak ada internet

**Problem:**
Client device terhubung ke LAN, dapat IP, tapi tidak bisa browsing.

**Diagnosis:**

```bash
# Test ping router
ping 192.168.0.1

# Test ping internet
ping 8.8.8.8

# Test DNS
nslookup google.com
```

**Solutions:**

**Step 1: Cek IP Forwarding aktif**

```bash
cat /proc/sys/net/ipv4/ip_forward
```

Harus output `1`.

Jika `0`:

```bash
# Temporary
sudo sysctl -w net.ipv4.ip_forward=1

# Permanent (edit /etc/sysctl.conf)
sudo nano /etc/sysctl.conf
# Uncomment: net.ipv4.ip_forward=1
sudo sysctl -p
```

**Step 2: Cek NAT rules ada**

```bash
sudo iptables -t nat -L -v
```

Harus ada:

```
MASQUERADE  all  --  anywhere  anywhere
```

Jika tidak:

```bash
sudo iptables -t nat -A POSTROUTING -o wlp2s0 -j MASQUERADE
sudo iptables -A FORWARD -i enp1s0 -o wlp2s0 -j ACCEPT
sudo iptables -A FORWARD -i wlp2s0 -o enp1s0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo netfilter-persistent save
```

**Step 3: Cek WiFi interface terhubung**

```bash
ip addr show wlp2s0
```

Harus ada IP address.

**Step 4: Test routing**

```bash
# Dari client
traceroute 8.8.8.8

# Dari router
sudo iptables -L -v
```

---

### ❌ WiFi interface DOWN atau tidak terhubung

**Problem:**
WiFi interface tidak aktif atau tidak terhubung ke internet.

**Solution:**

```bash
# 1. Cek status interface
ip link show wlp2s0

# 2. Aktifkan interface
sudo ip link set wlp2s0 up

# 3. Cek connection
iw dev wlp2s0 link

# 4. Scan available networks
sudo iw dev wlp2s0 scan

# 5. Connect ke WiFi
sudo nmcli device wifi connect "SSID" password "PASSWORD"

# 6. Verify connection
ip addr show wlp2s0
```

---

### ❌ Client tidak bisa reach router

**Problem:**
Client di LAN tidak bisa ping 192.168.0.1 (router).

**Solution:**

```bash
# Dari router - verify LAN interface IP
ip addr show enp1s0

# Dari router - check if ICMP replies enabled
sudo iptables -L -v

# Dari client - check gateway
ip route show

# Dari router - ping client (untuk verify koneksi fisik)
ping 192.168.0.100
```

---

## 📡 DNS Issues

### ❌ Client bisa ping IP tapi tidak bisa ping domain

**Problem:**

```bash
ping 8.8.8.8        # ✓ Works
ping google.com     # ✗ Failed
```

**Diagnosis:**

```bash
# Dari client
cat /etc/resolv.conf
nslookup google.com
dig google.com

# Dari router
cat /etc/dnsmasq.conf | grep server=
sudo systemctl status dnsmasq
```

**Solutions:**

**Step 1: Verify DNS config di router**

```bash
cat /etc/dnsmasq.conf | grep -E "^server=|^interface="
```

Harus ada:

```
interface=enp1s0
server=8.8.8.8
server=8.8.4.4
```

**Step 2: Restart dnsmasq**

```bash
sudo systemctl restart dnsmasq
sudo systemctl status dnsmasq
```

**Step 3: Test DNS dari router**

```bash
nslookup google.com 8.8.8.8
dig @8.8.8.8 google.com
```

**Step 4: Test DNS dari client**

```bash
# Specify DNS server explicitly
nslookup google.com 192.168.0.1
dig @192.168.0.1 google.com
```

**Step 5: Check /etc/resolv.conf pada client**

```bash
cat /etc/resolv.conf
```

Harus ada:

```
nameserver 192.168.0.1
```

Jika tidak, set manually:

```bash
echo "nameserver 192.168.0.1" | sudo tee /etc/resolv.conf
```

---

### ❌ DNS resolution lambat

**Problem:**
DNS resolution response time lama (>1 second).

**Solution:**

```bash
# 1. Test DNS speed
time nslookup google.com

# 2. Check dnsmasq config
cat /etc/dnsmasq.conf | grep -E "^cache-size|^dns"

# 3. Optimize cache size
sudo nano /etc/dnsmasq.conf

# Add/modify:
cache-size=1000
```

---

## ⚡ Performance Issues

### ❌ Internet lambat / Bandwidth rendah

**Problem:**
Internet connection dari router lebih lambat dari langsung WiFi.

**Diagnosis:**

```bash
# Cek router CPU/Memory
top
htop

# Cek interface stats
ethtool -S enp1s0
ethtool -S wlp2s0

# Monitor traffic real-time
iftop
nethogs
```

**Solutions:**

**Step 1: Check CPU usage**

```bash
top -b -n 1 | head -20
```

Jika CPU tinggi, hentikan service yang tidak perlu:

```bash
sudo systemctl stop cups
sudo systemctl stop bluetooth
```

**Step 2: Monitor real-time traffic**

```bash
# Install tools
sudo apt-get install iftop nethogs

# Monitor
sudo iftop -i enp1s0
sudo nethogs
```

**Step 3: Optimize dnsmasq**

```bash
sudo nano /etc/dnsmasq.conf

# Add:
cache-size=1000
log-queries
```

**Step 4: Optimize iptables**

```bash
# Reduce logging
sudo iptables -L -v --line-numbers
sudo iptables -D INPUT <line_number>  # Delete unnecessary rules
```

---

### ❌ Packet loss / Connection drops

**Problem:**
Connection sering putus atau packet loss tinggi.

**Solution:**

```bash
# 1. Test packet loss
ping -c 100 8.8.8.8 | tail -1

# 2. Check for errors
ethtool -S enp1s0 | grep -E "rx_errors|tx_errors"

# 3. Update network drivers
sudo apt-get update
sudo apt-get upgrade

# 4. Monitor logs
sudo journalctl -f | grep -i "error\|dropped"
```

---

## 🔍 Advanced Debugging

### Capture network traffic

```bash
# Install tcpdump
sudo apt-get install tcpdump

# Capture traffic di LAN interface
sudo tcpdump -i enp1s0 -n

# Capture DNS traffic
sudo tcpdump -i enp1s0 -n udp port 53

# Capture DHCP traffic
sudo tcpdump -i enp1s0 -n udp port 67 or port 68

# Save to file
sudo tcpdump -i enp1s0 -w capture.pcap

# Analyze saved file
tcpdump -r capture.pcap | head -50
```

---

### Monitor packet flow

```bash
# Install nftables
sudo apt-get install nftables

# Show connections
sudo nft list ruleset

# Monitor connection tracking
cat /proc/net/nf_conntrack | head -20
```

---

### Debug iptables rules

```bash
# List all rules dengan nomor
sudo iptables -L -v --line-numbers

# List NAT rules
sudo iptables -t nat -L -v --line-numbers

# Debug specific rule
sudo iptables -L INPUT -v --line-numbers

# Add logging untuk debug
sudo iptables -I FORWARD -j LOG --log-prefix "IPTABLES_DEBUG: "

# View logs
sudo tail -f /var/log/syslog | grep IPTABLES_DEBUG
```

---

## ❓ FAQ

### Q: Bagaimana cara check konfigurasi sudah benar?

**A:**

```bash
# Checklist lengkap
echo "=== IP Forwarding ==="
cat /proc/sys/net/ipv4/ip_forward

echo "=== LAN Interface ==="
ip addr show enp1s0

echo "=== WiFi Interface ==="
ip addr show wlp2s0

echo "=== iptables NAT Rules ==="
sudo iptables -t nat -L -v

echo "=== iptables FORWARD Rules ==="
sudo iptables -L FORWARD -v

echo "=== dnsmasq Status ==="
sudo systemctl status dnsmasq

echo "=== DHCP Leases ==="
cat /var/lib/dnsmasq/dnsmasq.leases
```

---

### Q: Bagaimana cara permanent set static IP untuk interface?

**A:**

**Netplan (Ubuntu 18.04+):**

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Tambahkan:

```yaml
network:
  version: 2
  ethernets:
    enp1s0:
      dhcp4: no
      addresses:
        - 192.168.0.1/24
```

Apply:

```bash
sudo netplan apply
```

---

### Q: Bagaimana cara uninstall semuanya?

**A:**

```bash
# Jalankan reset script
sudo bash reset_router.sh

# Atau manual:
sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq
sudo apt-get remove dnsmasq iptables-persistent
sudo iptables -F
sudo iptables -t nat -F
sudo sysctl -w net.ipv4.ip_forward=0
```

---

### Q: Bisakah saya gunakan interface wireless sebagai LAN?

**A:**

Technically yes, tapi **tidak direkomendasikan** karena:

- Performance akan menurun
- Interference antar WiFi
- Potential security issues

Better use wired connection (Ethernet) untuk LAN interface.

---

### Q: Berapa client yang bisa connect?

**A:**

Theoretically bisa unlimited, praktis tergantung:

- Hardware (CPU, RAM)
- Network interface (100Mbps vs Gigabit)
- DHCP range yang dikonfigurasi

Rekomendasi: maksimal 50-100 client untuk setup standard.

---

### Q: Gimana caranya limit bandwidth per client?

**A:**

Gunakan `tc` (traffic control):

```bash
# Install tools
sudo apt-get install iproute2

# Limit 1Mbps per interface
sudo tc qdisc add dev enp1s0 root tbf rate 1mbit burst 32kbit latency 400ms

# Check
sudo tc qdisc ls

# Remove
sudo tc qdisc del dev enp1s0 root
```

---

## 📞 Masih butuh bantuan?

Jika masalah tidak teratasi:

1. **Cek logs:**

   ```bash
   sudo journalctl -f
   sudo tail -f /var/log/syslog
   ```

2. **Buka GitHub Issue:**
   https://github.com/zulfikriyahya/router-setup/issues

3. **Kumpulkan informasi debugging:**

   ```bash
   # System info
   uname -a

   # Distro info
   lsb_release -a

   # Network interfaces
   ip link show
   ip addr show

   # Routes
   ip route show

   # iptables
   sudo iptables -L -v
   sudo iptables -t nat -L -v

   # Services status
   sudo systemctl status dnsmasq
   sudo systemctl status networking
   ```

4. **Share output & description di issue**

---
