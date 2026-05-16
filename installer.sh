#!/bin/bash

# ============================================================
# FAHTECH AUTOMATION - ULTIMATE FIX
# ============================================================

clear_screen() { printf "\033[2J\033[H"; }

banner() {
    clear_screen
    echo "================================================================================"
    echo "     ███████╗ █████╗ ██╗  ██╗████████╗███████╗ ██████╗██╗  ██╗                  "
    echo "     ██╔════╝██╔══██╗██║  ██║╚══██╔══╝██╔════╝██╔════╝██║  ██║                  "
    echo "     █████╗  ███████║███████║   ██║   █████╗  ██║     ███████║                  "
    echo "     ██╔══╝  ██╔══██║██╔══██║   ██║   ██╔══╝  ██║     ██╔══██║                  "
    echo "     ██║     ██║  ██║██║  ██║   ██║   ███████╗╚██████╗██║  ██║                  "
    echo "     ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝                  "
    echo "                   TJKT SMK WIKRAMA - AUTO CONFIGURATION                        "
    echo "================================================================================"
    echo ""
}

get_ips() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
}

pilih_ip() {
    local IP_LIST=()
    while IFS= read -r line; do IP_LIST+=("$line"); done < <(get_ips)
    
    if [ ${#IP_LIST[@]} -eq 0 ]; then echo "[ERROR] Tidak ada IP!"; exit 1; fi
    
    echo "============================================================"
    echo "            DAFTAR IP YANG TERSEDIA"
    echo "============================================================"
    for i in "${!IP_LIST[@]}"; do echo "  $((i+1)). ${IP_LIST[$i]}"; done
    echo ""
    read -p "Pilih nomor IP: " IP_CHOICE
    
    if [[ ! "$IP_CHOICE" =~ ^[0-9]+$ ]] || [ "$IP_CHOICE" -lt 1 ] || [ "$IP_CHOICE" -gt ${#IP_LIST[@]} ]; then
        echo "[ERROR] Pilihan tidak valid!"; exit 1
    fi
    
    SELECTED_IP="${IP_LIST[$((IP_CHOICE-1))]}"
    echo "[OK] IP terpilih: $SELECTED_IP"; sleep 1
}

# 1. Apache2 + Landing Page (PASTI JALAN)
install_apache_landing() {
    echo "[INSTALL] Apache2 + Landing Page..."
    pilih_ip
    
    apt update
    apt install -y apache2 php libapache2-mod-php
    
    # Bersihkan dan buat file baru
    rm -rf /var/www/html/*
    
    cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>SMK Wikrama - TJKT</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: 'Arial', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .card {
            background: white;
            border-radius: 20px;
            padding: 50px;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
        }
        h1 { color: #667eea; font-size: 2.5em; }
        .tagline { color: #764ba2; font-size: 1.2em; margin: 20px 0; }
        .features { display: flex; gap: 15px; margin: 30px 0; flex-wrap: wrap; justify-content: center; }
        .feature { background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 10px 20px; border-radius: 10px; }
        footer { margin-top: 30px; color: #999; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🚀 SMK WIKRAMA</h1>
        <h2>TEKNIK JARINGAN & TELEKOMUNIKASI</h2>
        <div class="tagline">🌟 Pusat Unggulan Teknologi Informasi dan Komunikasi 🌟</div>
        <div class="features">
            <div class="feature">💻 Networking</div>
            <div class="feature">🔧 Administrator</div>
            <div class="feature">🌐 Web Dev</div>
            <div class="feature">📡 Security</div>
        </div>
        <p>Auto Configuration by <strong>Fahtech</strong></p>
        <footer>© TJKT SMK Wikrama</footer>
    </div>
</body>
</html>
HTML

    # Fix permission
    chmod -R 755 /var/www/html/
    chown -R www-data:www-data /var/www/html/
    systemctl restart apache2
    
    echo ""
    echo "=========================================="
    echo "✅ SUCCESS!"
    echo "🌐 http://$SELECTED_IP"
    echo "=========================================="
    echo ""
}

# 2. DHCP Server
install_dhcp() {
    echo "[INSTALL] DHCP Server..."
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
}
EOF
    
    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server
    
    echo "✅ DHCP Server BERHASIL!"
    echo "📡 Range: ${NETWORK%.0}.100 - ${NETWORK%.0}.200"
    echo ""
}

# 3. Single DNS
install_dns_single() {
    echo "[INSTALL] DNS Server..."
    pilih_ip
    read -p "Masukkan domain: " DOMAIN
    
    apt update && apt install -y bind9
    
    cat > /etc/bind/named.conf.local << EOF
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.$DOMAIN";
};
EOF

    cat > /etc/bind/db.$DOMAIN << EOF
\$TTL    604800
@       IN      SOA     ns.$DOMAIN. admin.$DOMAIN. (2025010101 604800 86400 2419200 604800)
@       IN      NS      ns.$DOMAIN.
@       IN      A       $SELECTED_IP
ns      IN      A       $SELECTED_IP
www     IN      A       $SELECTED_IP
EOF

    systemctl restart bind9
    
    echo "✅ DNS Server BERHASIL!"
    echo "🌐 Domain: $DOMAIN"
    echo "🔍 nslookup $DOMAIN $SELECTED_IP"
    echo ""
}

# 4. Triple DNS
install_dns_triple() {
    echo "[INSTALL] 3 DNS Server..."
    pilih_ip
    
    apt update && apt install -y bind9 apache2
    a2enmod rewrite
    
    for i in 1 2 3; do
        read -p "Domain ke-$i: " DOM
        
        mkdir -p /var/www/$DOM
        
        cat > /var/www/$DOM/index.html << EOF
<!DOCTYPE html>
<html>
<head><title>$DOM</title>
<style>
body {
    margin: 0;
    padding: 50px;
    font-family: Arial;
    background: linear-gradient(135deg, #${RANDOM:0:6}, #${RANDOM:0:6});
    text-align: center;
    color: white;
}
.card {
    background: rgba(255,255,255,0.9);
    color: #333;
    padding: 40px;
    border-radius: 20px;
    max-width: 500px;
    margin: auto;
}
</style>
</head>
<body>
<div class="card">
    <h1>🚀 $DOM</h1>
    <h2>DNS Server Ke-$i</h2>
    <p>TJKT SMK WIKRAMA</p>
    <p>Powered by Fahtech Automation</p>
</div>
</body>
</html>
EOF
        
        cat >> /etc/bind/named.conf.local << EOF
zone "$DOM" {
    type master;
    file "/etc/bind/db.$DOM";
};
EOF

        cat > /etc/bind/db.$DOM << EOF
\$TTL 604800
@ IN SOA ns.$DOM. admin.$DOM. (2025010101 604800 86400 2419200 604800)
@ IN NS ns.$DOM.
@ IN A $SELECTED_IP
ns IN A $SELECTED_IP
www IN A $SELECTED_IP
EOF

        cat > /etc/apache2/sites-available/$DOM.conf << EOF
<VirtualHost *:80>
    ServerName $DOM
    ServerAlias www.$DOM
    DocumentRoot /var/www/$DOM
    <Directory /var/www/$DOM>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
        a2ensite $DOM.conf
    done
    
    systemctl restart bind9
    systemctl reload apache2
    chown -R www-data:www-data /var/www/
    chmod -R 755 /var/www/
    
    echo "✅ 3 DNS Server BERHASIL!"
    echo ""
}

# 5. FTP
install_ftp() {
    echo "[INSTALL] FTP Server..."
    pilih_ip
    apt update && apt install -y vsftpd
    
    cat > /etc/vsftpd.conf << EOF
listen=YES
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=10000
pasv_max_port=10100
EOF
    
    useradd -m ftpuser 2>/dev/null
    echo "ftpuser:wikrama123" | chpasswd
    
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    echo "✅ FTP Server BERHASIL!"
    echo "📁 ftp://$SELECTED_IP"
    echo "👤 ftpuser / wikrama123"
    echo ""
}

# 6. Samba
install_samba() {
    echo "[INSTALL] Samba Server..."
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
EOF
    
    systemctl restart smbd
    systemctl enable smbd
    
    echo "✅ Samba Server BERHASIL!"
    echo "📁 \\\\$SELECTED_IP\\wikrama-share"
    echo ""
}

# 7. CRUD (PASTI JALAN)
install_crud() {
    echo "[INSTALL] CRUD Application..."
    pilih_ip
    
    apt update
    apt install -y apache2 php php-mysql mariadb-server mariadb-client libapache2-mod-php
    
    # Start database
    systemctl start mariadb
    systemctl enable mariadb
    
    # Setup database
    mysql << 'MYSQL'
CREATE DATABASE IF NOT EXISTS siswa_wikrama;
USE siswa_wikrama;
CREATE TABLE IF NOT EXISTS data_siswa (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nis VARCHAR(20) NOT NULL,
    nama VARCHAR(100) NOT NULL,
    rombel VARCHAR(50) NOT NULL,
    rayon VARCHAR(50) NOT NULL
);
INSERT INTO data_siswa (nis, nama, rombel, rayon) VALUES 
('12345', 'Ahmad Fahtech', 'TJKT-1', 'Ciawi'),
('12346', 'Budi Santoso', 'TJKT-2', 'Bogor');
MYSQL
    
    # Buat file CRUD sederhana
    cat > /var/www/html/index.php << 'PHP'
<!DOCTYPE html>
<html>
<head>
    <title>CRUD Siswa - TJKT Wikrama</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Arial;
            background: linear-gradient(135deg, #667eea, #764ba2);
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 { color: #667eea; margin-bottom: 10px; }
        h2 { color: #764ba2; margin-bottom: 20px; }
        .form-group {
            display: inline-block;
            margin-right: 10px;
            margin-bottom: 15px;
        }
        input {
            padding: 10px;
            border: 2px solid #ddd;
            border-radius: 8px;
            width: 200px;
        }
        button {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 10px 25px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th { background: #667eea; color: white; }
        .edit { background: #4CAF50; color: white; padding: 5px 10px; text-decoration: none; border-radius: 5px; }
        .delete { background: #f44336; color: white; padding: 5px 10px; text-decoration: none; border-radius: 5px; }
        .stats { background: #e7f3ff; padding: 15px; border-radius: 10px; margin: 20px 0; }
    </style>
</head>
<body>
<div class="container">
    <h1>🚀 TJKT SMK WIKRAMA</h1>
    <h2>📚 Manajemen Data Siswa (CRUD)</h2>
    
    <?php
    $conn = new mysqli('localhost', 'root', '', 'siswa_wikrama');
    if ($conn->connect_error) die("Koneksi gagal: " . $conn->connect_error);
    
    // Tambah data
    if(isset($_POST['add'])) {
        $conn->query("INSERT INTO data_siswa (nis, nama, rombel, rayon) VALUES 
            ('{$_POST['nis']}', '{$_POST['nama']}', '{$_POST['rombel']}', '{$_POST['rayon']}')");
        echo "<script>alert('Data ditambahkan!'); window.location='';</script>";
    }
    
    // Update data
    if(isset($_POST['update'])) {
        $conn->query("UPDATE data_siswa SET nis='{$_POST['nis']}', nama='{$_POST['nama']}', 
            rombel='{$_POST['rombel']}', rayon='{$_POST['rayon']}' WHERE id={$_POST['id']}");
        echo "<script>alert('Data diupdate!'); window.location='';</script>";
    }
    
    // Hapus data
    if(isset($_GET['hapus'])) {
        $conn->query("DELETE FROM data_siswa WHERE id={$_GET['hapus']}");
        echo "<script>alert('Data dihapus!'); window.location='';</script>";
    }
    
    // Ambil data untuk edit
    $edit = null;
    if(isset($_GET['edit'])) {
        $result = $conn->query("SELECT * FROM data_siswa WHERE id={$_GET['edit']}");
        $edit = $result->fetch_assoc();
    }
    
    $total = $conn->query("SELECT COUNT(*) as total FROM data_siswa")->fetch_assoc()['total'];
    ?>
    
    <div class="stats">📊 Total Siswa: <strong><?= $total ?></strong> orang</div>
    
    <form method="POST">
        <input type="hidden" name="id" value="<?= $edit['id'] ?? '' ?>">
        <div class="form-group"><input type="text" name="nis" placeholder="NIS" value="<?= $edit['nis'] ?? '' ?>" required></div>
        <div class="form-group"><input type="text" name="nama" placeholder="Nama" value="<?= $edit['nama'] ?? '' ?>" required></div>
        <div class="form-group"><input type="text" name="rombel" placeholder="Rombel" value="<?= $edit['rombel'] ?? '' ?>" required></div>
        <div class="form-group"><input type="text" name="rayon" placeholder="Rayon" value="<?= $edit['rayon'] ?? '' ?>" required></div>
        <?php if($edit): ?>
            <button type="submit" name="update">Update Data</button>
            <a href="" style="margin-left:10px;">Batal</a>
        <?php else: ?>
            <button type="submit" name="add">Tambah Data</button>
        <?php endif; ?>
    </form>
    
    <h3>Data Siswa:</h3>
    <table>
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
                <a href="?edit=<?= $row['id'] ?>" class="edit">Edit</a>
                <a href="?hapus=<?= $row['id'] ?>" class="delete" onclick="return confirm('Yakin?')">Hapus</a>
            </td>
        </tr>
        <?php endwhile; ?>
    </table>
</div>
</body>
</html>
PHP
    
    # Hapus index.html biar gak konflik
    rm -f /var/www/html/index.html
    
    # Fix permission
    chmod -R 755 /var/www/html/
    chown -R www-data:www-data /var/www/html/
    systemctl restart apache2
    
    echo ""
    echo "=========================================="
    echo "✅ CRUD BERHASIL!"
    echo "🌐 http://$SELECTED_IP"
    echo "=========================================="
    echo ""
}

# 8. WordPress
install_wordpress() {
    echo "[INSTALL] WordPress..."
    pilih_ip
    
    apt update
    apt install -y apache2 php php-mysql php-curl php-gd php-mbstring php-xml php-zip mariadb-server mariadb-client libapache2-mod-php
    
    systemctl start mariadb
    systemctl enable mariadb
    
    DB_PASS=$(openssl rand -base64 12 | tr -d '/' | cut -c1-15)
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
    
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    systemctl restart apache2
    
    echo "✅ WordPress BERHASIL!"
    echo "🌐 http://$SELECTED_IP/wp-admin/install.php"
    echo "🔑 DB Pass: $DB_PASS"
    echo ""
}

# 9. Mail Server
install_mailserver() {
    echo "[INSTALL] Mail Server..."
    pilih_ip
    read -p "Domain email: " MAIL_DOMAIN
    
    apt update && apt install -y bind9 postfix dovecot-imapd dovecot-pop3d mailutils
    
    cat > /etc/bind/named.conf.local << EOF
zone "$MAIL_DOMAIN" {
    type master;
    file "/etc/bind/db.$MAIL_DOMAIN";
};
EOF

    cat > /etc/bind/db.$MAIL_DOMAIN << EOF
\$TTL 604800
@ IN SOA ns.$MAIL_DOMAIN. admin.$MAIL_DOMAIN. (2025010101 604800 86400 2419200 604800)
@ IN NS ns.$MAIL_DOMAIN.
@ IN A $SELECTED_IP
ns IN A $SELECTED_IP
mail IN A $SELECTED_IP
@ IN MX 10 mail.$MAIL_DOMAIN
EOF

    systemctl restart bind9
    
    debconf-set-selections <<< "postfix postfix/mailname string $MAIL_DOMAIN"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    apt install -y postfix
    
    postconf -e "myhostname = mail.$MAIL_DOMAIN"
    postconf -e "mydomain = $MAIL_DOMAIN"
    postconf -e "myorigin = \$mydomain"
    postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
    
    useradd -m admin 2>/dev/null
    echo "admin:wikramamail123" | chpasswd
    
    systemctl restart postfix dovecot
    
    echo "✅ Mail Server BERHASIL!"
    echo "📧 Domain: $MAIL_DOMAIN"
    echo "👤 admin / wikramamail123"
    echo ""
}

# 10. Zabbix
install_zabbix() {
    echo "[INSTALL] Zabbix Server..."
    pilih_ip
    
    apt update && apt install -y wget gnupg2 mariadb-server mariadb-client
    
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
    
    echo "✅ Zabbix BERHASIL!"
    echo "🌐 http://$SELECTED_IP/zabbix"
    echo "👤 Admin / zabbix"
    echo ""
}

# 11. Hapus Semua
hapus_semua() {
    echo "⚠️  HAPUS SEMUA SERVICE?"
    read -p "Ketik 'YA' untuk lanjut: " CONFIRM
    [[ "$CONFIRM" != "YA" ]] && echo "Batal" && return
    
    systemctl stop apache2 mariadb postfix dovecot bind9 isc-dhcp-server vsftpd smbd zabbix-server 2>/dev/null
    apt remove --purge -y apache2 mariadb-server php* postfix dovecot* bind9 isc-dhcp-server vsftpd samba zabbix-server-mysql 2>/dev/null
    apt autoremove -y
    rm -rf /var/www/html/* /etc/bind/* /etc/dhcp/* /srv/samba/* /var/lib/mysql /etc/zabbix 2>/dev/null
    
    echo "✅ Semua service dihapus!"
}

# 12. Install Semua
install_semua() {
    install_apache_landing
    install_dhcp
    install_dns_single
    install_ftp
    install_samba
    install_crud
    install_wordpress
    install_zabbix
    echo "✅ SEMUA SERVICE SELESAI!"
}

# ==================== MENU ====================
while true; do
    banner
    echo "================================================================================"
    echo "  1. Apache2 + Landing Page    7. CRUD Application"
    echo "  2. DHCP Server              8. WordPress CMS"
    echo "  3. DNS Server (Single)      9. Mail Server"
    echo "  4. 3 DNS Server             10. Zabbix Server"
    echo "  5. FTP Server               11. Hapus Semua Service"
    echo "  6. Samba Server             12. Install Semua Service"
    echo "  0. Keluar"
    echo "================================================================================"
    read -p "Pilih [0-12]: " MENU_CHOICE
    
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
        0) echo "Terima kasih!"; exit 0 ;;
        *) echo "Pilihan salah!" ;;
    esac
    
    read -p "Tekan Enter..."
done
