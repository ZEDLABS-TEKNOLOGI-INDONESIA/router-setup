<div align="center">

# 🌐 Router Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/zulfikriyahya/router-setup?style=social)](https://github.com/zulfikriyahya/router-setup)
[![GitHub Forks](https://img.shields.io/github/forks/zulfikriyahya/router-setup?style=social)](https://github.com/zulfikriyahya/router-setup)

**Ubah komputer Linux Anda menjadi router WiFi-to-LAN dengan sekali perintah! 🚀**

[Fitur](#-fitur) • [Instalasi](#-instalasi) • [Cara Kerja](#-cara-kerja) • [Troubleshooting](#-troubleshooting)

</div>

---

## 🎯 Pengenalan

**Router Setup** adalah script otomatis yang mengubah komputer Linux Anda menjadi router canggih untuk meneruskan internet dari interface WiFi ke LAN. Perfect untuk:

- 🏠 Share internet WiFi ke LAN network
- 💻 Membuat wireless access point
- 🔧 Lab testing & development
- 📡 Network experimentation

Tanpa perlu konfigurasi manual yang rumit!

---

## ✨ Fitur

| Fitur                    | Deskripsi                                    |
| ------------------------ | -------------------------------------------- |
| 🤖 **Fully Automated**   | Setup lengkap hanya dengan satu command      |
| 💬 **User-Friendly**     | Interface interaktif dengan verifikasi input |
| 📦 **Auto Dependencies** | Auto-install semua package yang dibutuhkan   |
| 🔄 **NAT & Forwarding**  | Konfigurasi NAT dan IP forwarding otomatis   |
| 📊 **DHCP Server**       | Client mendapat IP otomatis                  |
| 💾 **Persistent Config** | Setup tetap berlaku setelah reboot           |
| 🔙 **Easy Reset**        | Script reset untuk kembali ke kondisi awal   |
| ✅ **Error Handling**    | Validasi dan error handling yang robust      |

---

## 📋 Syarat & Ketentuan

Sebelum memulai, pastikan Anda memiliki:

- ✅ Linux (Ubuntu/Debian atau turunannya)
- ✅ Akses root/sudo
- ✅ Minimal 2 network interface (WiFi + LAN)
- ✅ Koneksi internet yang stabil

**Cek interface Anda:**

```bash
ip link show
```

---

## 🚀 Quick Start

### 1️⃣ Clone Repository

```bash
git clone https://github.com/zulfikriyahya/router-setup.git
cd router-setup
```

### 2️⃣ Berikan Permission

```bash
chmod +x router_setup.sh reset_router.sh
```

### 3️⃣ Jalankan Setup

```bash
sudo bash router_setup.sh
```

### 4️⃣ Ikuti Instruksi

Script akan bertanya:

- Nama interface WiFi (contoh: `wlp2s0`)
- Nama interface LAN (contoh: `enp1s0`)
- IP address LAN (contoh: `192.168.0.1`)
- DNS servers & DHCP range

Done! 🎉

---

## 💡 Contoh Penggunaan

```
$ sudo bash router_setup.sh

================================
  Internet Router Setup
================================

Interface jaringan yang tersedia:
enp1s0
enxc8a362414ac4
wlp2s0

=== KONFIGURASI INTERFACE ===
Masukkan nama interface WiFi (Internet source): wlp2s0
Masukkan nama interface LAN (untuk komputer lain): enp1s0

=== KONFIGURASI IP ADDRESS ===
Masukkan IP LAN interface (contoh: 192.168.0.1): 192.168.0.1
Masukkan subnet mask LAN (contoh: 24): 24
Masukkan DNS server 1 (default: 8.8.8.8): 8.8.8.8
Masukkan DNS server 2 (default: 8.8.4.4): 8.8.4.4
Masukkan range DHCP awal (contoh: 192.168.0.100): 192.168.0.100
Masukkan range DHCP akhir (contoh: 192.168.0.200): 192.168.0.200

Verifikasi konfigurasi:
WiFi Interface: wlp2s0
LAN Interface: enp1s0
LAN IP: 192.168.0.1/24
Gateway: 192.168.0.1
DNS: 8.8.8.8, 8.8.4.4
DHCP Range: 192.168.0.100 - 192.168.0.200

Apakah konfigurasi sudah benar? (y/n): y

=== MEMULAI INSTALASI ===
[0/7] Menginstall dependencies...
✓ Dependencies terinstall
[1/7] Mengkonfigurasi IP di interface enp1s0...
✓ IP dikonfigurasi
[2/7] Mengaktifkan IP Forwarding...
✓ IP Forwarding diaktifkan
[3/7] Mengkonfigurasi NAT...
✓ NAT dikonfigurasi
[4/7] Menyimpan konfigurasi iptables...
✓ Konfigurasi iptables disimpan
[5/7] Menginstall dan mengkonfigurasi DHCP Server...
✓ DHCP Server dikonfigurasi
[6/7] Memverifikasi konfigurasi...
✓ IP Forwarding: ON
✓ NAT Rules: Aktif
✓ DHCP Server: Berjalan
✓ LAN Interface IP: 192.168.0.1

================================
  Setup Selesai!
================================
```

---

## 🔄 Cara Kerja

```
┌─────────────────────────────────────────┐
│         Internet (Outside)              │
└────────────────┬────────────────────────┘
                 │
            ┌────▼────┐
            │  WiFi   │ (wlp2s0)
            │Interface│ Internet Source
            └────┬────┘
                 │
        ┌────────▼─────────┐
        │  Linux Router    │
        │  - IP Forward    │
        │  - NAT Rules     │
        │  - DHCP Server   │
        └────────┬─────────┘
                 │
            ┌────▼────┐
            │   LAN   │ (enp1s0)
            │Interface│ 192.168.0.1/24
            └────┬────┘
                 │
        ┌────────▼──────────┐
        │  Client Devices   │
        │ 192.168.0.100-200 │
        │  (DHCP Clients)   │
        └───────────────────┘
```

---

## 📝 Konfigurasi Manual

Untuk setup manual tanpa script, lihat [MANUAL.md](MANUAL.md)

---

## 🔄 Reset/Uninstall

### Gunakan Reset Script

```bash
sudo bash reset_router.sh
```

Script akan:

- ✓ Uninstall dnsmasq & iptables-persistent
- ✓ Hapus semua iptables rules
- ✓ Disable IP forwarding
- ✓ Restore konfigurasi default

---

## 🐛 Troubleshooting

### ❌ Client tidak bisa DHCP

**Solusi:**

```bash
# Cek status dnsmasq
sudo systemctl status dnsmasq

# Lihat log
sudo journalctl -u dnsmasq -n 50

# Restart dnsmasq
sudo systemctl restart dnsmasq
```

### ❌ Client tidak punya internet

**Cek IP Forwarding:**

```bash
cat /proc/sys/net/ipv4/ip_forward
```

Harus output `1`. Jika `0`, jalankan:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

**Cek iptables rules:**

```bash
sudo iptables -t nat -L -v
```

### ❌ Bisa ping IP tapi tidak bisa ping domain

**Masalah DNS.** Cek dari client:

```bash
nslookup google.com
```

Pastikan DNS server sudah benar di `/etc/dnsmasq.conf`.

### ❌ Interface tidak muncul

**List semua interface:**

```bash
ip link show
```

**Aktifkan interface:**

```bash
sudo ip link set <interface> up
```

**Lebih banyak solusi?** Lihat [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## 📂 Struktur File

```
router-setup/
├── 📄 README.md               # Dokumentasi utama
├── 📄 MANUAL.md               # Setup manual
├── 📄 TROUBLESHOOTING.md      # Panduan troubleshooting
├── 📄 LICENSE                 # MIT License
├── 🔧 router_setup.sh         # Script setup router
├── 🔧 reset_router.sh         # Script reset konfigurasi
└── 📋 .gitignore              # Git ignore file
```

---

## ⚡ Performance Tips

1. **Update secara berkala:**

   ```bash
   sudo apt-get update && sudo apt-get upgrade
   ```

2. **Monitor resource usage:**

   ```bash
   htop
   ```

3. **Check interface status:**

   ```bash
   ethtool -S <interface>
   ```

4. **Optimize DHCP lease time** di `/etc/dnsmasq.conf`:
   ```
   dhcp-range=192.168.0.100,192.168.0.200,24h
   ```

---

## 🤝 Kontribusi

Kami menerima kontribusi! Silakan:

1. **Fork** repository ini
2. **Buat branch** feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** changes (`git commit -m 'Add some AmazingFeature'`)
4. **Push** ke branch (`git push origin feature/AmazingFeature`)
5. **Buka Pull Request**

---

## 📋 Checklist Sebelum Production

- [ ] Backup konfigurasi penting
- [ ] Test setup di environment test terlebih dahulu
- [ ] Cek semua client bisa terhubung
- [ ] Verify internet connection stabil
- [ ] Monitor resource usage
- [ ] Setup backup/restore procedure

---

## 🎯 Roadmap

- [ ] Support IPv6
- [ ] Web UI dashboard
- [ ] Real-time traffic monitoring
- [ ] Auto-backup configuration
- [ ] Support multiple Linux distro (CentOS, Fedora, Arch)
- [ ] QoS configuration
- [ ] Firewall rules templates
- [ ] Automated testing

---

## ⚠️ Disclaimer

**Script ini disediakan "AS IS".** Pengguna sepenuhnya bertanggung jawab atas penggunaan script ini. Kami tidak bertanggung jawab atas:

- Data loss
- System damage
- Network issues
- Security vulnerabilities

**Selalu backup konfigurasi penting sebelum menjalankan script!**

---

## 📜 Lisensi

Project ini dilisensikan di bawah **MIT License**.

Lihat file [LICENSE](LICENSE) untuk detail lengkap.

---

## 📧 Support & Kontak

Punya pertanyaan atau menemukan bug? Silakan:

- 🐛 [Buka Issue](https://github.com/zulfikriyahya/router-setup/issues)
- 💬 [Diskusi](https://github.com/zulfikriyahya/router-setup/discussions)
- 📧 Hubungi maintainer

---

## 🌟 Jika Membantu, Berikan Star! ⭐

Jika project ini membantu Anda, jangan lupa kasih **star** di GitHub!

```bash
# Lihat di:
# https://github.com/zulfikriyahya/router-setup
```

---

<div align="center">

### Made with ❤️ by [zulfikriyahya](https://github.com/zulfikriyahya)

**Happy Routing! 🚀**

</div>
