#!/bin/bash

# ======================================================
# FULL INSTALLER - FAHRITECH SMK WIKRAMA
# ======================================================
# Fitur Lengkap:
# 1. Setting IP (BEBAS)
# 2. DHCP Server (Range 100-200)
# 3. DNS Server (Bind9)
# 4. Apache2 + PHP
# 5. MySQL / MariaDB
# 6. WordPress
# 7. phpMyAdmin
# 8. CRUD Siswa (Nama, NIS, Rombel) - FULL FUNCTIONAL
# 9. SSH Server
# 10. Samba File Sharing
# 11. DVWA
# 12. Website Utama SMK Wikrama (Tampilan Super Keren)
# ======================================================

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Variabel global
INTERFACE=""
IP_ADDR=""
GATEWAY=""
DOMAIN=""
DNS_IP=""

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Script ini harus dijalankan sebagai root!${NC}"
   exit 1
fi

# =================== TAMPILAN AWAL ===================
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                          ║"
    echo "║   ███████╗ █████╗ ██╗  ██╗██████╗ ██╗████████╗███████╗ ██████╗██╗  ██╗   ║"
    echo "║   ██╔════╝██╔══██╗██║  ██║██╔══██╗██║╚══██╔══╝██╔════╝██╔════╝██║  ██║   ║"
    echo "║   █████╗  ███████║███████║██████╔╝██║   ██║   █████╗  ██║     ███████║   ║"
    echo "║   ██╔══╝  ██╔══██║██╔══██║██╔══██╗██║   ██║   ██╔══╝  ██║     ██╔══██║   ║"
    echo "║   ██║     ██║  ██║██║  ██║██║  ██║██║   ██║   ███████╗╚██████╗██║  ██║   ║"
    echo "║   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝   ║"
    echo "║                                                                          ║"
    echo "║              🚀 FULL AUTO INSTALLER SERVER LINUX 🚀                       ║"
    echo "║                      SMK WIKRAMA - TUTORIAL                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    sleep 1
}

# =================== VALIDASI IP ===================
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi
    return 1
}

