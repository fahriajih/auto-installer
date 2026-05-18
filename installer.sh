Tentu, ini adalah *automation bash script* interaktif yang dirancang khusus untuk memenuhi kebutuhan Anda. Script ini bersifat *all-in-one*, interaktif di awal, bersih (melakukan *purge* total sebelum instalasi), dan otomatis mengonfigurasi seluruh *services* yang Anda minta.

### Cara Penggunaan Script

1. Buat file baru bernama `auto-tjkt.sh` di server Debian 12 / Ubuntu 22.04 Anda:
```bash
nano auto-tjkt.sh

```


2. Salin seluruh kode di bawah ini dan tempel (*paste*) ke dalam file tersebut.
3. Simpan dan keluar (Tekan `Ctrl + O`, `Enter`, lalu `Ctrl + X`).
4. Berikan izin eksekusi pada script:
```bash
chmod +x auto-tjkt.sh

```


5. Jalankan script dengan hak akses **root**:

```bash
   sudo ./auto-tjkt.sh

```

---

### Kode Automation Bash Script (`auto-tjkt.sh`)

```bash
#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Silakan jalankan script ini sebagai root (sudo ./auto-tjkt.sh)"
  exit 1
fi

clear
echo "========================================================================="
echo "   AUTOMATION SCRIPT DEPLOYMENT SERVICE - TJKT SMK WIKRAMA BOGOR"
echo "========================================================================="
echo ""

# ==========================================
# 1. PENGUMPULAN INFORMASI (INTERAKTIF)
# ==========================================

# A. Deteksi & Pilih Interface Jaringan
echo "[*] Mendeteksi interface jaringan yang tersedia..."
INTERFACES=($(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo'))

echo "Interface yang ditemukan:"
for i in "${!INTERFACES[@]}"; do
    echo "  [$i] ${INTERFACES[$i]}"
done

read -p "Pilih nomor interface untuk DHCP server: " INT_INDEX
IFACE=${INTERFACES[$INT_INDEX]}

if [ -z "$IFACE" ]; then
    echo "[-] Pilihan tidak valid. Eksit."
    exit 1
fi

read -p "Masukkan IP static untuk interface $IFACE (contoh: 10.1.27.1/24): " IP_WITH_MASK
IP_ADDR=$(echo $IP_WITH_MASK | cut -d'/' -f1)
NETMASK_BITS=$(echo $IP_WITH_MASK | cut -d'/' -f2)

# Hitung Network IP & Range DHCP (+100 sampai +200) Secara Sederhana
IP_BASE=$(echo $IP_ADDR | cut -d'.' -f1-3)
DHCP_START="${IP_BASE}.100"
DHCP_END="${IP_BASE}.200"

# B. Deteksi IP Sekarang & Informasi DNS / Domain
echo ""
echo "[*] IP Server saat ini yang terdeteksi:"
ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print "  - " $2}'

read -p "Masukkan domain yang diinginkan (contoh: wikrama.local): " DOMAIN
read -p "Masukkan IP untuk DNS server (rekomendasi: $IP_ADDR): " DNS_IP
if [ -z "$DNS_IP" ]; then
    DNS_IP=$IP_ADDR
fi

echo ""
echo "========================================================================="
echo " DATA BERHASIL DIKUMPULKAN. MEMULAI PROSES INSTALASI..."
echo "========================================================================="
sleep 2

# ==========================================
# 2. CLEARING / PURGE SEBELUMNYA
# ==========================================
echo "[*] Menghapus service lama beserta konfigurasinya (Purge)..."
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y apache2 mariadb-server mariadb-client php* proftpd* samba* isc-dhcp-server bind9 postfix dovecot-imapd dovecot-pop3d phpmyadmin wordpress &>/dev/null
apt-get autoremove -y &>/dev/null
apt-get clean &>/dev/null

# Hapus sisa direktori konfigurasi lama
rm -rf /etc/apache2 /etc/bind /etc/dhcp /etc/samba /etc/proftpd /etc/postfix /etc/dovecot /var/www/html/* /var/lib/mysql

# Update Repositori
echo "[*] Memperbarui repositori sistem..."
apt-get update -y &>/dev/null

# ==========================================
# 3. KONFIGURASI INTERFACE JARINGAN
# ==========================================
echo "[*] Mengonfigurasi IP Static pada interface $IFACE..."
cat <<EOF> /etc/network/interfaces
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $IP_ADDR
    netmask 255.255.255.0
EOF
systemctl restart networking &>/dev/null

# ==========================================
# 4. INSTALASI & KONFIGURASI DHCP SERVER
# ==========================================
echo "[*] Menginstall dan mengonfigurasi DHCP Server..."
apt-get install -y isc-dhcp-server &>/dev/null

sed -i "s/INTERFACESv4=\"\"/INTERFACESv4=\"$IFACE\"/" /etc/default/isc-dhcp-server

cat <<EOF> /etc/dhcp/dhcpd.conf
option domain-name "$DOMAIN";
option domain-name-servers $DNS_IP;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

subnet ${IP_BASE}.0 netmask 255.255.255.0 {
  range $DHCP_START $DHCP_END;
  option routers $IP_ADDR;
  option broadcast-address ${IP_BASE}.255;
}
EOF
systemctl restart isc-dhcp-server &>/dev/null

# ==========================================
# 5. INSTALASI & KONFIGURASI DNS (BIND9)
# ==========================================
echo "[*] Menginstall dan mengonfigurasi DNS Server (BIND9)..."
apt-get install -y bind9 bind9utils dnsutils &>/dev/null

# named.conf.local
cat <<EOF> /etc/bind/named.conf.local
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.domain";
};

zone "$(echo $IP_BASE | awk -F. '{print $3"."$2"."$1}').in-addr.arpa" {
    type master;
    file "/etc/bind/db.rev";
};
EOF

# Forward Zone (db.domain)
LAST_OCTET=$(echo $IP_ADDR | cut -d'.' -f4)
cat <<EOF> /etc/bind/db.domain
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. root.$DOMAIN. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache
;
@       IN      NS      ns1.$DOMAIN.
@       IN      NS      ns2.$DOMAIN.
@       IN      NS      ns3.$DOMAIN.
@       IN      MX  10  mail.$DOMAIN.

ns1     IN      A       $DNS_IP
ns2     IN      A       $DNS_IP
ns3     IN      A       $DNS_IP
www     IN      A       $DNS_IP
mail    IN      A       $DNS_IP
crud    IN      A       $DNS_IP
@       IN      A       $DNS_IP
EOF

# Reverse Zone (db.rev)
cat <<EOF> /etc/bind/db.rev
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. root.$DOMAIN. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache
;
@       IN      NS      ns1.$DOMAIN.
@       IN      NS      ns2.$DOMAIN.
@       IN      NS      ns3.$DOMAIN.

$LAST_OCTET   IN      PTR     ns1.$DOMAIN.
$LAST_OCTET   IN      PTR     ns2.$DOMAIN.
$LAST_OCTET   IN      PTR     ns3.$DOMAIN.
$LAST_OCTET   IN      PTR     www.$DOMAIN.
$LAST_OCTET   IN      PTR     mail.$DOMAIN.
$LAST_OCTET   IN      PTR     crud.$DOMAIN.
EOF

# Set local resolver to itself
echo "nameserver $DNS_IP" > /etc/resolv.conf

systemctl restart bind9 &>/dev/null

# ==========================================
# 6. INSTALASI MARIADB & PHP (UNTUK WEB/CRUD/WP)
# ==========================================
echo "[*] Menginstall MariaDB, PHP, dan modul pendukung..."
apt-get install -y mariadb-server php php-mysql php-gd php-mbstring php-xml php-curl &>/dev/null

# Setup Database untuk CRUD dan WordPress
mysql -e "CREATE DATABASE tjkt_crud;"
mysql -e "CREATE DATABASE wordpress;"
mysql -e "CREATE USER 'tjkt_user'@'localhost' IDENTIFIED BY 'Wikrama2026!';"
mysql -e "GRANT ALL PRIVILEGES ON tjkt_crud.* TO 'tjkt_user'@'localhost';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'tjkt_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Buat tabel siswa untuk aplikasi CRUD
mysql tjkt_crud -e "
CREATE TABLE siswa (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nis VARCHAR(20) NOT NULL,
    nama VARCHAR(100) NOT NULL,
    rombel VARCHAR(50) NOT NULL,
    rayon VARCHAR(50) NOT NULL
);
INSERT INTO siswa (nis, nama, rombel, rayon) VALUES 
('12410510', 'Muhammad Fahri Akbar', 'TJKT XII-1', 'Cicurug 1'),
('12410511', 'Siswa Contoh 1', 'TJKT XII-1', 'Ciawi 2');
"

# ==========================================
# 7. APACHE2 & 3 VIRTUAL HOSTS (WWW, MAIL, CRUD)
# ==========================================
echo "[*] Menginstall Apache2 dan mengonfigurasi Virtual Hosts..."
apt-get install -y apache2 &>/dev/null

# Buat Direktori Website
mkdir -p /var/www/$DOMAIN/www
mkdir -p /var/www/$DOMAIN/mail
mkdir -p /var/www/$DOMAIN/crud

# --- A. Halaman www.domain (Profil TJKT) ---
cat <<EOF> /var/www/$DOMAIN/www/index.php
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>TJKT - SMK Wikrama Bogor</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f0f2f5; margin: 0; padding: 0; color: #333; }
        header { background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%); color: white; padding: 40px 20px; text-align: center; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .container { max-width: 900px; margin: 30px auto; padding: 20px; background: white; border-radius: 8px; box-shadow: 0 0 15px rgba(0,0,0,0.05); }
        h1 { margin: 0; font-size: 2.5em; }
        h2 { color: #1e3c72; border-bottom: 2px solid #2a5298; padding-bottom: 5px; }
        ul { list-style-type: none; padding: 0; }
        li { background: #eef2f7; margin: 10px 0; padding: 15px; border-left: 5px solid #2a5298; font-weight: bold; border-radius: 0 4px 4px 0; }
        footer { text-align: center; margin-top: 40px; padding: 20px; color: #777; font-size: 0.9em; }
    </style>
</head>
<body>
    <header>
        <h1>Teknik Jaringan Komputer dan Telekomunikasi</h1>
        <p>SMK Wikrama Bogor - Silih Asah, Silih Asih, Silih Asuh</p>
    </header>
    <div class="container">
        <h2>Profil Kompetensi Keahlian</h2>
        <p>TJKT SMK Wikrama Bogor mencetak tenaga profesional di bidang administrator jaringan, cybersecurity, dan sistem server lokal maupun cloud dengan fondasi akhlak mulia dan kompetensi industri modern.</p>
        
        <h2>Daftar Materi Belajar Utama</h2>
        <ul>
            <li>🚀 AIJ (Administrasi Infrastruktur Jaringan)</li>
            <li>🖥️ TLJ (Teknologi Layanan Jaringan)</li>
            <li>🌐 Pemrograman Web</li>
            <li>🗄️ Basis Data</li>
            <li>💼 PKK (Produk Kreatif dan Kewirausahaan)</li>
        </ul>
    </div>
    <footer>&copy; 2026 TJKT SMK Wikrama Bogor - All Rights Reserved.</footer>
</body>
</html>
EOF

# --- B. Halaman mail.domain (Info Mail) ---
cat <<EOF> /var/www/$DOMAIN/mail/index.php
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Mail Server Info - TJKT</title>
    <style>
        body { font-family: Arial, sans-serif; background: #fafafa; padding: 40px; }
        .card { max-width: 600px; margin: auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); border-top: 5px solid #e74c3c; }
        h2 { color: #e74c3c; }
        .info-box { background: #f9f9f9; padding: 15px; border: 1px solid #ddd; border-radius: 5px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="card">
        <h2>📬 Mail Server Terkonfigurasi</h2>
        <p>Layanan Mail Server untuk internal domain <strong>$DOMAIN</strong> siap digunakan dengan protokol Postfix (SMTP) dan Dovecot (POP3/IMAP).</p>
        <div class="info-box">
            SMTP Server: mail.$DOMAIN (Port 25)<br>
            IMAP Server: mail.$DOMAIN (Port 143)<br>
            POP3 Server: mail.$DOMAIN (Port 110)
        </div>
    </div>
</body>
</html>
EOF

# --- C. Halaman crud.domain (Aplikasi CRUD Siswa Super Keren) ---
cat <<EOF> /var/www/$DOMAIN/crud/index.php
<?php
\$conn = new mysqli("localhost", "tjkt_user", "Wikrama2026!", "tjkt_crud");

if (isset(\$_POST['add'])) {
    \$nis = \$_POST['nis']; \$nama = \$_POST['nama']; \$rombel = \$_POST['rombel']; \$rayon = \$_POST['rayon'];
    \$conn->query("INSERT INTO siswa (nis, nama, rombel, rayon) VALUES ('\$nis', '\$nama', '\$rombel', '\$rayon')");
}
if (isset(\$_GET['delete'])) {
    \$id = \$_GET['delete'];
    \$conn->query("DELETE FROM siswa WHERE id=\$id");
}
\$result = \$conn->query("SELECT * FROM siswa");
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>CRUD Siswa TJKT - Super Keren</title>
    <style>
        body { font-family: 'Poppins', sans-serif; background: #0f172a; color: #e2e8f0; padding: 30px; }
        .container { max-width: 1000px; margin: auto; }
        h1 { text-align: center; color: #38bdf8; text-transform: uppercase; letter-spacing: 2px; }
        .grid { display: grid; grid-template-columns: 1fr 2fr; gap: 20px; }
        .card { background: #1e293b; padding: 25px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.3); border: 1px solid #334155; }
        input, button { width: 100%; padding: 12px; margin: 8px 0; border-radius: 6px; border: 1px solid #475569; background: #0f172a; color: white; box-sizing: border-box; }
        button { background: #0284c7; font-weight: bold; cursor: pointer; border: none; transition: 0.3s; }
        button:hover { background: #0369a1; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; background: #1e293b; border-radius: 12px; overflow: hidden; }
        th, td { padding: 14px; text-align: left; border-bottom: 1px solid #334155; }
        th { background: #38bdf8; color: #0f172a; font-weight: bold; }
        tr:hover { background: #293548; }
        .btn-del { background: #ef4444; color: white; padding: 6px 12px; border-radius: 4px; text-decoration: none; font-size: 0.85em; }
        .btn-del:hover { background: #dc2626; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ Data Management Siswa TJKT ⚡</h1>
        <div class="grid">
            <div class="card">
                <h3 style="color: #38bdf8; margin-top:0;">Tambah Siswa</h3>
                <form method="POST">
                    <input type="text" name="nis" placeholder="NIS" required>
                    <input type="text" name="nama" placeholder="Nama Lengkap" required>
                    <input type="text" name="rombel" placeholder="Rombel" required>
                    <input type="text" name="rayon" placeholder="Rayon" required>
                    <button type="submit" name="add">Simpan Data</button>
                </form>
            </div>
            <div class="card">
                <h3 style="color: #38bdf8; margin-top:0;">Daftar Siswa Aktif</h3>
                <table>
                    <tr><th>NIS</th><th>Nama</th><th>Rombel</th><th>Rayon</th><th>Aksi</th></tr>
                    <?php while(\$row = \$result->fetch_assoc()): ?>
                    <tr>
                        <td><?=\$row['nis']?></td>
                        <td><?=\$row['nama']?></td>
                        <td><?=\$row['rombel']?></td>
                        <td><?=\$row['rayon']?></td>
                        <td><a class="btn-del" href="?delete=<?=\$row['id']?>" onclick="return confirm('Hapus data ini?')">Hapus</a></td>
                    </tr>
                    <?php endwhile; ?>
                </table>
            </div>
        </div>
    </div>
</body>
</html>
EOF

# --- D. Membuat File Virtual Host Apache ---
cat <<EOF> /etc/apache2/sites-available/tjkt.conf
<VirtualHost *:80>
    ServerName www.$DOMAIN
    ServerAlias $DOMAIN
    DocumentRoot /var/www/$DOMAIN/www
</VirtualHost>

<VirtualHost *:80>
    ServerName mail.$DOMAIN
    DocumentRoot /var/www/$DOMAIN/mail
</VirtualHost>

<VirtualHost *:80>
    ServerName crud.$DOMAIN
    DocumentRoot /var/www/$DOMAIN/crud
</VirtualHost>
EOF

# Aktifkan site dan modul rewrite
a2ensite tjkt.conf &>/dev/null
a2dissite 000-default.conf &>/dev/null
a2enmod rewrite &>/dev/null
systemctl restart apache2 &>/dev/null

# ==========================================
# 8. INSTALASI & KONFIGURASI WORDPRESS
# ==========================================
echo "[*] Mengunduh dan memasang WordPress..."
cd /tmp
wget https://wordpress.org/latest.tar.gz &>/dev/null
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/$DOMAIN/www/
cp /var/www/$DOMAIN/www/wp-config-sample.php /var/www/$DOMAIN/www/wp-config.php

# Konfigurasi wp-config.php secara otomatis
sed -i "s/database_name_here/wordpress/" /var/www/$DOMAIN/www/wp-config.php
sed -i "s/username_here/tjkt_user/" /var/www/$DOMAIN/www/wp-config.php
sed -i "s/password_here/Wikrama2026!/" /var/www/$DOMAIN/www/wp-config.php

chown -R www-data:www-data /var/www/$DOMAIN/www
systemctl restart apache2 &>/dev/null

# ==========================================
# 9. INSTALASI & KONFIGURASI FTP SERVER (PROFTPD)
# ==========================================
echo "[*] Menginstall dan mengonfigurasi FTP Server (ProFTPD)..."
apt-get install -y proftpd-basic &>/dev/null

# Tambah user ftpuser jika belum ada
if ! id "ftpuser" &>/dev/null; then
    useradd -m -s /bin/sbin/nologin ftpuser
    echo "ftpuser:Wikrama2026!" | chpasswd
fi

# Konfigurasi DefaultRoot agar terkunci di home dir
sed -i 's/# DefaultRoot/DefaultRoot/' /etc/proftpd/proftpd.conf
systemctl restart proftpd &>/dev/null

# ==========================================
# 10. INSTALASI & KONFIGURASI SAMBA SHARE
# ==========================================
echo "[*] Menginstall dan mengonfigurasi Samba Share..."
apt-get install -y samba &>/dev/null

mkdir -p /home/samba/tjkt-wikrama
chmod -R 777 /home/samba/tjkt-wikrama
chown -R nobody:nogroup /home/samba/tjkt-wikrama

cat <<EOF>> /etc/samba/smb.conf

[tjkt-wikrama]
   path = /home/samba/tjkt-wikrama
   browseable = yes
   read only = no
   guest ok = yes
   public = yes
   force user = nobody
EOF
systemctl restart smbd &>/dev/null

# ==========================================
# 11. INSTALASI & KONFIGURASI MAIL SERVER (POSTFIX+DOVECOT)
# ==========================================
echo "[*] Menginstall dan mengonfigurasi Mail Server (Postfix + Dovecot)..."
debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install -y postfix dovecot-imapd dovecot-pop3d &>/dev/null

# Konfigurasi Postfix
postconf -e "myhostname = mail.$DOMAIN"
postconf -e "mydestination = \$myhostname, $DOMAIN, localhost.\$mydomain, localhost"
postconf -e "home_mailbox = Maildir/"
postconf -e "mynetworks = 127.0.0.0/8 [::1]/128 $IP_BASE.0/24"

# Konfigurasi Dovecot Maildir
sed -i 's|#mail_location = .*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
sed -i 's|#disable_plaintext_auth = .*|disable_plaintext_auth = no|' /etc/dovecot/conf.d/10-auth.conf

systemctl restart postfix &>/dev/null
systemctl restart dovecot &>/dev/null

# ==========================================
# 12. PANDUAN OPERASIONAL (FINAL OUTPUT)
# ==========================================
clear
echo "========================================================================="
echo " 🎉 PROSES INSTALASI DAN OTOMASI LAYANAN TJKT SELESAI 🎉"
echo "========================================================================="
echo ""
echo " Berikut adalah Panduan Operasional untuk mengakses layanan Anda:"
echo ""
echo " 🌐 1. DOMAIN UTAMA & WORDPRESS"
echo "    - Akses via browser  : http://www.$DOMAIN/ atau http://$IP_ADDR/"
echo "    - Konten             : Profil Informasi Keren TJKT SMK Wikrama Bogor"
echo "                           dan Halaman Setup Awal WordPress."
echo ""
echo " ⚡ 2. APLIKASI CRUD DATA SISWA"
echo "    - Akses via browser  : http://crud.$DOMAIN/"
echo "    - Konten             : Manajemen data siswa (NIS, Nama, Rombel, Rayon)"
echo "                           dengan UI Modern Dark Mode."
echo ""
echo " 📬 3. MAIL SERVER"
echo "    - Akses Info Layanan : http://mail.$DOMAIN/"
echo "    - Konfigurasi Client : SMTP/IMAP/POP3 menggunakan domain mail.$DOMAIN"
echo ""
echo " 📁 4. SAMBA SHARE (FILE SHARING)"
echo "    - Akses Windows (Run): \\\\$IP_ADDR\\tjkt-wikrama"
echo "    - Hak Akses          : Public / Anonymous (Bisa tulis & baca)"
echo ""
echo " 🔑 5. FTP SERVER"
echo "    - Akses FileZilla/Web: ftp://$IP_ADDR"
echo "    - Kredensial User     : Username: ftpuser  |  Password: Wikrama2026!"
echo ""
echo " 🔍 6. PENGUJIAN DNS"
echo "    - Perintah Uji       : Jalankan 'nslookup $DOMAIN' atau 'nslookup www.$DOMAIN'"
echo ""
echo " 📶 7. ALOKASI IP DHCP CLIENT"
echo "    - Range Distribusi   : $DHCP_START s/d $DHCP_END"
echo ""
echo "========================================================================="
echo " Server Anda telah siap digunakan untuk lingkungan lab SMK Wikrama Bogor!"
echo "========================================================================="

```

```</EOF></EOF></EOF></EOF></EOF></EOF></EOF></EOF></EOF></EOF>

```
