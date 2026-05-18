#!/bin/bash
# =============================================================================
# Script: setup_server.sh
# Fungsi: Instalasi otomatis server (DHCP, DNS, Web, Mail, FTP, Samba, Wordpress)
# Target : Debian 12 / Ubuntu 22.04
# =============================================================================

set -e  # Hentikan jika ada error

# Warna biar keren
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===================== DETEKSI INTERFACE JARINGAN =====================
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     SCRIPT INSTALASI SERVER TJKT SMK WIKRAMA BOGOR    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"

# Mendeteksi semua interface kecuali lo
interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v lo))
echo -e "\n${YELLOW}[DETEKSI] Interface jaringan yang tersedia:${NC}"
for i in "${!interfaces[@]}"; do
    echo "  $((i+1))) ${interfaces[$i]}"
done

# Pilih interface untuk DHCP server
echo -e "\n${GREEN}Pilih interface untuk DHCP server (nomor 1-${#interfaces[@]}):${NC}"
read -p ">> " iface_choice
if [[ ! "$iface_choice" =~ ^[0-9]+$ ]] || [ "$iface_choice" -lt 1 ] || [ "$iface_choice" -gt ${#interfaces[@]} ]; then
    echo -e "${RED}ERROR: Pilihan tidak valid!${NC}"
    exit 1
fi
DHCP_IFACE="${interfaces[$((iface_choice-1))]}"

# Masukkan IP static untuk interface tersebut
echo -e "\n${GREEN}Masukkan IP static untuk interface $DHCP_IFACE (contoh: 10.1.27.1/24):${NC}"
read -p ">> " STATIC_CIDR

# Validasi format IP/CIDR sederhana
if [[ ! "$STATIC_CIDR" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    echo -e "${RED}ERROR: Format IP/CIDR salah!${NC}"
    exit 1
fi

# ===================== DETEKSI IP DAN DOMAIN =====================
echo -e "\n${GREEN}Masukkan domain yang diinginkan (contoh: wikrama.local):${NC}"
read -p ">> " DOMAIN

echo -e "\n${GREEN}Masukkan IP untuk DNS server (bisa pakai IP static tadi):${NC}"
read -p ">> " DNS_IP

# ===================== KONFIRMASI SEBELUM INSTALASI =====================
echo -e "\n${YELLOW}══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  DATA YANG AKAN DIGUNAKAN:${NC}"
echo -e "  Interface DHCP    : $DHCP_IFACE"
echo -e "  IP Static/CIDR    : $STATIC_CIDR"
echo -e "  Domain            : $DOMAIN"
echo -e "  IP DNS            : $DNS_IP"
echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
echo -e "${RED}PERINGATAN: Semua service lama (Apache2, MySQL, PHP, FTP, Samba, DHCP, DNS, Postfix, Dovecot, WordPress) akan DIHAPUS TOTAL beserta konfigurasinya!${NC}"
read -p "Lanjutkan? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Dibatalkan.${NC}"
    exit 0
fi

# ===================== HAPUS SEMUA SERVICE LAMA =====================
echo -e "\n${YELLOW}[1/8] Menghapus semua service lama ...${NC}"
systemctl stop apache2 mysql php8.* bind9 isc-dhcp-server vsftpd samba postfix dovecot 2>/dev/null || true
systemctl disable apache2 mysql php8.* bind9 isc-dhcp-server vsftpd samba postfix dovecot 2>/dev/null || true
apt remove --purge -y apache2* mysql* php* bind9* isc-dhcp-server vsftpd samba* postfix dovecot* wordpress* 2>/dev/null || true
apt autoremove -y
rm -rf /etc/apache2 /etc/mysql /etc/php /etc/bind /etc/dhcp /etc/samba /etc/postfix /etc/dovecot /var/www/html/* 2>/dev/null || true

# ===================== INSTALL ULANG SEMUA SERVICE =====================
echo -e "\n${YELLOW}[2/8] Update sistem & install ulang semua package ...${NC}"
apt update
apt install -y isc-dhcp-server bind9 bind9utils bind9-doc apache2 php php-mysql libapache2-mod-php mysql-server vsftpd samba samba-common-bin postfix dovecot-core dovecot-imapd dovecot-pop3d wordpress wget unzip

# ===================== KONFIGURASI DHCP =====================
echo -e "\n${YELLOW}[3/8] Mengkonfigurasi DHCP server ...${NC}"
# Hitung range IP dari static IP (IP +100 s/d +200)
IFS='/' read -r base_ip cidr <<< "$STATIC_CIDR"
IFS='.' read -r a b c d <<< "$base_ip"
ip_int=$((a*256**3 + b*256**2 + c*256 + d))
start_int=$((ip_int + 100))
end_int=$((ip_int + 200))
start_ip=$(printf "%d.%d.%d.%d" $((start_int>>24 & 255)) $((start_int>>16 & 255)) $((start_int>>8 & 255)) $((start_int & 255)))
end_ip=$(printf "%d.%d.%d.%d" $((end_int>>24 & 255)) $((end_int>>16 & 255)) $((end_int>>8 & 255)) $((end_int & 255)))

cat > /etc/dhcp/dhcpd.conf <<EOF
option domain-name "$DOMAIN";
option domain-name-servers $DNS_IP;
default-lease-time 600;
max-lease-time 7200;
subnet $a.$b.$c.0 netmask 255.255.255.0 {
    range $start_ip $end_ip;
    option routers $base_ip;
    option subnet-mask 255.255.255.0;
    option domain-name-servers $DNS_IP;
}
EOF

echo "INTERFACESv4=\"$DHCP_IFACE\"" > /etc/default/isc-dhcp-server
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server

# ===================== KONFIGURASI DNS BIND9 =====================
echo -e "\n${YELLOW}[4/8] Mengkonfigurasi DNS BIND9 ...${NC}"
cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.$DOMAIN";
};
EOF

rev_ip=$(echo $DNS_IP | awk -F. '{print $4"."$3"."$2"."$1}')
cat > /etc/bind/db.$DOMAIN <<EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                        2025010101      ; Serial
                        604800          ; Refresh
                        86400           ; Retry
                        2419200         ; Expire
                        604800 )        ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
@       IN      NS      ns2.$DOMAIN.
@       IN      NS      ns3.$DOMAIN.
@       IN      A       $DNS_IP
ns1     IN      A       $DNS_IP
ns2     IN      A       $DNS_IP
ns3     IN      A       $DNS_IP
www     IN      A       $DNS_IP
mail    IN      A       $DNS_IP
crud    IN      A       $DNS_IP
EOF

systemctl restart bind9
systemctl enable bind9

# ===================== APACHE2 + VIRTUAL HOST =====================
echo -e "\n${YELLOW}[5/8] Mengkonfigurasi Apache2 & Virtual Host ...${NC}"
a2enmod rewrite

# Virtual Host www.domain
cat > /etc/apache2/sites-available/www.$DOMAIN.conf <<EOF
<VirtualHost *:80>
    ServerName www.$DOMAIN
    DocumentRoot /var/www/html/www
    <Directory /var/www/html/www>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Virtual Host mail.domain
cat > /etc/apache2/sites-available/mail.$DOMAIN.conf <<EOF
<VirtualHost *:80>
    ServerName mail.$DOMAIN
    DocumentRoot /var/www/html/mail
</VirtualHost>
EOF

# Virtual Host crud.domain
cat > /etc/apache2/sites-available/crud.$DOMAIN.conf <<EOF
<VirtualHost *:80>
    ServerName crud.$DOMAIN
    DocumentRoot /var/www/html/crud
</VirtualHost>
EOF

mkdir -p /var/www/html/{www,mail,crud}

# Halaman www.domain
cat > /var/www/html/www/index.html <<'EOF'
<!DOCTYPE html>
<html lang="id">
<head><meta charset="UTF-8"><title>TJKT SMK Wikrama Bogor</title>
<style>body{font-family:Arial; background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); color:white; padding:20px;}
.container{max-width:800px; margin:auto; background:rgba(0,0,0,0.7); padding:30px; border-radius:20px;}
ul{list-style:none; padding:0;} li{background:#f4f4f4; color:#333; margin:10px; padding:15px; border-radius:10px;}
</style></head>
<body><div class="container">
<h1>✨ SMK Wikrama Bogor - TJKT ✨</h1>
<p>Teknik Jaringan Komputer dan Telekomunikasi</p>
<h2>📚 Materi Belajar Unggulan:</h2>
<ul><li>🤖 AIJ (Administrasi Infrastruktur Jaringan)</li><li>📡 TLJ (Teknologi Layanan Jaringan)</li><li>💻 Pemrograman Web</li><li>🗄️ Basis Data</li><li>📊 PKK (Produk Kreatif dan Kewirausahaan)</li></ul>
<p>🌟 <strong>Keren abis!</strong> Wikrama Juara! 🌟</p>
</div></body></html>
EOF

# Halaman mail.domain
cat > /var/www/html/mail/index.html <<EOF
<!DOCTYPE html>
<html><head><title>Mail Server</title></head>
<body><h1>📧 Mail Server $DOMAIN</h1>
<p>Mail server menggunakan Postfix + Dovecot</p>
<p>IMAP/SMTP: mail.$DOMAIN</p>
<p>Login: ftpuser@$DOMAIN (setelah FTP dibuat)</p>
</body></html>
EOF

# Halaman CRUD siswa (PHP + MySQL)
cat > /var/www/html/crud/index.php <<'EOF'
<?php
$host = 'localhost'; $user = 'root'; $pass = ''; $db = 'siswa';
$conn = new mysqli($host, $user, $pass, $db);
if ($conn->connect_error) die("Koneksi gagal");
if($_SERVER['REQUEST_METHOD']=='POST' && isset($_POST['add'])){
    $conn->query("INSERT INTO siswa (NIS, Nama, Rombel, Rayon) VALUES ('$_POST[NIS]','$_POST[Nama]','$_POST[Rombel]','$_POST[Rayon]')");
}
if(isset($_GET['delete'])) $conn->query("DELETE FROM siswa WHERE NIS='$_GET[delete]'");
?>
<!DOCTYPE html>
<html><head><title>CRUD Siswa - Keren</title>
<style>body{font-family:Arial; background:#ecf0f1; padding:20px;} table{width:100%; background:white; border-radius:10px;} th{background:#3498db; color:white;} td,th{padding:10px;} form{background:white; padding:20px; border-radius:10px; margin-bottom:20px;}</style>
</head><body>
<h2>📋 CRUD Data Siswa TJKT Wikrama</h2>
<form method="post"><input type="text" name="NIS" placeholder="NIS" required> <input type="text" name="Nama" placeholder="Nama"> <input type="text" name="Rombel" placeholder="Rombel"> <input type="text" name="Rayon" placeholder="Rayon"> <button type="submit" name="add">Tambah</button></form>
<table border=1><tr><th>NIS</th><th>Nama</th><th>Rombel</th><th>Rayon</th><th>Aksi</th></tr>
<?php $res=$conn->query("SELECT * FROM siswa"); while($row=$res->fetch_assoc()){ echo "<tr><td>$row[NIS]</td><td>$row[Nama]</td><td>$row[Rombel]</td><td>$row[Rayon]</td><td><a href='?delete=$row[NIS]'>Hapus</a></td></tr>"; } ?>
</table></body></html>
EOF

# Setup database & tabel
mysql -e "CREATE DATABASE IF NOT EXISTS siswa; USE siswa; CREATE TABLE IF NOT EXISTS siswa (NIS VARCHAR(20) PRIMARY KEY, Nama VARCHAR(100), Rombel VARCHAR(50), Rayon VARCHAR(50));"

a2ensite www.$DOMAIN.conf mail.$DOMAIN.conf crud.$DOMAIN.conf
a2dissite 000-default.conf
systemctl restart apache2

# ===================== FTP SERVER =====================
echo -e "\n${YELLOW}[6/8] Mengkonfigurasi FTP server ...${NC}"
useradd -m -s /bin/bash ftpuser 2>/dev/null || true
echo "ftpuser:wikrama123" | chpasswd
echo "ftpuser" >> /etc/vsftpd.user_list
cat > /etc/vsftpd.conf <<EOF
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
userlist_enable=YES
userlist_file=/etc/vsftpd.user_list
userlist_deny=NO
EOF
systemctl restart vsftpd
systemctl enable vsftpd

# ===================== SAMBA SHARE =====================
echo -e "\n${YELLOW}[7/8] Mengkonfigurasi Samba share ...${NC}"
mkdir -p /srv/tjkt-wikrama
chown nobody:nogroup /srv/tjkt-wikrama
chmod 777 /srv/tjkt-wikrama
cat >> /etc/samba/smb.conf <<EOF
[tjkt-wikrama]
   path = /srv/tjkt-wikrama
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0777
   directory mask = 0777
EOF
systemctl restart smbd
systemctl enable smbd

# ===================== MAIL SERVER (Postfix+Dovecot) =====================
echo -e "\n${YELLOW}[8/8] Mengkonfigurasi Mail server ...${NC}"
debconf-set-selections <<< "postfix postfix/mailname string $DOMAIN"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d
systemctl restart postfix dovecot
systemctl enable postfix dovecot

# ===================== WORDPRESS =====================
echo -e "\n${YELLOW}[EXTRA] Memasang WordPress ...${NC}"
rm -rf /var/www/html/wordpress
cp -r /usr/share/wordpress /var/www/html/
chown -R www-data:www-data /var/www/html/wordpress
mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
cat > /var/www/html/wordpress/wp-config.php <<EOF
<?php
define('DB_NAME', 'wordpress');
define('DB_USER', 'root');
define('DB_PASSWORD', '');
define('DB_HOST', 'localhost');
define('WP_HOME', 'http://$DNS_IP');
define('WP_SITEURL', 'http://$DNS_IP');
\$table_prefix = 'wp_';
require_once(ABSPATH . 'wp-settings.php');
EOF

# ===================== TAMPILAN PANDUAN AKHIR =====================
echo -e "\n${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}              INSTALASI SELESAI 100% SUKSES!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🌐 AKSES LAYANAN:${NC}"
echo -e "  📍 WordPress       : ${YELLOW}http://$DNS_IP/wordpress${NC}"
echo -e "  📍 CRUD Siswa      : ${YELLOW}http://crud.$DOMAIN${NC}  atau  http://$DNS_IP/crud"
echo -e "  📍 Web Informasi   : ${YELLOW}http://www.$DOMAIN${NC}  atau  http://$DNS_IP/www"
echo -e "  📍 Mail Server Info: ${YELLOW}http://mail.$DOMAIN${NC}"
echo -e "  📍 FTP             : ${YELLOW}ftp://$DNS_IP${NC}  (user: ftpuser / pass: wikrama123)"
echo -e "  📍 Samba Share     : ${YELLOW}\\\\$DNS_IP\\tjkt-wikrama${NC} (Guest akses)"
echo -e "  📍 Mail (IMAP/POP3): ${YELLOW}mail.$DOMAIN${NC}"
echo -e "\n${BLUE}🛠️ TESTING DNS:${NC}"
echo -e "  ${YELLOW}nslookup www.$DOMAIN $DNS_IP${NC}"
echo -e "  ${YELLOW}nslookup mail.$DOMAIN $DNS_IP${NC}"
echo -e "  ${YELLOW}nslookup crud.$DOMAIN $DNS_IP${NC}"
echo -e "\n${BLUE}🔐 INFORMASI LOGIN:${NC}"
echo -e "  FTP User     : ftpuser / wikrama123"
echo -e "  MySQL root   : (tanpa password, langsung enter)"
echo -e "  Samba Share  : Guest (tanpa user/pass)"
echo -e "\n${GREEN}✨ Server siap digunakan! Selamat mencoba ~ TJKT Wikrama Juara! ✨${NC}"