# =================== MENU 1: SETTING IP ===================
menu_set_ip() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    1. SETTING IP ADDRESS                        ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    interfaces=($(ip link show | grep -E '^[0-9]+: ens|eth' | awk -F': ' '{print $2}'))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}Tidak ada interface yang terdeteksi!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Pilih interface yang mau dipakai:${NC}"
    for i in "${!interfaces[@]}"; do
        echo "  ${CYAN}$((i+1)))${NC} ${interfaces[$i]}"
    done
    echo ""
    read -p "Masukkan pilihan [1-${#interfaces[@]}]: " pilih_interface
    
    if [[ $pilih_interface -ge 1 && $pilih_interface -le ${#interfaces[@]} ]]; then
        INTERFACE="${interfaces[$((pilih_interface-1))]}"
    else
        echo -e "${RED}Pilihan tidak valid!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}📌 CONTOH IP VALID:${NC}"
    echo "   192.168.1.10     192.168.27.50     10.10.10.5"
    echo -e "${GREEN}   (BEBAS, tidak ada batasan!)${NC}"
    echo ""
    
    while true; do
        read -p "Masukkan IP address untuk $INTERFACE: " IP_ADDR
        if validate_ip "$IP_ADDR"; then
            break
        else
            echo -e "${RED}❌ Format IP tidak valid! Contoh: 192.168.1.10${NC}"
        fi
    done
    
    subnet=$(echo $IP_ADDR | cut -d'.' -f1-3)
    GATEWAY="${subnet}.1"
    
    cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      addresses:
        - $IP_ADDR/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
    
    netplan apply
    echo ""
    echo -e "${GREEN}✅ IP Address $IP_ADDR berhasil diset ke $INTERFACE${NC}"
    echo -e "${GREEN}✅ Netmask: 255.255.255.0${NC}"
    echo -e "${GREEN}✅ Gateway: $GATEWAY${NC}"
}

# =================== MENU 2: DHCP SERVER ===================
menu_set_dhcp() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    2. SETUP DHCP SERVER                         ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    interfaces=($(ip link show | grep -E '^[0-9]+: ens|eth' | awk -F': ' '{print $2}'))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}Tidak ada interface yang terdeteksi!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Pilih interface untuk DHCP Server:${NC}"
    for i in "${!interfaces[@]}"; do
        ip_check=$(ip addr show ${interfaces[$i]} 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ -n "$ip_check" ]; then
            echo "  ${CYAN}$((i+1)))${NC} ${interfaces[$i]} [IP: $ip_check]"
        else
            echo "  ${CYAN}$((i+1)))${NC} ${interfaces[$i]} [belum ada IP]"
        fi
    done
    echo ""
    read -p "Masukkan pilihan [1-${#interfaces[@]}]: " pilih_dhcp
    
    if [[ $pilih_dhcp -ge 1 && $pilih_dhcp -le ${#interfaces[@]} ]]; then
        DHCP_INTERFACE="${interfaces[$((pilih_dhcp-1))]}"
    else
        echo -e "${RED}Pilihan tidak valid!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}⚙️  Menginstall DHCP Server...${NC}"
    apt update -qq
    apt install isc-dhcp-server -y
    
    if [ -z "$IP_ADDR" ]; then
        IP_ADDR=$(ip addr show $DHCP_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        subnet=$(echo $IP_ADDR | cut -d'.' -f1-3)
        GATEWAY="${subnet}.1"
    else
        subnet=$(echo $IP_ADDR | cut -d'.' -f1-3)
    fi
    
    cat > /etc/dhcp/dhcpd.conf <<EOF
subnet ${subnet}.0 netmask 255.255.255.0 {
    range ${subnet}.100 ${subnet}.200;
    option routers $GATEWAY;
    option domain-name-servers $IP_ADDR, 8.8.8.8;
}
EOF
    
    sed -i "s/INTERFACESv4=\".*\"/INTERFACESv4=\"$DHCP_INTERFACE\"/" /etc/default/isc-dhcp-server
    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server
    
    echo ""
    echo -e "${GREEN}✅ DHCP Server berhasil diinstall${NC}"
    echo -e "${GREEN}✅ Interface: $DHCP_INTERFACE${NC}"
    echo -e "${GREEN}✅ Range IP: ${subnet}.100 - ${subnet}.200${NC}"
    echo -e "${YELLOW}📌 IP Server Anda: $IP_ADDR (BEBAS, tidak dalam range DHCP)${NC}"
}

# =================== MENU 3: DNS SERVER ===================
menu_set_dns() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    3. SETUP DNS SERVER                          ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    echo ""
    echo -e "${YELLOW}📌 CONTOH DOMAIN: smkwikrama.local${NC}"
    echo -e "${YELLOW}📌 CONTOH IP DOMAIN: $IP_ADDR${NC}"
    echo ""
    read -p "Masukkan nama domain: " DOMAIN
    read -p "Masukkan IP untuk domain $DOMAIN: " DNS_IP
    
    echo ""
    echo -e "${YELLOW}⚙️  Menginstall DNS Server...${NC}"
    apt install bind9 -y
    
    cat > /etc/bind/db.$DOMAIN <<EOF
;
; BIND data file for $DOMAIN
;
\$TTL    604800
@       IN      SOA     $DOMAIN. admin.$DOMAIN. (
                  2         ; Serial
             604800         ; Refresh
              86400         ; Retry
            2419200         ; Expire
             604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
@       IN      A       $DNS_IP
ns1     IN      A       $DNS_IP
www     IN      A       $DNS_IP
EOF
    
    reverse_ip=$(echo $DNS_IP | awk -F '.' '{print $3"."$2"."$1}')
    last_octet=$(echo $DNS_IP | awk -F '.' '{print $4}')
    cat > /etc/bind/db.$reverse_ip <<EOF
;
; BIND reverse data file for $reverse_ip
;
\$TTL    604800
@       IN      SOA     $DOMAIN. admin.$DOMAIN. (
                  2         ; Serial
             604800         ; Refresh
              86400         ; Retry
            2419200         ; Expire
             604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
$last_octet     IN      PTR     $DOMAIN.
$last_octet     IN      PTR     www.$DOMAIN.
EOF
    
    cat >> /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" {
    type master;
    file "/etc/bind/db.$DOMAIN";
};
zone "$reverse_ip.in-addr.arpa" {
    type master;
    file "/etc/bind/db.$reverse_ip";
};
EOF
    
    apt install resolvconf -y
    echo "nameserver $DNS_IP" > /etc/resolvconf/resolv.conf.d/head
    systemctl restart resolvconf
    systemctl restart bind9
    
    echo ""
    echo -e "${GREEN}✅ DNS Server berhasil diinstall${NC}"
    echo -e "${GREEN}✅ Domain: $DOMAIN -> $DNS_IP${NC}"
}

# =================== MENU 4: APACHE2 + PHP ===================
menu_set_apache() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    4. INSTALL APACHE2 & PHP                     ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Menginstall Apache2 dan PHP...${NC}"
    apt install apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y
    systemctl enable apache2
    systemctl restart apache2
    
    echo -e "${GREEN}✅ Apache2 & PHP berhasil diinstall${NC}"
}

# =================== MENU 5: MYSQL ===================
menu_set_mysql() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    5. INSTALL MYSQL                             ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Menginstall MySQL/MariaDB...${NC}"
    apt install mariadb-server -y
    
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpass123';" 2>/dev/null
    mysql -u root -prootpass123 -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    echo -e "${GREEN}✅ MySQL berhasil diinstall${NC}"
    echo -e "${YELLOW}🔑 Password root MySQL: rootpass123${NC}"
}

# =================== MENU 6: WORDPRESS ===================
menu_set_wordpress() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    6. INSTALL WORDPRESS                        ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Setup database WordPress...${NC}"
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS wordpress;" 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY 'wppass123';" 2>/dev/null
    mysql -u root -prootpass123 -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';" 2>/dev/null
    mysql -u root -prootpass123 -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    echo -e "${YELLOW}⚙️  Download WordPress...${NC}"
    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    cp -r wordpress/* /var/www/html/
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php 2>/dev/null
    
    sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php
    sed -i "s/password_here/wppass123/" /var/www/html/wp-config.php
    chown -R www-data:www-data /var/www/html/
    systemctl restart apache2
    
    domain_web=${DOMAIN:-$IP_ADDR}
    echo ""
    echo -e "${GREEN}✅ WordPress berhasil diinstall${NC}"
    echo -e "${GREEN}✅ Akses: http://${domain_web}/wp-admin${NC}"
}

# =================== MENU 7: phpMyAdmin ===================
menu_set_phpmyadmin() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    7. INSTALL phpMyAdmin                       ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Menginstall phpMyAdmin...${NC}"
    
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password rootpass123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password rootpass123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password rootpass123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    
    apt install phpmyadmin -y
    systemctl restart apache2
    
    domain_web=${DOMAIN:-$IP_ADDR}
    echo ""
    echo -e "${GREEN}✅ phpMyAdmin berhasil diinstall${NC}"
    echo -e "${GREEN}✅ Akses: http://${domain_web}/phpmyadmin${NC}"
    echo -e "${YELLOW}🔑 Login: root / rootpass123${NC}"
}

# =================== MENU 8: WEBSITE UTAMA & CRUD ===================
menu_set_website() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    8. WEBSITE UTAMA & CRUD                     ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    echo ""
    echo -e "${YELLOW}🌐 Membuat Website Utama SMK Wikrama...${NC}"
    
    # Website Utama
    cat > /var/www/html/index.php << 'EOF_MAIN'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SMK Wikrama - Web Tutorial Server</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Poppins', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .navbar {
            background: rgba(255,255,255,0.98);
            backdrop-filter: blur(10px);
            padding: 15px 50px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            box-shadow: 0 2px 20px rgba(0,0,0,0.1);
            position: sticky;
            top: 0;
            z-index: 1000;
        }
        .logo h1 {
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-size: 28px;
        }
        .nav-links {
            display: flex;
            gap: 30px;
            flex-wrap: wrap;
        }
        .nav-links a {
            text-decoration: none;
            color: #333;
            font-weight: 500;
            transition: 0.3s;
            padding: 8px 15px;
            border-radius: 25px;
        }
        .nav-links a:hover {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
        }
        .hero {
            text-align: center;
            padding: 100px 20px;
            color: white;
        }
        .hero h1 {
            font-size: 3.5rem;
            margin-bottom: 20px;
            animation: fadeInUp 0.8s ease;
        }
        .hero p {
            font-size: 1.2rem;
            margin-bottom: 30px;
            opacity: 0.9;
        }
        .btn-hero {
            display: inline-block;
            padding: 15px 40px;
            background: white;
            color: #667eea;
            text-decoration: none;
            border-radius: 50px;
            font-weight: 600;
            transition: 0.3s;
            box-shadow: 0 5px 20px rgba(0,0,0,0.2);
        }
        .btn-hero:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        .features {
            background: white;
            padding: 60px 40px;
        }
        .features h2 {
            text-align: center;
            font-size: 2rem;
            color: #333;
            margin-bottom: 50px;
        }
        .feature-grid {
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
            gap: 30px;
            max-width: 1200px;
            margin: 0 auto;
        }
        .feature-card {
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            padding: 30px;
            border-radius: 20px;
            text-align: center;
            width: 250px;
            transition: 0.3s;
            cursor: pointer;
        }
        .feature-card:hover {
            transform: translateY(-10px);
            box-shadow: 0 20px 40px rgba(0,0,0,0.2);
        }
        .feature-card i {
            font-size: 50px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 15px;
        }
        .feature-card h3 {
            margin-bottom: 10px;
            color: #333;
        }
        .feature-card p {
            color: #666;
            font-size: 14px;
        }
        .footer {
            background: #1a1a2e;
            color: white;
            text-align: center;
            padding: 30px;
        }
        @keyframes fadeInUp {
            from { opacity: 0; transform: translateY(30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        @media (max-width: 768px) {
            .navbar { flex-direction: column; gap: 15px; padding: 15px 20px; }
            .hero h1 { font-size: 2rem; }
        }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="logo"><h1><i class="fas fa-laptop-code"></i> SMK Wikrama</h1></div>
        <div class="nav-links">
            <a href="index.php"><i class="fas fa-home"></i> Home</a>
            <a href="crud_siswa.php"><i class="fas fa-users"></i> CRUD Siswa</a>
            <a href="wp-admin"><i class="fab fa-wordpress"></i> WordPress</a>
            <a href="phpmyadmin"><i class="fas fa-database"></i> phpMyAdmin</a>
            <a href="setup.php"><i class="fas fa-shield-alt"></i> DVWA</a>
        </div>
    </div>
    <div class="hero">
        <h1>Selamat Datang di Web Tutorial</h1>
        <p>SMK Wikrama - Belajar Server dan Web Development</p>
        <a href="#features" class="btn-hero"><i class="fas fa-rocket"></i> Mulai Belajar</a>
    </div>
    <div class="features" id="features">
        <h2><i class="fas fa-star"></i> Fitur Unggulan</h2>
        <div class="feature-grid">
            <div class="feature-card" onclick="location.href='crud_siswa.php'">
                <i class="fas fa-database"></i>
                <h3>CRUD Siswa</h3>
                <p>Kelola data siswa (Nama, NIS, Rombel) dengan mudah</p>
            </div>
            <div class="feature-card" onclick="location.href='wp-admin'">
                <i class="fab fa-wordpress"></i>
                <h3>WordPress</h3>
                <p>Blog CMS terpopuler di dunia</p>
            </div>
            <div class="feature-card" onclick="location.href='phpmyadmin'">
                <i class="fas fa-server"></i>
                <h3>phpMyAdmin</h3>
                <p>Manajemen database MySQL</p>
            </div>
            <div class="feature-card" onclick="location.href='setup.php'">
                <i class="fas fa-shield-alt"></i>
                <h3>DVWA</h3>
                <p>Belajar keamanan web</p>
            </div>
        </div>
    </div>
    <div class="footer">
        <p><i class="fas fa-code"></i> SMK Wikrama - Web Tutorial Server | 2025</p>
        <p style="font-size: 12px; margin-top: 10px;">Powered by FAHRITECH</p>
    </div>
</body>
</html>
EOF_MAIN

    # Database CRUD
    echo -e "${YELLOW}📦 Membuat database CRUD...${NC}"
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS sekolah;" 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE TABLE IF NOT EXISTS sekolah.siswa (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nama VARCHAR(100) NOT NULL,
        nis VARCHAR(20) NOT NULL UNIQUE,
        rombel VARCHAR(50) NOT NULL
    );" 2>/dev/null

    # File CRUD
    cat > /var/www/html/crud_siswa.php << 'EOF_CRUD'
<?php
$conn = new mysqli("localhost", "root", "rootpass123", "sekolah");
if ($conn->connect_error) die("Koneksi gagal: " . $conn->connect_error);

$message = '';
$message_type = '';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    if (isset($_POST['action'])) {
        $action = $_POST['action'];
        
        if ($action == 'add') {
            $nama = $conn->real_escape_string($_POST['nama']);
            $nis = $conn->real_escape_string($_POST['nis']);
            $rombel = $conn->real_escape_string($_POST['rombel']);
            
            $check = $conn->query("SELECT id FROM siswa WHERE nis='$nis'");
            if ($check->num_rows > 0) {
                $message = "NIS sudah terdaftar!";
                $message_type = "error";
            } else {
                if ($conn->query("INSERT INTO siswa (nama, nis, rombel) VALUES ('$nama', '$nis', '$rombel')")) {
                    $message = "Data berhasil ditambahkan!";
                    $message_type = "success";
                }
            }
        }
        elseif ($action == 'edit') {
            $id = intval($_POST['id']);
            $nama = $conn->real_escape_string($_POST['nama']);
            $nis = $conn->real_escape_string($_POST['nis']);
            $rombel = $conn->real_escape_string($_POST['rombel']);
            
            $check = $conn->query("SELECT id FROM siswa WHERE nis='$nis' AND id != $id");
            if ($check->num_rows > 0) {
                $message = "NIS sudah digunakan siswa lain!";
                $message_type = "error";
            } else {
                if ($conn->query("UPDATE siswa SET nama='$nama', nis='$nis', rombel='$rombel' WHERE id=$id")) {
                    $message = "Data berhasil diupdate!";
                    $message_type = "success";
                }
            }
        }
        elseif ($action == 'delete') {
            $id = intval($_POST['id']);
            if ($conn->query("DELETE FROM siswa WHERE id=$id")) {
                $message = "Data berhasil dihapus!";
                $message_type = "success";
            }
        }
    }
}

$edit_data = null;
if (isset($_GET['edit'])) {
    $id = intval($_GET['edit']);
    $result = $conn->query("SELECT * FROM siswa WHERE id=$id");
    $edit_data = $result->fetch_assoc();
}
$siswa = $conn->query("SELECT * FROM siswa ORDER BY id DESC");
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRUD Siswa - SMK Wikrama</title>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Poppins', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 40px 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .header h1 { font-size: 2.5rem; color: white; text-shadow: 2px 2px 4px rgba(0,0,0,0.2); }
        .header h1 i { margin-right: 15px; }
        .header p { color: rgba(255,255,255,0.9); margin-top: 10px; }
        .card {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
            margin-bottom: 30px;
        }
        .card-header {
            background: linear-gradient(135deg, #667eea, #764ba2);
            padding: 20px 30px;
            color: white;
        }
        .card-header h2 { font-size: 1.5rem; }
        .card-header h2 i { margin-right: 10px; }
        .card-body { padding: 30px; }
        .form-group { margin-bottom: 20px; }
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #333;
        }
        .form-group label i { margin-right: 8px; color: #667eea; }
        .form-group input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 14px;
            transition: all 0.3s;
            font-family: 'Poppins', sans-serif;
        }
        .form-group input:focus {
            outline: none;
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102,126,234,0.1);
        }
        .btn {
            padding: 12px 25px;
            border: none;
            border-radius: 10px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            font-family: 'Poppins', sans-serif;
        }
        .btn-primary {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
        }
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102,126,234,0.4);
        }
        .btn-edit {
            background: #ffc107;
            color: #333;
            padding: 6px 12px;
            border-radius: 8px;
            text-decoration: none;
            font-size: 12px;
        }
        .btn-edit:hover { background: #ffb300; }
        .btn-delete {
            background: #dc3545;
            color: white;
            padding: 6px 12px;
            border-radius: 8px;
            border: none;
            cursor: pointer;
            font-size: 12px;
        }
        .btn-delete:hover { background: #c82333; }
        .btn-cancel {
            background: #6c757d;
            color: white;
        }
        .btn-cancel:hover { background: #5a6268; }
        .alert {
            padding: 15px 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            animation: slideIn 0.3s ease;
        }
        .alert.success { background: #d4edda; color: #155724; border-left: 4px solid #28a745; }
        .alert.error { background: #f8d7da; color: #721c24; border-left: 4px solid #dc3545; }
        @keyframes slideIn {
            from { transform: translateY(-20px); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
        .table-wrapper { overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; }
        table thead tr { background: linear-gradient(135deg, #667eea, #764ba2); color: white; }
        table th { padding: 15px; text-align: left; font-weight: 500; }
        table td { padding: 15px; border-bottom: 1px solid #e0e0e0; }
        table tbody tr:hover { background: #f8f9fa; }
        .action-buttons { display: flex; gap: 10px; align-items: center; }
        .modal {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.5);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 1000;
        }
        .modal-content {
            background: white;
            border-radius: 20px;
            max-width: 500px;
            width: 90%;
            animation: modalSlideIn 0.3s ease;
        }
        @keyframes modalSlideIn {
            from { transform: translateY(-50px); opacity: 0; }
            to { transform: translateY(0); opacity: 1; }
        }
        .modal-header {
            padding: 20px 25px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border-radius: 20px 20px 0 0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .modal-header h3 { font-size: 1.3rem; }
        .modal-header .close {
            font-size: 28px;
            cursor: pointer;
            background: none;
            border: none;
            color: white;
            text-decoration: none;
        }
        .modal-body { padding: 25px; }
        .modal-actions { display: flex; gap: 15px; margin-top: 20px; }
        .empty-state { text-align: center; padding: 60px; color: #999; }
        .empty-state i { font-size: 60px; margin-bottom: 20px; color: #ddd; }
        .footer { text-align: center; margin-top: 30px; color: rgba(255,255,255,0.7); font-size: 14px; }
        .badge {
            display: inline-block;
            padding: 4px 10px;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            border-radius: 20px;
            font-size: 11px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-users"></i> Manajemen Data Siswa</h1>
            <p>SMK Wikrama - Sistem CRUD Nama, NIS, dan Rombel</p>
            <p><span class="badge"><i class="fas fa-check-circle"></i> Full Functional</span></p>
        </div>
        
        <div class="card">
            <div class="card-header"><h2><i class="fas fa-plus-circle"></i> Tambah Data Siswa</h2></div>
            <div class="card-body">
                <?php if($message): ?>
                <div class="alert <?php echo $message_type; ?>">
                    <i class="fas <?php echo $message_type == 'success' ? 'fa-check-circle' : 'fa-exclamation-circle'; ?>"></i>
                    <?php echo $message; ?>
                </div>
                <?php endif; ?>
                <form method="POST" action="">
                    <div class="form-group">
                        <label><i class="fas fa-user"></i> Nama Lengkap</label>
                        <input type="text" name="nama" placeholder="Masukkan nama siswa" required>
                    </div>
                    <div class="form-group">
                        <label><i class="fas fa-id-card"></i> NIS</label>
                        <input type="text" name="nis" placeholder="Masukkan NIS" required>
                    </div>
                    <div class="form-group">
                        <label><i class="fas fa-graduation-cap"></i> Rombel</label>
                        <input type="text" name="rombel" placeholder="Contoh: XI RPL 1" required>
                    </div>
                    <button type="submit" name="action" value="add" class="btn btn-primary">
                        <i class="fas fa-save"></i> Simpan Data
                    </button>
                </form>
            </div>
        </div>
        
        <div class="card">
            <div class="card-header"><h2><i class="fas fa-list"></i> Daftar Siswa</h2></div>
            <div class="card-body">
                <div class="table-wrapper">
                    <?php if ($siswa->num_rows > 0): ?>
                    <table>
                        <thead><tr><th>No</th><th>Nama</th><th>NIS</th><th>Rombel</th><th>Aksi</th></tr></thead>
                        <tbody>
                            <?php $no = 1; while($row = $siswa->fetch_assoc()): ?>
                            <tr>
                                <td><?php echo $no++; ?></td>
                                <td><strong><?php echo htmlspecialchars($row['nama']); ?></strong></td>
                                <td><?php echo htmlspecialchars($row['nis']); ?></td>
                                <td><?php echo htmlspecialchars($row['rombel']); ?></td>
                                <td class="action-buttons">
                                    <a href="?edit=<?php echo $row['id']; ?>" class="btn-edit"><i class="fas fa-edit"></i> Edit</a>
                                    <form method="POST" action="" style="display:inline;" onsubmit="return confirm('Yakin ingin menghapus data <?php echo addslashes($row['nama']); ?>?')">
                                        <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                        <button type="submit" name="action" value="delete" class="btn-delete"><i class="fas fa-trash"></i> Hapus</button>
                                    </form>
                                </td>
                            </tr>
                            <?php endwhile; ?>
                        </tbody>
                    </table>
                    <?php else: ?>
                    <div class="empty-state">
                        <i class="fas fa-folder-open"></i>
                        <p>Belum ada data siswa</p>
                        <p style="font-size: 12px;">Silakan tambah data siswa melalui form di atas</p>
                    </div>
                    <?php endif; ?>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p><i class="fas fa-code"></i> SMK Wikrama - Sistem Informasi Siswa | <?php echo date('Y'); ?></p>
            <p style="font-size: 12px;">✅ Fitur: Tambah | Edit | Hapus | Cancel</p>
        </div>
    </div>
    
    <?php if ($edit_data): ?>
    <div class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h3><i class="fas fa-edit"></i> Edit Data Siswa</h3>
                <a href="crud_siswa.php" class="close">&times;</a>
            </div>
            <div class="modal-body">
                <form method="POST" action="">
                    <input type="hidden" name="id" value="<?php echo $edit_data['id']; ?>">
                    <div class="form-group">
                        <label><i class="fas fa-user"></i> Nama Lengkap</label>
                        <input type="text" name="nama" value="<?php echo htmlspecialchars($edit_data['nama']); ?>" required>
                    </div>
                    <div class="form-group">
                        <label><i class="fas fa-id-card"></i> NIS</label>
                        <input type="text" name="nis" value="<?php echo htmlspecialchars($edit_data['nis']); ?>" required>
                    </div>
                    <div class="form-group">
                        <label><i class="fas fa-graduation-cap"></i> Rombel</label>
                        <input type="text" name="rombel" value="<?php echo htmlspecialchars($edit_data['rombel']); ?>" required>
                    </div>
                    <div class="modal-actions">
                        <button type="submit" name="action" value="edit" class="btn btn-primary"><i class="fas fa-save"></i> Update Data</button>
                        <a href="crud_siswa.php"><button type="button" class="btn btn-cancel"><i class="fas fa-times"></i> Batal</button></a>
                    </div>
                </form>
            </div>
        </div>
    </div>
    <?php endif; ?>
    
    <script>
        setTimeout(function() {
            var alerts = document.querySelectorAll('.alert');
            alerts.forEach(function(alert) { alert.style.display = 'none'; });
        }, 3000);
    </script>
</body>
</html>
EOF_CRUD

    echo ""
    echo -e "${GREEN}✅ Website Utama dan CRUD berhasil dibuat!${NC}"
}

# =================== MENU 9: SSH & SAMBA ===================
menu_set_samba() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    9. SETUP SSH & SAMBA                         ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Menginstall SSH dan Samba...${NC}"
    
    apt install openssh-server samba -y
    systemctl enable ssh
    systemctl start ssh
    
    mkdir -p /srv/samba/share
    chmod 777 /srv/samba/share
    
    cat >> /etc/samba/smb.conf <<EOF

[wikrama-share]
   path = /srv/samba/share
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
   create mask = 0777
   directory mask = 0777
EOF
    
    systemctl restart smbd
    
    echo ""
    echo -e "${GREEN}✅ SSH Server aktif${NC}"
    echo -e "${GREEN}✅ Remote: ssh root@$IP_ADDR${NC}"
    echo -e "${GREEN}✅ Samba Share: \\\\$IP_ADDR\\wikrama-share${NC}"
}

# =================== MENU 10: DVWA ===================
menu_set_dvwa() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    10. INSTALL DVWA                            ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Clone DVWA dari GitHub...${NC}"
    
    apt install git -y
    
    cd /tmp
    rm -rf DVWA
    git clone https://github.com/digininja/DVWA.git
    cp -r DVWA/* /var/www/html/
    
    cp /var/www/html/config/config.inc.php.dist /var/www/html/config/config.inc.php 2>/dev/null
    sed -i "s/p@ssw0rd/rootpass123/g" /var/www/html/config/config.inc.php 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS dvwa;" 2>/dev/null
    
    chown -R www-data:www-data /var/www/html/
    chmod 777 /var/www/html/hackable/uploads/
    systemctl restart apache2
    
    domain_web=${DOMAIN:-$IP_ADDR}
    echo ""
    echo -e "${GREEN}✅ DVWA berhasil diinstall${NC}"
    echo -e "${GREEN}✅ Akses: http://${domain_web}/setup.php${NC}"
    echo -e "${YELLOW}🔑 Login: admin / password${NC}"
}

# =================== MENU 11: TEST DNS ===================
menu_test_dns() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    11. TEST NSLOOKUP                           ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}❌ Anda harus setting DNS dulu (Menu 3)!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${YELLOW}📌 Testing nslookup...${NC}"
    echo -e "${GREEN}nslookup $DOMAIN:${NC}"
    nslookup $DOMAIN $DNS_IP 2>/dev/null || echo -e "${RED}Gagal${NC}"
    
    echo ""
    echo -e "${GREEN}nslookup www.$DOMAIN:${NC}"
    nslookup www.$DOMAIN $DNS_IP 2>/dev/null || echo -e "${RED}Gagal${NC}"
}

# =================== MENU 12: INSTALL SEMUA ===================
menu_install_all() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}              INSTALL SEMUA FITUR SEKALIGUS                     ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    
    menu_set_ip || return 1
    menu_set_dhcp || return 1
    menu_set_dns || return 1
    menu_set_apache || return 1
    menu_set_mysql || return 1
    menu_set_wordpress || return 1
    menu_set_phpmyadmin || return 1
    menu_set_website || return 1
    menu_set_samba || return 1
    menu_set_dvwa || return 1
    
    # Restart semua service
    systemctl restart apache2
    systemctl restart mysql
    
    # Tampilkan hasil
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                          ║"
    echo "║              ✅ SEMUA FITUR BERHASIL DIINSTALL! ✅                        ║"
    echo "║                                                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}🌐 AKSES WEB SERVER:${NC}"
    echo "   ┌─────────────────────────────────────────────────────────────────────────┐"
    echo "   │  🔥 Website Utama    : http://$IP_ADDR/                                 │"
    echo "   │  📋 CRUD Siswa       : http://$IP_ADDR/crud_siswa.php                   │"
    echo "   │  📝 WordPress        : http://$IP_ADDR/wp-admin                         │"
    echo "   │  🗄️  phpMyAdmin       : http://$IP_ADDR/phpmyadmin                       │"
    echo "   │  🔐 DVWA             : http://$IP_ADDR/setup.php                         │"
    echo "   └─────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "${YELLOW}🔑 LOGIN INFORMATION:${NC}"
    echo "   ┌─────────────────────────────────────────────────────────────────────────┐"
    echo "   │  phpMyAdmin : root / rootpass123                                         │"
    echo "   │  WordPress  : (isi sendiri saat install pertama)                         │"
    echo "   │  DVWA       : admin / password                                           │"
    echo "   │  MySQL      : root / rootpass123                                         │"
    echo "   └─────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "${CYAN}💻 REMOTE ACCESS:${NC}"
    echo "   ┌─────────────────────────────────────────────────────────────────────────┐"
    echo "   │  🔌 SSH    : ssh root@$IP_ADDR                                          │"
    echo "   │  📁 Samba  : \\\\$IP_ADDR\\wikrama-share                                  │"
    echo "   └─────────────────────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              TERIMA KASIH TELAH MENGGUNAKAN FAHRITECH!                  ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════════════${NC}"
}

# =================== MENU UTAMA ===================
show_menu() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    MENU INSTALLASI SERVER                        ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📊 STATUS SAAT INI:${NC}"
    echo -e "   ${CYAN}├ Interface :${NC} ${GREEN}${INTERFACE:-Belum diset}${NC}"
    echo -e "   ${CYAN}├ IP Address:${NC} ${GREEN}${IP_ADDR:-Belum diset}${NC}"
    echo -e "   ${CYAN}└ Domain    :${NC} ${GREEN}${DOMAIN:-Belum diset}${NC}"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  1)${NC} Setting IP Address (BEBAS)"
    echo -e "${GREEN}  2)${NC} Setup DHCP Server (Range 100-200)"
    echo -e "${GREEN}  3)${NC} Setup DNS Server"
    echo -e "${GREEN}  4)${NC} Install Apache2 & PHP"
    echo -e "${GREEN}  5)${NC} Install MySQL"
    echo -e "${GREEN}  6)${NC} Install WordPress"
    echo -e "${GREEN}  7)${NC} Install phpMyAdmin"
    echo -e "${GREEN}  8)${NC} Website Utama + CRUD Siswa"
    echo -e "${GREEN}  9)${NC} Setup SSH & Samba"
    echo -e "${GREEN} 10)${NC} Install DVWA"
    echo -e "${GREEN} 11)${NC} Test NSLOOKUP"
    echo -e "${CYAN} 12)${NC} INSTALL SEMUA SEKALIGUS ⭐ (REKOMENDASI)"
    echo -e "${RED}  0)${NC} EXIT"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# =================== MAIN LOOP ===================
while true; do
    show_banner
    show_menu
    read -p "➡️  Pilih menu [0-12]: " choice
    
    case $choice in
        1) menu_set_ip ;;
        2) menu_set_dhcp ;;
        3) menu_set_dns ;;
        4) menu_set_apache ;;
        5) menu_set_mysql ;;
        6) menu_set_wordpress ;;
        7) menu_set_phpmyadmin ;;
        8) menu_set_website ;;
        9) menu_set_samba ;;
        10) menu_set_dvwa ;;
        11) menu_test_dns ;;
        12) menu_install_all ;;
        0) 
            echo -e "${GREEN}Terima kasih telah menggunakan FAHRITECH!${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}Pilihan tidak valid!${NC}"
            sleep 1
            ;;
    esac
    
    echo ""
    read -p "Tekan ENTER untuk kembali ke menu..."
done
