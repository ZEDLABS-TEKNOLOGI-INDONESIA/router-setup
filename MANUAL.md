# 📖 Setup Manual Router

Panduan lengkap untuk mengkonfigurasi router secara manual tanpa menggunakan script otomatis.

---

## 📋 Daftar Isi

- [Prasyarat](#prasyarat)
- [Identifikasi Interface](#identifikasi-interface)
- [Step-by-Step Setup](#step-by-step-setup)
- [Verifikasi](#verifikasi)
- [Network Diagram](#network-diagram)

---

## ✅ Prasyarat

Sebelum memulai, pastikan:

```bash
# 1. Update system
sudo apt-get update && sudo apt-get upgrade -y

# 2. Install dependencies
sudo apt-get install -y iptables iptables-persistent dnsmasq net-tools

# 3. Cek interface
ip link show
```

---

## 🔍 Identifikasi Interface

### Lihat semua interface

```bash
ip link show
```

Output contoh:

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
3: wlp2s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500
```

### Lihat detail interface

```bash
ip addr show
```

Output contoh:

```
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    link/ether fc:34:97:72:aa:c2 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.253/24 brd 192.168.0.255 scope global enp1s0

4: wlp2s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    link/ether 14:18:c3:93:54:72 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.10/24 brd 192.168.1.255 scope global wlp2s0
```

**Identifikasi:**

- **wlp2s0** = WiFi interface (terhubung internet)
- **enp1s0** = LAN interface (untuk client)

---

## 🔧 Step-by-Step Setup

### Variabel Setup

Replace dengan nilai Anda:

```bash
# Interface
WIFI_IF="wlp2s0"          # Interface WiFi (internet source)
LAN_IF="enp1s0"           # Interface LAN (untuk client)

# IP Configuration
LAN_IP="192.168.0.1"      # IP Gateway LAN
LAN_SUBNET="24"           # Subnet mask (CIDR)
NETWORK="192.168.0.0"     # Network address
BROADCAST="192.168.0.255" # Broadcast address

# DHCP Configuration
DHCP_START="192.168.0.100"     # DHCP range awal
DHCP_END="192.168.0.200"       # DHCP range akhir
DNS1="8.8.8.8"                 # Primary DNS
DNS2="8.8.4.4"                 # Secondary DNS
```

### Step 1: Konfigurasi IP di LAN Interface

**Flush IP lama (jika ada):**

```bash
sudo ip addr flush dev $LAN_IF
```

**Assign IP baru:**

```bash
sudo ip addr add $LAN_IP/$LAN_SUBNET brd $BROADCAST dev $LAN_IF
sudo ip link set $LAN_IF up
```

**Verifikasi:**

```bash
ip addr show $LAN_IF
```

Output:

```
2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    link/ether fc:34:97:72:aa:c2 brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.1/24 brd 192.168.0.255 scope global enp1s0
```

---

### Step 2: Enable IP Forwarding

**Temporary (sampai reboot):**

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

**Permanent (survive reboot):**

```bash
# Edit sysctl.conf
sudo nano /etc/sysctl.conf
```

Cari baris:

```
#net.ipv4.ip_forward=1
```

Uncomment menjadi:

```
net.ipv4.ip_forward=1
```

Simpan (Ctrl+X, Y, Enter), kemudian jalankan:

```bash
sudo sysctl -p
```

**Verifikasi:**

```bash
sysctl net.ipv4.ip_forward
```

Output harus:

```
net.ipv4.ip_forward = 1
```

---

### Step 3: Setup NAT dengan iptables

**Flush rules lama:**

```bash
sudo iptables -t nat -F
sudo iptables -F
```

**Buat NAT rules:**

```bash
# MASQUERADE untuk WiFi interface
sudo iptables -t nat -A POSTROUTING -o $WIFI_IF -j MASQUERADE

# Forward packets dari LAN ke WiFi
sudo iptables -A FORWARD -i $LAN_IF -o $WIFI_IF -j ACCEPT

# Forward established connections dari WiFi ke LAN
sudo iptables -A FORWARD -i $WIFI_IF -o $LAN_IF -m state --state RELATED,ESTABLISHED -j ACCEPT
```

**Contoh dengan nilai actual:**

```bash
sudo iptables -t nat -A POSTROUTING -o wlp2s0 -j MASQUERADE
sudo iptables -A FORWARD -i enp1s0 -o wlp2s0 -j ACCEPT
sudo iptables -A FORWARD -i wlp2s0 -o enp1s0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

**Verifikasi:**

```bash
sudo iptables -t nat -L -v
sudo iptables -L -v
```

---

### Step 4: Simpan iptables Rules (Persistent)

**Install iptables-persistent (jika belum):**

```bash
sudo apt-get install -y iptables-persistent
```

**Saat install, pilih YES untuk IPv4 & IPv6**

**Save current rules:**

```bash
sudo netfilter-persistent save
```

atau

```bash
sudo iptables-save > /etc/iptables/rules.v4
```

**Verifikasi tersimpan:**

```bash
cat /etc/iptables/rules.v4 | grep -i masquerade
```

Harus ada output `MASQUERADE`.

---

### Step 5: Setup DHCP Server (dnsmasq)

**Install dnsmasq (jika belum):**

```bash
sudo apt-get install -y dnsmasq
```

**Backup konfigurasi original:**

```bash
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
```

**Edit konfigurasi:**

```bash
sudo nano /etc/dnsmasq.conf
```

Cari dan comment baris-baris ini (jika ada):

```
#interface=
#dhcp-range=
#server=
```

Scroll ke bawah, tambahkan di akhir file:

```
# Router Configuration
interface=enp1s0
dhcp-range=192.168.0.100,192.168.0.200,12h
dhcp-option=option:router,192.168.0.1
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4
no-resolv
server=8.8.8.8
server=8.8.4.4
```

**Contoh lengkap:**

```bash
# Interface DHCP
interface=enp1s0

# DHCP address range dan lease time
dhcp-range=192.168.0.100,192.168.0.200,12h

# Gateway
dhcp-option=option:router,192.168.0.1

# DNS servers
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4

# Use specified DNS servers
no-resolv
server=8.8.8.8
server=8.8.4.4
```

**Simpan file (Ctrl+X, Y, Enter)**

**Restart dnsmasq:**

```bash
sudo systemctl restart dnsmasq
```

**Enable saat boot:**

```bash
sudo systemctl enable dnsmasq
```

**Verifikasi:**

```bash
sudo systemctl status dnsmasq
```

Harus output `active (running)`.

---

## ✅ Verifikasi Konfigurasi

### Check semua komponen

**1. IP Forwarding aktif:**

```bash
cat /proc/sys/net/ipv4/ip_forward
```

Harus output: `1`

**2. LAN Interface UP dan punya IP:**

```bash
ip addr show enp1s0
```

Harus terlihat:

```
inet 192.168.0.1/24 brd 192.168.0.255 scope global enp1s0
```

**3. WiFi Interface terhubung:**

```bash
ip addr show wlp2s0
```

Harus punya `inet` address.

**4. NAT Rules aktif:**

```bash
sudo iptables -t nat -L -v
sudo iptables -L -v
```

Harus ada:

```
MASQUERADE  all  --  anywhere  anywhere
```

**5. DHCP Server running:**

```bash
sudo systemctl status dnsmasq
```

Harus `active (running)`.

**6. Test DNS:**

```bash
nslookup google.com 192.168.0.1
```

Harus resolve domain.

---

## 🧪 Test dari Client Device

### Setup Client

1. **Connect ke LAN interface** (kabel/bridge ke enp1s0)
2. **Set IP ke DHCP** atau manual IP `192.168.0.100-200`

### Test Connectivity

**From client device:**

```bash
# Lihat IP yang dapat (harus dalam range DHCP)
ip addr show

# Ping gateway
ping 192.168.0.1

# Ping internet
ping 8.8.8.8

# Test DNS
nslookup google.com
ping google.com
```

Semua harus berhasil!

---

## 🌐 Network Diagram

```
┌─────────────────────────────────┐
│    Internet (192.168.1.x/24)    │
└──────────────┬──────────────────┘
               │
        ┌──────▼─────┐
        │  WiFi Card │ wlp2s0
        │192.168.1.10│ (DHCP client dari router WiFi)
        └──────┬─────┘
               │
        ┌──────▼──────────────────────┐
        │   Linux Router Server       │
        │  (Kernel IP Forwarding ON)  │
        │  (iptables NAT rules)       │
        │  (dnsmasq DHCP server)      │
        └──────┬──────────────────────┘
               │
        ┌──────▼─────────┐
        │  Ethernet Card │ enp1s0
        │ 192.168.0.1/24 │ (Gateway)
        └──────┬─────────┘
               │
        ┌──────▼──────────────────────┐
        │   Local Network             │
        │ 192.168.0.0/24              │
        │                             │
        │ Client 1: 192.168.0.100     │
        │ Client 2: 192.168.0.101     │
        │ Client 3: 192.168.0.102     │
        │ ...                         │
        │ Client N: 192.168.0.200     │
        └─────────────────────────────┘
```

---

## 🔄 Persistent Setup (Survive Reboot)

Agar setup tetap berlaku setelah reboot, pastikan:

### 1. IP Forwarding Permanent

Edit `/etc/sysctl.conf`:

```bash
sudo nano /etc/sysctl.conf
```

Pastikan ada:

```
net.ipv4.ip_forward=1
```

### 2. iptables Rules Saved

```bash
sudo netfilter-persistent save
```

### 3. Enable Services Saat Boot

```bash
sudo systemctl enable dnsmasq
sudo systemctl enable systemd-resolved
```

### 4. Static IP untuk LAN Interface (Optional)

Edit `/etc/netplan/` atau `/etc/network/interfaces`:

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
      routes:
        - to: 0.0.0.0/0
          via: 192.168.1.1 # Gateway WiFi router
```

Apply:

```bash
sudo netplan apply
```

---

## ⚠️ Troubleshooting Manual Setup

### Issue: Client tidak dapat DHCP

**Check dnsmasq:**

```bash
sudo systemctl status dnsmasq
sudo journalctl -u dnsmasq -n 20
```

**Restart dnsmasq:**

```bash
sudo systemctl restart dnsmasq
```

### Issue: Tidak ada internet di client

**Check IP Forwarding:**

```bash
cat /proc/sys/net/ipv4/ip_forward
```

Jika `0`, enable:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

**Check iptables:**

```bash
sudo iptables -L -v
sudo iptables -t nat -L -v
```

### Issue: DNS tidak bekerja

**Check DNS config:**

```bash
cat /etc/dnsmasq.conf | grep server=
```

**Test DNS:**

```bash
dig @8.8.8.8 google.com
nslookup google.com
```

### Issue: Packet loss/Slow

**Check interface status:**

```bash
ethtool enp1s0
ethtool wlp2s0
```

**Monitor traffic:**

```bash
iftop
nethogs
```

---

## 📚 Referensi Lengkap

- **iptables:** `man iptables`
- **sysctl:** `man sysctl`
- **dnsmasq:** `man dnsmasq`
- **ip command:** `man ip`

---
