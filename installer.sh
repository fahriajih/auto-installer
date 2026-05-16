#!/bin/bash

# ============================================================
# FAHTECH AUTOMATION - TJKT SMK WIKRAMA
# Super Complete Auto Configuration Script
# Version: 2.0 | Author: Fahtech
# ============================================================

set -e

# Warna Super Kece
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# ASCII Art Banner
banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo -e "║     ${RED}███████╗ █████╗ ██╗  ██╗████████╗███████╗ ██████╗██╗  ██╗${CYAN}     ║"
    echo -e "║     ${RED}██╔════╝██╔══██╗██║  ██║╚══██╔══╝██╔════╝██╔════╝██║  ██║${CYAN}     ║"
    echo -e "║     ${RED}█████╗  ███████║███████║   ██║   █████╗  ██║     ███████║${CYAN}     ║"
    echo -e "║     ${RED}██╔══╝  ██╔══██║██╔══██║   ██║   ██╔══╝  ██║     ██╔══██║${CYAN}     ║"
    echo -e "║     ${RED}██║     ██║  ██║██║  ██║   ██║   ███████╗╚██████╗██║  ██║${CYAN}     ║"
    echo -e "║     ${RED}╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝${CYAN}     ║"
    echo "║                                                                  ║"
    echo -e "║              ${WHITE}TJKT SMK WIKRAMA - AUTO CONFIGURATION${CYAN}                ║"
    echo "║                      ${YELLOW}PILIH NOMOR LAYANAN${CYAN}                          ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Fungsi deteksi IP
get_ips() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
}

