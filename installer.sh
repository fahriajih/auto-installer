#!/bin/bash

# ============================================================
# FAHTECH AUTOMATION - TJKT SMK WIKRAMA
# VERSION FINAL - ALL SERVICES WORKING
# CRUD ACCESS: http://IP/crud/
# ============================================================

clear_screen() {
    printf "\033[2J\033[H"
}

banner() {
    clear_screen
    echo "================================================================================"
    echo "                                                                                "
    echo "     ███████╗ █████╗ ██╗  ██╗████████╗███████╗ ██████╗██╗  ██╗                  "
    echo "     ██╔════╝██╔══██╗██║  ██║╚══██╔══╝██╔════╝██╔════╝██║  ██║                  "
    echo "     █████╗  ███████║███████║   ██║   █████╗  ██║     ███████║                  "
    echo "     ██╔══╝  ██╔══██║██╔══██║   ██║   ██╔══╝  ██║     ██╔══██║                  "
    echo "     ██║     ██║  ██║██║  ██║   ██║   ███████╗╚██████╗██║  ██║                  "
    echo "     ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝                  "
    echo "                                                                                "
    echo "                   TJKT SMK WIKRAMA - AUTO CONFIGURATION                        "
    echo "                              PILIH NOMOR LAYANAN                               "
    echo "================================================================================"
    echo ""
}

get_ips() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
}