# Fungsi pilih IP dengan tampilan keren
pilih_ip() {
    local IP_LIST=($(get_ips))
    if [ ${#IP_LIST[@]} -eq 0 ]; then
        echo -e "${RED}❌ ERROR: Tidak ada IP terdeteksi!${NC}"
        exit 1
    fi
    
    echo -e "${PURPLE}╔════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║      📡 DAFTAR IP YANG TERSEDIA       ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════╝${NC}"
    
    for i in "${!IP_LIST[@]}"; do
        echo -e "${GREEN}  $((i+1)). ${WHITE}${IP_LIST[$i]}${NC}"
    done
    
    echo ""
    read -p "$(echo -e ${YELLOW}"➤ Pilih nomor IP: "${NC})" IP_CHOICE
    
    if [[ ! "$IP_CHOICE" =~ ^[0-9]+$ ]] || [ "$IP_CHOICE" -lt 1 ] || [ "$IP_CHOICE" -gt ${#IP_LIST[@]} ]; then
        echo -e "${RED}❌ Pilihan tidak valid!${NC}"
        exit 1
    fi
    
    SELECTED_IP="${IP_LIST[$((IP_CHOICE-1))]}"
    echo -e "${GREEN}✅ IP terpilih: ${WHITE}$SELECTED_IP${NC}"
    sleep 1
}

# ==================== SERVICE FUNCTIONS ====================

# 1. Apache2 + Landing Page
install_apache_landing() {
    echo -e "${BLUE}🔧 Memulai instalasi Apache2 + Landing Page...${NC}"
    pilih_ip
    apt update && apt install -y apache2
    
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
            font-family: 'Poppins', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            overflow-x: hidden;
        }
        .container {
            background: rgba(255,255,255,0.95);
            border-radius: 30px;
            padding: 50px;
            box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5);
            text-align: center;
            max-width: 800px;
            margin: 20px;
        }
        h1 {
            font-size: 3em;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .feature-card {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            padding: 20px;
            border-radius: 15px;
            color: white;
        }
        .btn {
            display: inline-block;
            padding: 12px 30px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            text-decoration: none;
            border-radius: 25px;
        }
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
        <footer><p>© 2025 TJKT SMK Wikrama</p></footer>
    </div>
</body>
</html>
EOF
    
    systemctl restart apache2
    echo -e "${GREEN}✅ Apache2 + Landing Page SUKSES!${NC}"
    echo -e "${CYAN}🌐 Akses: ${WHITE}http://$SELECTED_IP${NC}"
}

# 2. DHCP Server
install_dhcp() {
    echo -e "${BLUE}🔧 Memulai instalasi DHCP Server...${NC}"
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
    echo -e "${GREEN}✅ DHCP Server SUKSES!${NC}"
    echo -e "${CYAN}📡 Range IP: ${WHITE}${NETWORK%.0}.100 - ${NETWORK%.0}.200${NC}"
}

# 3. Single DNS Server (DENGAN REVERSE DNS)
install_dns_single() {
    echo -e "${BLUE}🔧 Memulai instalasi DNS Server (Forward + Reverse DNS)...${NC}"
    pilih_ip
    read -p "$(echo -e ${YELLOW}"➤ Masukkan domain (contoh: tjkt.wikrama.sch.id): "${NC})" DOMAIN

    apt update && apt install -y bind9

    # Hitung Reverse DNS
    REVERSE_ZONE=$(echo $SELECTED_IP | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
    LAST_OCTET=$(echo $SELECTED_IP | awk -F. '{print $4}')

    # Konfigurasi named.conf.local
    cat > /etc/bind/named.conf.local << EOF
// Forward Zone: $DOMAIN
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.$DOMAIN";
};

// Reverse Zone
zone "$REVERSE_ZONE" {
    type master;
    file "/etc/bind/db.$REVERSE_ZONE";
};
EOF

    # Forward Zone File
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
mail    IN      A       $SELECTED_IP
ftp     IN      A       $SELECTED_IP
EOF

    # Reverse Zone File (db.ip)
    cat > /etc/bind/db.$REVERSE_ZONE << EOF
\$TTL    604800
@       IN      SOA     ns.$DOMAIN. admin.$DOMAIN. (
                  2025010101
                  604800
                  86400
                  2419200
                  604800 )
@       IN      NS      ns.$DOMAIN.
$LAST_OCTET     IN      PTR     $DOMAIN.
$LAST_OCTET     IN      PTR     www.$DOMAIN.
$LAST_OCTET     IN      PTR     mail.$DOMAIN.
EOF

    systemctl restart bind9
    echo -e "${GREEN}✅ DNS Server (Forward + Reverse) SUKSES!${NC}"
    echo -e "${CYAN}🌐 Forward DNS: ${WHITE}$DOMAIN → $SELECTED_IP${NC}"
    echo -e "${CYAN}🔄 Reverse DNS: ${WHITE}$SELECTED_IP → $DOMAIN${NC}"
    echo -e "${YELLOW}📝 Test: nslookup $DOMAIN${NC}"
    echo -e "${YELLOW}📝 Test Reverse: nslookup $SELECTED_IP${NC}"
}

# 4. Triple DNS dengan 3 Domain + Reverse DNS
install_dns_triple() {
    echo -e "${BLUE}🔧 Memulai instalasi 3 DNS Server + Reverse DNS...${NC}"
    pilih_ip

    declare -a DOMAINS
    REVERSE_ZONE=$(echo $SELECTED_IP | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
    LAST_OCTET=$(echo $SELECTED_IP | awk -F. '{print $4}')

    for i in {1..3}; do
        read -p "$(echo -e ${YELLOW}"➤ Masukkan domain ke-$i: "${NC})" DOM
        mkdir -p /var/www/$DOM
        DOMAINS[$i]=$DOM

        RAND_HEX1=$(openssl rand -hex 3)
        RAND_HEX2=$(openssl rand -hex 3)
        cat > /var/www/$DOM/index.html << EOF
<!DOCTYPE html>
<html>
<head><title>$DOM - Fahtech Service</title>
<style>
body {
    background: linear-gradient(135deg, #${RAND_HEX1}, #${RAND_HEX2});
    font-family: Arial;
    text-align: center;
    padding: 50px;
    color: white;
}
</style>
</head>
<body>
<h1>🚀 Selamat datang di $DOM</h1>
<h2>Layanan DNS Ke-$i - TJKT SMK Wikrama</h2>
<p>IP Server: $SELECTED_IP</p>
</body>
</html>
EOF
    done

    apt update && apt install -y bind9 apache2

    # Konfigurasi named.conf.local
    cat > /etc/bind/named.conf.local << EOF
// Reverse Zone
zone "$REVERSE_ZONE" {
    type master;
    file "/etc/bind/db.$REVERSE_ZONE";
};
EOF

    # Tambahkan forward zone untuk tiap domain
    for i in {1..3}; do
        cat >> /etc/bind/named.conf.local << EOF

// Forward Zone: ${DOMAINS[$i]}
zone "${DOMAINS[$i]}" {
    type master;
    file "/etc/bind/db.${DOMAINS[$i]}";
};
EOF

        cat > /etc/bind/db.${DOMAINS[$i]} << EOF
\$TTL    604800
@       IN      SOA     ns.${DOMAINS[$i]}. admin.${DOMAINS[$i]}. (
                  2025010101
                  604800
                  86400
                  2419200
                  604800 )
@       IN      NS      ns.${DOMAINS[$i]}.
@       IN      A       $SELECTED_IP
ns      IN      A       $SELECTED_IP
www     IN      A       $SELECTED_IP
EOF
    done

    # Reverse Zone File
    cat > /etc/bind/db.$REVERSE_ZONE << EOF
\$TTL    604800
@       IN      SOA     ns.${DOMAINS[1]}. admin.${DOMAINS[1]}. (
                  2025010101
                  604800
                  86400
                  2419200
                  604800 )
@       IN      NS      ns.${DOMAINS[1]}.
$LAST_OCTET     IN      PTR     ${DOMAINS[1]}.
$LAST_OCTET     IN      PTR     ${DOMAINS[2]}.
$LAST_OCTET     IN      PTR     ${DOMAINS[3]}.
EOF

    # Konfigurasi Apache
    for i in {1..3}; do
        cat > /etc/apache2/sites-available/${DOMAINS[$i]}.conf << EOF
<VirtualHost *:80>
    ServerName ${DOMAINS[$i]}
    ServerAlias www.${DOMAINS[$i]}
    DocumentRoot /var/www/${DOMAINS[$i]}
</VirtualHost>
EOF
        a2ensite ${DOMAINS[$i]}.conf
    done

    systemctl restart bind9
    systemctl reload apache2

    echo -e "${GREEN}✅ 3 DNS Server + Reverse DNS SUKSES!${NC}"
    for i in {1..3}; do
        echo -e "${CYAN}🌐 Domain $i: ${WHITE}http://${DOMAINS[$i]}${NC}"
    done
    echo -e "${CYAN}🔄 Reverse DNS: ${WHITE}$SELECTED_IP → semua domain${NC}"
}

# 5. FTP Server
install_ftp() {
    echo -e "${BLUE}🔧 Memulai instalasi FTP Server...${NC}"
    pilih_ip
    apt update && apt install -y vsftpd
    
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    
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
    
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    useradd -m -s /bin/bash ftpuser 2>/dev/null || true
    echo "ftpuser:wikrama123" | chpasswd
    
    echo -e "${GREEN}✅ FTP Server SUKSES!${NC}"
    echo -e "${CYAN}📁 Server: ${WHITE}ftp://$SELECTED_IP${NC}"
    echo -e "${YELLOW}📝 User: ftpuser | Pass: wikrama123${NC}"
}

# 6. Samba Server
install_samba() {
    echo -e "${BLUE}🔧 Memulai instalasi Samba Server...${NC}"
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
    
    echo -e "${GREEN}✅ Samba Server SUKSES!${NC}"
    echo -e "${CYAN}📁 Share: ${WHITE}\\\\$SELECTED_IP\\wikrama-share${NC}"
}

# 7. CRUD (PHP + MySQL)
install_crud() {
    echo -e "${BLUE}🔧 Memulai instalasi CRUD Application...${NC}"
    pilih_ip
    apt update && apt install -y apache2 mysql-server php php-mysql libapache2-mod-php
    
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
    
    cat > /var/www/html/crud.php << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CRUD Siswa - TJKT Wikrama</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
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
        h1 { color: #667eea; }
        h2 { color: #764ba2; }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input, select {
            width: 100%;
            padding: 10px;
            border: 2px solid #ddd;
            border-radius: 8px;
        }
        button {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 12px 30px;
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
        .edit { background: #4CAF50; padding: 5px 10px; border-radius: 5px; color: white; text-decoration: none; }
        .delete { background: #f44336; padding: 5px 10px; border-radius: 5px; color: white; text-decoration: none; }
        .success { background: #d4edda; color: #155724; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .error { background: #f8d7da; color: #721c24; padding: 10px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
<div class="container">
    <h1>🚀 TJKT SMK WIKRAMA</h1>
    <h2>📚 Manajemen Data Siswa (CRUD)</h2>
    <?php
    $conn = new mysqli('localhost', 'root', '', 'siswa_wikrama');
    if ($conn->connect_error) die("Koneksi gagal: " . $conn->connect_error);
    
    if(isset($_POST['add'])) {
        $sql = "INSERT INTO data_siswa (nis, nama, rombel, rayon) VALUES ('$_POST[nis]', '$_POST[nama]', '$_POST[rombel]', '$_POST[rayon]')";
        if($conn->query($sql)) echo "<div class='success'>✅ Data berhasil ditambahkan!</div>";
        else echo "<div class='error'>❌ Error: " . $conn->error . "</div>";
    }
    
    if(isset($_POST['update'])) {
        $sql = "UPDATE data_siswa SET nis='$_POST[nis]', nama='$_POST[nama]', rombel='$_POST[rombel]', rayon='$_POST[rayon]' WHERE id=$_POST[id]";
        if($conn->query($sql)) echo "<div class='success'>✅ Data berhasil diupdate!</div>";
        else echo "<div class='error'>❌ Error: " . $conn->error . "</div>";
    }
    
    if(isset($_GET['delete'])) {
        $sql = "DELETE FROM data_siswa WHERE id=$_GET[delete]";
        if($conn->query($sql)) echo "<div class='success'>✅ Data berhasil dihapus!</div>";
        else echo "<div class='error'>❌ Error: " . $conn->error . "</div>";
    }
    
    $edit_data = null;
    if(isset($_GET['edit'])) {
        $result = $conn->query("SELECT * FROM data_siswa WHERE id=$_GET[edit]");
        $edit_data = $result->fetch_assoc();
    }
    ?>
    <form method="POST">
        <input type="hidden" name="id" value="<?php echo $edit_data['id'] ?? ''; ?>">
        <div class="form-group"><label>NIS:</label><input type="text" name="nis" value="<?php echo $edit_data['nis'] ?? ''; ?>" required></div>
        <div class="form-group"><label>Nama:</label><input type="text" name="nama" value="<?php echo $edit_data['nama'] ?? ''; ?>" required></div>
        <div class="form-group"><label>Rombel:</label><input type="text" name="rombel" value="<?php echo $edit_data['rombel'] ?? ''; ?>" required></div>
        <div class="form-group"><label>Rayon:</label><input type="text" name="rayon" value="<?php echo $edit_data['rayon'] ?? ''; ?>" required></div>
        <?php if($edit_data): ?>
            <button type="submit" name="update">🔄 Update</button>
            <a href="crud.php">➕ Tambah Baru</a>
        <?php else: ?>
            <button type="submit" name="add">➕ Tambah</button>
        <?php endif; ?>
    </form>
    <h3>📋 Data Siswa:</h3>
    <table border="1" cellpadding="10" cellspacing="0">
        <tr><th>ID</th><th>NIS</th><th>Nama</th><th>Rombel</th><th>Rayon</th><th>Aksi</th></tr>
        <?php
        $result = $conn->query("SELECT * FROM data_siswa ORDER BY id DESC");
        while($row = $result->fetch_assoc()):
        ?>
        <tr>
            <td><?php echo $row['id']; ?></td>
            <td><?php echo $row['nis']; ?></td>
            <td><?php echo $row['nama']; ?></td>
            <td><?php echo $row['rombel']; ?></td>
            <td><?php echo $row['rayon']; ?></td>
            <td><a href="crud.php?edit=<?php echo $row['id']; ?>" class="edit">✏️ Edit</a> <a href="crud.php?delete=<?php echo $row['id']; ?>" class="delete" onclick="return confirm('Yakin?')">🗑️ Hapus</a></td>
        </tr>
        <?php endwhile; ?>
    </table>
</div>
</body>
</html>
EOF
    
    chmod 755 /var/www/html/crud.php
    systemctl restart apache2
    
    echo -e "${GREEN}✅ CRUD Application SUKSES!${NC}"
    echo -e "${CYAN}🌐 Akses: ${WHITE}http://$SELECTED_IP/crud.php${NC}"
}

# 8. WordPress
install_wordpress() {
    echo -e "${BLUE}🔧 Memulai instalasi WordPress...${NC}"
    pilih_ip
    apt update && apt install -y apache2 mysql-server php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip libapache2-mod-php wget
    
    DB_PASS=$(openssl rand -base64 12)
    mysql << EOF
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    cd /tmp
    wget https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    cp -r wordpress/* /var/www/html/
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    
    sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php
    sed -i "s/password_here/$DB_PASS/" /var/www/html/wp-config.php
    
    chown -R www-data:www-data /var/www/html/
    systemctl restart apache2
    
    echo -e "${GREEN}✅ WordPress SUKSES!${NC}"
    echo -e "${CYAN}🌐 Akses: ${WHITE}http://$SELECTED_IP/wp-admin/install.php${NC}"
    echo -e "${YELLOW}📝 Database: wordpress | User: wpuser | Pass: $DB_PASS${NC}"
}

# 9. Mail Server
install_mailserver() {
    echo -e "${BLUE}🔧 Memulai instalasi Mail Server...${NC}"
    pilih_ip
    read -p "$(echo -e ${YELLOW}"➤ Masukkan domain untuk email: "${NC})" MAIL_DOMAIN
    
    apt update && apt install -y bind9
    
    REVERSE_ZONE=$(echo $SELECTED_IP | awk -F. '{print $3"."$2"."$1".in-addr.arpa"}')
    LAST_OCTET=$(echo $SELECTED_IP | awk -F. '{print $4}')
    
    cat > /etc/bind/named.conf.local << EOF
zone "$MAIL_DOMAIN" {
    type master;
    file "/etc/bind/db.$MAIL_DOMAIN";
};
zone "$REVERSE_ZONE" {
    type master;
    file "/etc/bind/db.$REVERSE_ZONE";
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

    cat > /etc/bind/db.$REVERSE_ZONE << EOF
\$TTL    604800
@       IN      SOA     ns.$MAIL_DOMAIN. admin.$MAIL_DOMAIN. (
                  2025010101
                  604800
                  86400
                  2419200
                  604800 )
@       IN      NS      ns.$MAIL_DOMAIN.
$LAST_OCTET     IN      PTR     mail.$MAIL_DOMAIN.
EOF

    systemctl restart bind9
    
    debconf-set-selections <<< "postfix postfix/mailname string $MAIL_DOMAIN"
    debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
    apt install -y postfix dovecot-imapd dovecot-pop3d mailutils
    
    postconf -e "myhostname = mail.$MAIL_DOMAIN"
    postconf -e "mydomain = $MAIL_DOMAIN"
    postconf -e "myorigin = \$mydomain"
    postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"
    
    sed -i 's/#mail_location = mbox:~/mail/mail_location = mbox:~/mail/' /etc/dovecot/conf.d/10-mail.conf
    
    useradd -m -s /bin/bash admin 2>/dev/null || true
    echo "admin:wikramamail123" | chpasswd
    
    systemctl restart postfix dovecot
    
    echo -e "${GREEN}✅ Mail Server SUKSES!${NC}"
    echo -e "${CYAN}📧 SMTP/IMAP: ${WHITE}$SELECTED_IP${NC}"
    echo -e "${YELLOW}📝 User: admin | Pass: wikramamail123${NC}"
}

# 10. Zabbix Server
install_zabbix() {
    echo -e "${BLUE}🔧 Memulai instalasi Zabbix Server...${NC}"
    pilih_ip
    apt update && apt install -y wget gnupg2 software-properties-common
    
    UBUNTU_VERSION=$(lsb_release -rs)
    
    if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
        wget -O /tmp/zabbix-release.deb https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu24.04_all.deb
    else
        wget -O /tmp/zabbix-release.deb https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-1+ubuntu22.04_all.deb
    fi
    
    dpkg -i /tmp/zabbix-release.deb
    apt update
    
    apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent mysql-server
    
    mysql << EOF
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY 'zabbix123';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbix123 zabbix
    
    sed -i "s/# DBPassword=/DBPassword=zabbix123/" /etc/zabbix/zabbix_server.conf
    systemctl restart zabbix-server zabbix-agent apache2
    systemctl enable zabbix-server zabbix-agent
    
    echo -e "${GREEN}✅ Zabbix Server SUKSES!${NC}"
    echo -e "${CYAN}🌐 Akses: ${WHITE}http://$SELECTED_IP/zabbix${NC}"
    echo -e "${YELLOW}📝 Login: Admin / zabbix${NC}"
}

# 11. Hapus Semua Service
hapus_semua() {
    echo -e "${RED}⚠️  PERINGATAN: Ini akan menghapus SEMUA service!${NC}"
    read -p "Yakin? (ketik 'YA' untuk lanjut): " CONFIRM
    if [ "$CONFIRM" != "YA" ]; then
        echo -e "${YELLOW}❌ Dibatalkan${NC}"
        return
    fi
    
    systemctl stop apache2 mysql postfix dovecot bind9 isc-dhcp-server vsftpd smbd zabbix-server 2>/dev/null || true
    apt remove --purge -y apache2 mysql-server php* postfix dovecot* bind9 isc-dhcp-server vsftpd samba zabbix-server-mysql zabbix-frontend-php 2>/dev/null || true
    apt autoremove -y
    rm -rf /var/www/html/* /etc/bind/* /etc/dhcp/* /srv/samba/* /var/lib/mysql /etc/zabbix 2>/dev/null || true
    
    echo -e "${GREEN}✅ Semua service telah dihapus!${NC}"
}

# 12. Install Semua Service Sekaligus
install_semua() {
    echo -e "${BLUE}🚀 Memulai instalasi SEMUA service...${NC}"
    install_apache_landing
    install_dhcp
    install_dns_single
    install_ftp
    install_samba
    install_crud
    install_wordpress
    install_zabbix
    echo -e "${GREEN}✅ SEMUA service berhasil diinstall!${NC}"
}

# ==================== MAIN MENU ====================
while true; do
    banner
    echo ""
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                         DAFTAR LAYANAN                           ║${NC}"
    echo -e "${WHITE}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${WHITE}║  ${GREEN}1.${WHITE}  Apache2 + Landing Page TJKT                            ║${NC}"
    echo -e "${WHITE}║  ${GREEN}2.${WHITE}  DHCP Server (Range 100-200)                          ║${NC}"
    echo -e "${WHITE}║  ${GREEN}3.${WHITE}  DNS Server Single + Reverse DNS                      ║${NC}"
    echo -e "${WHITE}║  ${GREEN}4.${WHITE}  3 DNS Server + Reverse DNS (3 Domain Berbeda)        ║${NC}"
    echo -e "${WHITE}║  ${GREEN}5.${WHITE}  FTP Server                                           ║${NC}"
    echo -e "${WHITE}║  ${GREEN}6.${WHITE}  Samba Server (SMB Share)                             ║${NC}"
    echo -e "${WHITE}║  ${GREEN}7.${WHITE}  CRUD Application (Data Siswa)                        ║${NC}"
    echo -e "${WHITE}║  ${GREEN}8.${WHITE}  WordPress CMS                                        ║${NC}"
    echo -e "${WHITE}║  ${GREEN}9.${WHITE}  Mail Server (Postfix + Dovecot + DNS)                ║${NC}"
    echo -e "${WHITE}║  ${GREEN}10.${WHITE} Zabbix Server Monitoring                             ║${NC}"
    echo -e "${WHITE}║  ${GREEN}11.${WHITE} Hapus Semua Service                                  ║${NC}"
    echo -e "${WHITE}║  ${GREEN}12.${WHITE} Install Semua Service Sekaligus                      ║${NC}"
    echo -e "${WHITE}║  ${RED}0.${WHITE}  Keluar                                               ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -ne "${CYAN}➤ Pilih nomor [0-12]: ${NC}"
    read MENU_CHOICE
    
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
        0) echo -e "${GREEN}👋 Terima kasih - Fahtech Automation${NC}"; exit 0 ;;
        *) echo -e "${RED}❌ Pilihan salah! Silakan pilih 0-12${NC}"; sleep 2 ;;
    esac
    
    echo ""
    echo -ne "${YELLOW}Tekan Enter untuk kembali ke menu...${NC}"
    read
done