pilih_ip() {
    local IP_LIST=()
    while IFS= read -r line; do
        IP_LIST+=("$line")
    done < <(get_ips)

    if [ ${#IP_LIST[@]} -eq 0 ]; then
        echo "[ERROR] Tidak ada IP terdeteksi!"
        exit 1
    fi

    echo "============================================================"
    echo "            DAFTAR IP YANG TERSEDIA"
    echo "============================================================"

    for i in "${!IP_LIST[@]}"; do
        echo "  $((i+1)). ${IP_LIST[$i]}"
    done

    echo ""
    read -p "Pilih nomor IP: " IP_CHOICE

    if [[ ! "$IP_CHOICE" =~ ^[0-9]+$ ]] || [ "$IP_CHOICE" -lt 1 ] || [ "$IP_CHOICE" -gt ${#IP_LIST[@]} ]; then
        echo "[ERROR] Pilihan tidak valid!"
        exit 1
    fi

    SELECTED_IP="${IP_LIST[$((IP_CHOICE-1))]}"
    echo "[OK] IP terpilih: $SELECTED_IP"
    echo ""
    sleep 1
}

fix_permission() {
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    systemctl restart apache2 2>/dev/null
}

# ==================== 1. APACHE2 + LANDING PAGE ====================
install_apache_landing() {
    echo "[INSTALL] Memulai instalasi Apache2 + Landing Page..."
    pilih_ip
    apt update && apt install -y apache2

    rm -rf /var/www/html/*

    cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SMK Wikrama - TJKT</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: rgba(255,255,255,0.95);
            border-radius: 20px;
            padding: 50px;
            text-align: center;
            max-width: 700px;
            margin: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
            font-size: 2.5em;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        h2 { color: #4a5568; margin-bottom: 20px; font-size: 1.2em; }
        .features {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 15px;
            margin: 30px 0;
        }
        .feature-card {
            background: linear-gradient(135deg, #667eea, #764ba2);
            padding: 15px;
            border-radius: 10px;
            color: white;
        }
        .btn {
            display: inline-block;
            padding: 12px 30px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            text-decoration: none;
            border-radius: 25px;
            margin-top: 20px;
        }
        footer { margin-top: 30px; color: #a0aec0; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 SMK WIKRAMA</h1>
        <h2>TEKNIK JARINGAN & TELEKOMUNIKASI</h2>
        <div class="features">
            <div class="feature-card">💻 Networking Expert</div>
            <div class="feature-card">🔧 Server Administrator</div>
            <div class="feature-card">🌐 Web Development</div>
            <div class="feature-card">📡 Cybersecurity</div>
        </div>
        <p>Selamat datang di layanan auto-configuration Fahtech!</p>
        <a href="#" class="btn">Explore More →</a>
        <footer>© 2025 TJKT SMK Wikrama | Powered by Fahtech Automation</footer>
    </div>
</body>
</html>
EOF

    fix_permission
    echo ""
    echo "[SUCCESS] Apache2 + Landing Page BERHASIL!"
    echo "[ACCESS] http://$SELECTED_IP"
    echo ""
}

# ==================== 2. DHCP SERVER ====================
install_dhcp() {
    echo "[INSTALL] Memulai instalasi DHCP Server..."
    pilih_ip
    apt update && apt install -y isc-dhcp-server

    INTERFACE=$(ip -4 addr show | grep -B2 "$SELECTED_IP" | head -n1 | awk '{print $2}' | tr -d ':')
    NETWORK=$(echo $SELECTED_IP | cut -d. -f1-3).0

    cat > /etc/default/isc-dhcp-server << EOF
INTERFACESv4="$INTERFACE"
INTERFACESv6=""
EOF

    cat > /etc/dhcp/dhcpd.conf << EOF
option domain-name "wikrama.local";
option domain-name-servers $SELECTED_IP;
default-lease-time 600;
max-lease-time 7200;
subnet $NETWORK netmask 255.255.255.0 {
    range ${NETWORK%.0}.100 ${NETWORK%.0}.200;
    option routers $SELECTED_IP;
    option subnet-mask 255.255.255.0;
    option domain-name-servers $SELECTED_IP;
}
EOF

    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server

    echo ""
    echo "[SUCCESS] DHCP Server BERHASIL!"
    echo "[RANGE] ${NETWORK%.0}.100 - ${NETWORK%.0}.200"
    echo ""
}

# ==================== 3. DNS SINGLE ====================
install_dns_single() {
    echo "[INSTALL] Memulai instalasi DNS Server (Single)..."
    pilih_ip
    read -p "Masukkan domain (contoh: tjkt.wikrama.sch.id): " DOMAIN

    apt update && apt install -y bind9

    cat > /etc/bind/named.conf.local << EOF
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.$DOMAIN";
};
EOF

    cat > /etc/bind/db.$DOMAIN << EOF
\$TTL    604800
@       IN      SOA     ns.$DOMAIN. admin.$DOMAIN. (
                  2025010101
                  604800
                  86400
                  2419200
                  604800 )
@       IN      NS      ns.$DOMAIN.
@       IN      A       $SELECTED_IP
ns      IN      A       $SELECTED_IP
www     IN      A       $SELECTED_IP
EOF

    systemctl restart bind9

    echo ""
    echo "[SUCCESS] DNS Server BERHASIL!"
    echo "[DOMAIN] $DOMAIN"
    echo "[TEST] nslookup $DOMAIN $SELECTED_IP"
    echo ""
}

# ==================== 4. 3 DNS SERVER ====================
install_dns_triple() {
    echo "[INSTALL] Memulai instalasi 3 DNS Server..."
    pilih_ip

    apt update && apt install -y bind9 apache2

    declare -a DOMAINS

    for i in 1 2 3; do
        read -p "Masukkan domain ke-$i (contoh: domain$i.com): " DOM

        mkdir -p /var/www/$DOM

        cat > /var/www/$DOM/index.html << EOF
<!DOCTYPE html>
<html>
<head><title>$DOM</title>
<style>
body{background:linear-gradient(135deg,#667eea,#764ba2);font-family:Arial;text-align:center;padding:50px;color:white}
.card{background:rgba(0,0,0,0.3);border-radius:20px;padding:40px;max-width:600px;margin:auto}
h1{font-size:48px}
</style>
</head>
<body>
<div class="card">
<h1>🚀 $DOM</h1>
<p>DNS Server Ke-$i - TJKT SMK WIKRAMA</p>
<p>Dikonfigurasi oleh Fahtech Automation</p>
</div>
</body>
</html>
EOF

        DOMAINS[$i]=$DOM

        cat >> /etc/bind/named.conf.local << EOF
zone "$DOM" {
    type master;
    file "/etc/bind/db.$DOM";
};
EOF

        cat > /etc/bind/db.$DOM << EOF
\$TTL    604800
@       IN      SOA     ns.$DOM. admin.$DOM. (
                  2025010101
                  604800
                  86400
                  2419200
                  604800 )
@       IN      NS      ns.$DOM.
@       IN      A       $SELECTED_IP
ns      IN      A       $SELECTED_IP
www     IN      A       $SELECTED_IP
EOF

        cat > /etc/apache2/sites-available/$DOM.conf << EOF
<VirtualHost *:80>
    ServerName $DOM
    DocumentRoot /var/www/$DOM
</VirtualHost>
EOF
        a2ensite $DOM.conf
    done

    systemctl restart bind9
    systemctl reload apache2
    fix_permission

    echo ""
    echo "[SUCCESS] 3 DNS Server BERHASIL!"
    for i in 1 2 3; do
        echo "  🌐 http://${DOMAINS[$i]}"
    done
    echo ""
}

# ==================== 5. FTP SERVER ====================
install_ftp() {
    echo "[INSTALL] Memulai instalasi FTP Server..."
    pilih_ip
    apt update && apt install -y vsftpd

    cat > /etc/vsftpd.conf << EOF
listen=YES
listen_ipv6=NO
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
pasv_enable=YES
pasv_min_port=10000
pasv_max_port=10100
EOF

    useradd -m -s /bin/bash ftpuser 2>/dev/null
    echo "ftpuser:wikrama123" | chpasswd

    systemctl restart vsftpd
    systemctl enable vsftpd

    echo ""
    echo "[SUCCESS] FTP Server BERHASIL!"
    echo "[SERVER] ftp://$SELECTED_IP"
    echo "[USER] ftpuser / PASS: wikrama123"
    echo ""
}

# ==================== 6. SAMBA SERVER ====================
install_samba() {
    echo "[INSTALL] Memulai instalasi Samba Server..."
    pilih_ip
    apt update && apt install -y samba

    mkdir -p /srv/samba/share
    chmod 777 /srv/samba/share

    cat >> /etc/samba/smb.conf << EOF

[wikrama-share]
   path = /srv/samba/share
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0777
   directory mask = 0777
   force user = nobody
EOF

    systemctl restart smbd
    systemctl enable smbd

    echo ""
    echo "[SUCCESS] Samba Server BERHASIL!"
    echo "[SHARE] \\\\$SELECTED_IP\\wikrama-share"
    echo ""
}

# ==================== 7. CRUD APPLICATION (FIXED - /crud/) ====================
install_crud() {
    echo "[INSTALL] Memulai instalasi CRUD Application..."
    pilih_ip
    
    apt update
    apt install -y apache2 php php-mysql libapache2-mod-php mariadb-server

    systemctl start mariadb
    systemctl enable mariadb

    mysql << EOF
CREATE DATABASE IF NOT EXISTS siswa_wikrama;
USE siswa_wikrama;
CREATE TABLE IF NOT EXISTS data_siswa (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nis VARCHAR(20) NOT NULL UNIQUE,
    nama VARCHAR(100) NOT NULL,
    rombel VARCHAR(50) NOT NULL,
    rayon VARCHAR(50) NOT NULL
);
INSERT IGNORE INTO data_siswa (nis, nama, rombel, rayon) VALUES 
('12345', 'Ahmad Fahtech', 'TJKT-1', 'Ciawi'),
('12346', 'Budi Santoso', 'TJKT-2', 'Bogor');
EOF

    # Buat folder crud (bukan file crud.php)
    mkdir -p /var/www/html/crud

    cat > /var/www/html/crud/index.php << 'EOF'
<?php
$conn = new mysqli('localhost', 'root', '', 'siswa_wikrama');
if ($conn->connect_error) die("Koneksi gagal: " . $conn->connect_error);

if(isset($_POST['add'])) {
    $conn->query("INSERT INTO data_siswa (nis, nama, rombel, rayon) VALUES 
        ('{$_POST['nis']}', '{$_POST['nama']}', '{$_POST['rombel']}', '{$_POST['rayon']}')");
    echo "<script>alert('Data ditambahkan!'); window.location='index.php';</script>";
}

if(isset($_POST['update'])) {
    $conn->query("UPDATE data_siswa SET nis='{$_POST['nis']}', nama='{$_POST['nama']}', 
        rombel='{$_POST['rombel']}', rayon='{$_POST['rayon']}' WHERE id={$_POST['id']}");
    echo "<script>alert('Data diupdate!'); window.location='index.php';</script>";
}

if(isset($_GET['delete'])) {
    $conn->query("DELETE FROM data_siswa WHERE id={$_GET['delete']}");
    echo "<script>alert('Data dihapus!'); window.location='index.php';</script>";
}

$edit = null;
if(isset($_GET['edit'])) {
    $result = $conn->query("SELECT * FROM data_siswa WHERE id={$_GET['edit']}");
    $edit = $result->fetch_assoc();
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>CRUD Siswa - TJKT Wikrama</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial; background: linear-gradient(135deg, #667eea, #764ba2); padding: 20px; }
        .container { max-width: 1000px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; }
        h1, h2 { color: #667eea; }
        input { width: 100%; padding: 10px; margin: 5px 0 15px 0; border: 1px solid #ddd; border-radius: 5px; }
        button { background: #667eea; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #667eea; color: white; }
        .edit { color: green; text-decoration: none; margin-right: 10px; }
        .delete { color: red; text-decoration: none; }
    </style>
</head>
<body>
<div class="container">
    <h1>🚀 TJKT SMK WIKRAMA</h1>
    <h2>Manajemen Data Siswa (CRUD)</h2>
    <form method="POST">
        <input type="hidden" name="id" value="<?= $edit['id'] ?? '' ?>">
        <input type="text" name="nis" placeholder="NIS" value="<?= $edit['nis'] ?? '' ?>" required>
        <input type="text" name="nama" placeholder="Nama Lengkap" value="<?= $edit['nama'] ?? '' ?>" required>
        <input type="text" name="rombel" placeholder="Rombel" value="<?= $edit['rombel'] ?? '' ?>" required>
        <input type="text" name="rayon" placeholder="Rayon" value="<?= $edit['rayon'] ?? '' ?>" required>
        <?php if($edit): ?>
            <button type="submit" name="update">Update Data</button>
            <a href="index.php">Batal</a>
        <?php else: ?>
            <button type="submit" name="add">Tambah Data</button>
        <?php endif; ?>
    </form>
    <h3>Data Siswa:</h3>
    <table border="1">
        <tr><th>ID</th><th>NIS</th><th>Nama</th><th>Rombel</th><th>Rayon</th><th>Aksi</th></tr>
        <?php
        $result = $conn->query("SELECT * FROM data_siswa ORDER BY id DESC");
        while($row = $result->fetch_assoc()):
        ?>
        <tr>
            <td><?= $row['id'] ?></td>
            <td><?= $row['nis'] ?></td>
            <td><?= $row['nama'] ?></td>
            <td><?= $row['rombel'] ?></td>
            <td><?= $row['rayon'] ?></td>
            <td>
                <a href="index.php?edit=<?= $row['id'] ?>" class="edit">Edit</a>
                <a href="index.php?delete=<?= $row['id'] ?>" class="delete" onclick="return confirm('Yakin?')">Hapus</a>
            </td>
        </tr>
        <?php endwhile; ?>
    </table>
</div>
</body>
</html>
EOF

    fix_permission

    echo ""
    echo "[SUCCESS] CRUD Application BERHASIL!"
    echo "[ACCESS] http://$SELECTED_IP/crud/"
    echo ""
}

# ==================== 8. WORDPRESS ====================
install_wordpress() {
    echo "[INSTALL] Memulai instalasi WordPress..."
    pilih_ip
    apt update
    apt install -y apache2 php php-mysql php-curl php-gd php-mbstring php-xml php-zip libapache2-mod-php mariadb-server

    systemctl start mariadb
    systemctl enable mariadb

    DB_PASS=$(openssl rand -base64 12)
    mysql << EOF
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
EOF

    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    cp -r wordpress/* /var/www/html/
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

    sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php
    sed -i "s/password_here/$DB_PASS/" /var/www/html/wp-config.php

    fix_permission

    echo ""
    echo "[SUCCESS] WordPress BERHASIL!"
    echo "[ACCESS] http://$SELECTED_IP/wp-admin/install.php"
    echo "[DB PASS] $DB_PASS"
    echo ""
}

# ==================== 9. MAIL SERVER ====================
install_mailserver() {
    echo "[INSTALL] Memulai instalasi Mail Server..."
    pilih_ip
    read -p "Masukkan domain untuk email (contoh: mail.wikrama.sch.id): " MAIL_DOMAIN

    apt update && apt install -y bind9 postfix dovecot-imapd dovecot-pop3d mailutils

    cat > /etc/bind/named.conf.local << EOF
zone "$MAIL_DOMAIN" {
    type master;
    file "/etc/bind/db.$MAIL_DOMAIN";
};
EOF

    cat > /etc/bind/db.$MAIL_DOMAIN << EOF
\$TTL    604800
@       IN      SOA     ns.$MAIL_DOMAIN. admin.$MAIL_DOMAIN. (
                  2025010101
                  604800
                  86400
                  2419200
                  604800 )
@       IN      NS      ns.$MAIL_DOMAIN.
@       IN      A       $SELECTED_IP
ns      IN      A       $SELECTED_IP
mail    IN      A       $SELECTED_IP
@       IN      MX      10      mail.$MAIL_DOMAIN
EOF

    systemctl restart bind9

    debconf-set-selections <<< "postfix postfix/mailname string $MAIL_DOMAIN"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    apt install -y postfix

    postconf -e "myhostname = mail.$MAIL_DOMAIN"
    postconf -e "mydomain = $MAIL_DOMAIN"
    postconf -e "myorigin = \$mydomain"
    postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"

    useradd -m -s /bin/bash admin 2>/dev/null
    echo "admin:wikramamail123" | chpasswd

    systemctl restart postfix dovecot

    echo ""
    echo "[SUCCESS] Mail Server BERHASIL!"
    echo "[DOMAIN] $MAIL_DOMAIN"
    echo "[USER] admin / PASS: wikramamail123"
    echo ""
}

# ==================== 10. ZABBIX SERVER ====================
install_zabbix() {
    echo "[INSTALL] Memulai instalasi Zabbix Server..."
    pilih_ip
    apt update && apt install -y wget gnupg2 mariadb-server

    wget -q https://repo.zabbix.com/zabbix/6.4/debian/pool/main/z/zabbix-release/zabbix-release_6.4-1+debian12_all.deb
    dpkg -i zabbix-release_6.4-1+debian12_all.deb
    apt update

    apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

    mysql << EOF
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'zabbix123';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EOF

    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbix123 zabbix

    sed -i "s/# DBPassword=/DBPassword=zabbix123/" /etc/zabbix/zabbix_server.conf
    systemctl restart zabbix-server zabbix-agent apache2
    systemctl enable zabbix-server zabbix-agent

    echo ""
    echo "[SUCCESS] Zabbix Server BERHASIL!"
    echo "[ACCESS] http://$SELECTED_IP/zabbix"
    echo "[LOGIN] Admin / zabbix"
    echo ""
}

# ==================== 11. HAPUS SEMUA SERVICE ====================
hapus_semua() {
    echo "============================================================"
    echo "  PERINGATAN: Ini akan menghapus SEMUA service!"
    echo "============================================================"
    read -p "Yakin? (ketik 'YA' untuk lanjut): " CONFIRM
    if [ "$CONFIRM" != "YA" ]; then
        echo "[BATAL]"
        return
    fi

    systemctl stop apache2 mariadb postfix dovecot bind9 isc-dhcp-server vsftpd smbd zabbix-server 2>/dev/null

    apt remove --purge -y apache2 mariadb-server php* postfix dovecot* bind9 isc-dhcp-server vsftpd samba zabbix-server-mysql zabbix-frontend-php 2>/dev/null
    apt autoremove -y

    rm -rf /var/www/html/* /etc/bind/* /etc/dhcp/* /srv/samba/* /var/lib/mysql /etc/zabbix 2>/dev/null

    echo ""
    echo "[SUCCESS] Semua service telah dihapus!"
    echo ""
}

# ==================== 12. INSTALL SEMUA SERVICE ====================
install_semua() {
    echo "============================================================"
    echo "  MEMULAI INSTALL SEMUA SERVICE"
    echo "============================================================"
    install_apache_landing
    install_dhcp
    install_dns_single
    install_ftp
    install_samba
    install_crud
    install_wordpress
    install_zabbix
    echo "============================================================"
    echo "[SUCCESS] SEMUA service berhasil diinstall!"
    echo "============================================================"
}

# ==================== MAIN MENU ====================
while true; do
    banner
    echo "================================================================================"
    echo "                            DAFTAR LAYANAN"
    echo "================================================================================"
    echo "  1.  Apache2 + Landing Page TJKT"
    echo "  2.  DHCP Server (Range 100-200)"
    echo "  3.  DNS Server (Single Domain)"
    echo "  4.  3 DNS Server (3 Domain Berbeda)"
    echo "  5.  FTP Server"
    echo "  6.  Samba Server (SMB Share)"
    echo "  7.  CRUD Application (Data Siswa) - Akses /crud/"
    echo "  8.  WordPress CMS"
    echo "  9.  Mail Server (Postfix + Dovecot)"
    echo "  10. Zabbix Server Monitoring"
    echo "  11. Hapus Semua Service"
    echo "  12. Install Semua Service Sekaligus"
    echo "  0.  Keluar"
    echo "================================================================================"
    echo ""
    read -p "Pilih nomor [0-12]: " MENU_CHOICE

    case $MENU_CHOICE in
        1) install_apache_landing ;;
        2) install_dhcp ;;
        3) install_dns_single ;;
        4) install_dns_triple ;;
        5) install_ftp ;;
        6) install_samba ;;
        7) install_crud ;;
        8) install_wordpress ;;
        9) install_mailserver ;;
        10) install_zabbix ;;
        11) hapus_semua ;;
        12) install_semua ;;
        0) 
            echo ""
            echo "Terima kasih - Fahtech Automation"
            echo "TJKT SMK WIKRAMA"
            exit 0 
            ;;
        *) 
            echo "Pilihan salah!"
            sleep 1
            ;;
    esac

    if [ "$MENU_CHOICE" != "0" ]; then
        echo ""
        read -p "Tekan Enter untuk kembali ke menu..."
    fi
done
