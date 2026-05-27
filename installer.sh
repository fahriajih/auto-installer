#!/bin/bash

# ======================================================
# INSTALLER LENGKAP - FAHRITECH SMK WIKRAMA
# ======================================================
# Fitur: Setting IP (BEBAS), DHCP (Range 100-200), DNS,
# Apache2, PHP, MySQL, WordPress, phpMyAdmin, CRUD Siswa,
# SSH, Samba, DVWA
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

# =================== TAMPILAN AWAL FAHRITECH ===================
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║   ███████╗ █████╗ ██╗  ██╗██████╗ ██╗████████╗███████╗   ║"
    echo "║   ██╔════╝██╔══██╗██║  ██║██╔══██╗██║╚══██╔══╝██╔════╝   ║"
    echo "║   █████╗  ███████║███████║██████╔╝██║   ██║   █████╗     ║"
    echo "║   ██╔══╝  ██╔══██║██╔══██║██╔══██╗██║   ██║   ██╔══╝     ║"
    echo "║   ██║     ██║  ██║██║  ██║██║  ██║██║   ██║   ███████╗   ║"
    echo "║   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝   ╚══════╝   ║"
    echo "║                                                          ║"
    echo "║           🚀 AUTO INSTALLER SERVER LINUX 🚀              ║"
    echo "║                   SMK WIKRAMA - TUTORIAL                 ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    sleep 1
}

# =================== FUNGSI VALIDASI IP (BEBAS) ===================
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi
    return 1
}

# =================== MENU 1: SETTING IP (BEBAS) ===================
menu_set_ip() {
    echo -e "${BLUE}==================== 1. SETTING IP ADDRESS ====================${NC}"
    
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
    echo -e "${YELLOW}📌 CONTOH IP:${NC}"
    echo "   192.168.1.10"
    echo "   192.168.27.50"
    echo "   10.10.10.5"
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

# =================== MENU 2: DHCP SERVER (RANGE 100-200) ===================
menu_set_dhcp() {
    echo -e "${BLUE}==================== 2. INSTALL & SETUP DHCP SERVER ====================${NC}"
    
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
    echo -e "${BLUE}==================== 3. INSTALL & SETUP DNS SERVER ====================${NC}"
    
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
    echo -e "${BLUE}==================== 4. INSTALL APACHE2 & PHP ====================${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Menginstall Apache2 dan PHP...${NC}"
    apt install apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y
    systemctl enable apache2
    systemctl restart apache2
    
    domain_web=${DOMAIN:-$IP_ADDR}
    cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>SMK Wikrama - Web Tutorial</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Poppins', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .card {
            background: rgba(255,255,255,0.95);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 500px;
            margin: 20px;
        }
        h1 { color: #667eea; margin-bottom: 20px; }
        .info { color: #555; margin: 20px 0; }
        .features { display: flex; gap: 15px; justify-content: center; flex-wrap: wrap; margin-top: 30px; }
        .badge { background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 8px 15px; border-radius: 20px; font-size: 14px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>📚 SMK Wikrama</h1>
        <h3>Web Tutorial Server</h3>
        <div class="info">
            <p>Server: <strong>$domain_web</strong></p>
            <p>IP: <strong>$DNS_IP</strong></p>
        </div>
        <div class="features">
            <span class="badge">📝 WordPress</span>
            <span class="badge">🗄️ phpMyAdmin</span>
            <span class="badge">📊 CRUD</span>
            <span class="badge">🔐 DVWA</span>
        </div>
    </div>
</body>
</html>
EOF
    
    echo ""
    echo -e "${GREEN}✅ Apache2 & PHP berhasil diinstall${NC}"
    echo -e "${GREEN}✅ Web: http://${domain_web}${NC}"
}

# =================== MENU 5: WORDPRESS ===================
menu_set_wordpress() {
    echo -e "${BLUE}==================== 5. INSTALL WORDPRESS ====================${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Menginstall MySQL...${NC}"
    apt install mariadb-server -y
    
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpass123';" 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS wordpress;" 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY 'wppass123';" 2>/dev/null
    mysql -u root -prootpass123 -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';" 2>/dev/null
    mysql -u root -prootpass123 -e "FLUSH PRIVILEGES;" 2>/dev/null
    
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

# =================== MENU 6: phpMyAdmin ===================
menu_set_phpmyadmin() {
    echo -e "${BLUE}==================== 6. INSTALL phpMyAdmin ====================${NC}"
    
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

# =================== MENU 7: CRUD SISWA (Nama, NIS, Rombel) ===================
menu_set_crud() {
    echo -e "${BLUE}==================== 7. MEMBUAT CRUD SISWA ====================${NC}"
    
    echo ""
    echo -e "${YELLOW}⚙️  Membuat database dan tabel siswa...${NC}"
    
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS sekolah;" 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE TABLE IF NOT EXISTS sekolah.siswa (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nama VARCHAR(100) NOT NULL,
        nis VARCHAR(20) NOT NULL UNIQUE,
        rombel VARCHAR(50) NOT NULL
    );" 2>/dev/null
    
    cat > /var/www/html/crud_siswa.php <<'PHP_EOF'
<?php
$conn = new mysqli("localhost", "root", "rootpass123", "sekolah");
if ($conn->connect_error) die("Koneksi gagal: " . $conn->connect_error);

$message = '';
if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    if (isset($_POST['action'])) {
        $action = $_POST['action'];
        if ($action == 'add') {
            $nama = $conn->real_escape_string($_POST['nama']);
            $nis = $conn->real_escape_string($_POST['nis']);
            $rombel = $conn->real_escape_string($_POST['rombel']);
            $check = $conn->query("SELECT id FROM siswa WHERE nis='$nis'");
            if ($check->num_rows > 0) {
                $message = '<div class="alert error">❌ NIS sudah terdaftar!</div>';
            } else {
                if ($conn->query("INSERT INTO siswa (nama, nis, rombel) VALUES ('$nama', '$nis', '$rombel')")) {
                    $message = '<div class="alert success">✅ Data berhasil ditambahkan!</div>';
                }
            }
        }
        elseif ($action == 'edit') {
            $id = intval($_POST['id']);
            $nama = $conn->real_escape_string($_POST['nama']);
            $nis = $conn->real_escape_string($_POST['nis']);
            $rombel = $conn->real_escape_string($_POST['rombel']);
            if ($conn->query("UPDATE siswa SET nama='$nama', nis='$nis', rombel='$rombel' WHERE id=$id")) {
                $message = '<div class="alert success">✅ Data berhasil diupdate!</div>';
            }
        }
        elseif ($action == 'delete') {
            $id = intval($_POST['id']);
            if ($conn->query("DELETE FROM siswa WHERE id=$id")) {
                $message = '<div class="alert success">✅ Data berhasil dihapus!</div>';
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
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Poppins', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 40px 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
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
        .btn-edit { background: #ffc107; color: #333; padding: 8px 15px; border-radius: 8px; text-decoration: none; display: inline-block; }
        .btn-edit:hover { background: #ffb300; }
        .btn-delete { background: #dc3545; color: white; padding: 8px 15px; border-radius: 8px; border: none; cursor: pointer; }
        .btn-delete:hover { background: #c82333; }
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
        .empty-state { text-align: center; padding: 40px; color: #999; }
        .empty-state i { font-size: 50px; margin-bottom: 15px; }
        .footer { text-align: center; margin-top: 30px; color: rgba(255,255,255,0.7); font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><i class="fas fa-users"></i> Manajemen Data Siswa</h1>
            <p>SMK Wikrama - Sistem CRUD Nama, NIS, dan Rombel</p>
        </div>
        
        <div class="card">
            <div class="card-header">
                <h2><i class="fas fa-plus-circle"></i> Tambah Data Siswa</h2>
            </div>
            <div class="card-body">
                <?php echo $message; ?>
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
            <div class="card-header">
                <h2><i class="fas fa-list"></i> Daftar Siswa</h2>
            </div>
            <div class="card-body">
                <div class="table-wrapper">
                    <?php if ($siswa->num_rows > 0): ?>
                    <table>
                        <thead>
                            <tr><th>No</th><th>Nama</th><th>NIS</th><th>Rombel</th><th>Aksi</th></tr>
                        </thead>
                        <tbody>
                            <?php $no = 1; while($row = $siswa->fetch_assoc()): ?>
                            <tr>
                                <td><?php echo $no++; ?></td>
                                <td><strong><?php echo htmlspecialchars($row['nama']); ?></strong></td>
                                <td><?php echo htmlspecialchars($row['nis']); ?></td>
                                <td><?php echo htmlspecialchars($row['rombel']); ?></td>
                                <td class="action-buttons">
                                    <a href="?edit=<?php echo $row['id']; ?>" class="btn-edit">
                                        <i class="fas fa-edit"></i> Edit
                                    </a>
                                    <form method="POST" action="" style="display:inline;" onsubmit="return confirm('Yakin ingin menghapus data ini?')">
                                        <input type="hidden" name="id" value="<?php echo $row['id']; ?>">
                                        <button type="submit" name="action" value="delete" class="btn-delete">
                                            <i class="fas fa-trash"></i> Hapus
                                        </button>
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
                    <button type="submit" name="action" value="edit" class="btn btn-primary">
                        <i class="fas fa-save"></i> Update Data
                    </button>
                    <a href="crud_siswa.php">
                        <button type="button" class="btn" style="background:#6c757d; color:white;">
                            <i class="fas fa-times"></i> Batal
                        </button>
                    </a>
                </form>
            </div>
        </div>
    </div>
    <?php endif; ?>
</body>
</html>
PHP_EOF
    
    rm -f /var/www/html/crud.php 2>/dev/null
    
    domain_web=${DOMAIN:-$IP_ADDR}
    echo ""
    echo -e "${GREEN}✅ CRUD Siswa berhasil dibuat!${NC}"
    echo -e "${GREEN}✅ Akses: http://${domain_web}/crud_siswa.php${NC}"
    echo -e "${YELLOW}📌 Fitur: Tambah, Edit, Hapus Data Siswa (Nama, NIS, Rombel)${NC}"
}

# =================== MENU 8: SSH + SAMBA ===================
menu_set_samba() {
    echo -e "${BLUE}==================== 8. SSH & SAMBA FILE SHARING ====================${NC}"
    
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

# =================== MENU 9: GITHUB + DVWA ===================
menu_set_github_dvwa() {
    echo -e "${BLUE}==================== 9. CLONE GITHUB & DVWA ====================${NC}"
    
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

# =================== MENU 10: TEST DNS ===================
menu_test_dns() {
    echo -e "${BLUE}==================== 10. TEST NSLOOKUP ====================${NC}"
    
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

# =================== MENU 11: INSTALL SEMUA SEKALIGUS ===================
menu_install_all() {
    echo -e "${BLUE}==================== INSTALL SEMUA FITUR ====================${NC}"
    
    # Setting IP dulu
    menu_set_ip
    if [ $? -ne 0 ]; then return 1; fi
    
    # DHCP
    menu_set_dhcp
    if [ $? -ne 0 ]; then return 1; fi
    
    # DNS
    menu_set_dns
    if [ $? -ne 0 ]; then return 1; fi
    
    # Apache
    menu_set_apache
    if [ $? -ne 0 ]; then return 1; fi
    
    # WordPress
    menu_set_wordpress
    if [ $? -ne 0 ]; then return 1; fi
    
    # phpMyAdmin
    menu_set_phpmyadmin
    if [ $? -ne 0 ]; then return 1; fi
    
    # CRUD
    menu_set_crud
    if [ $? -ne 0 ]; then return 1; fi
    
    # Samba
    menu_set_samba
    if [ $? -ne 0 ]; then return 1; fi
    
    # DVWA
    menu_set_github_dvwa
    if [ $? -ne 0 ]; then return 1; fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              ✅ SEMUA FITUR BERHASIL DIINSTALL! ✅${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}🌐 AKSES WEB SERVER:${NC}"
    echo "   📍 Website Utama    : http://$IP_ADDR/"
    echo "   📍 CRUD Siswa       : http://$IP_ADDR/crud_siswa.php"
    echo "   📍 WordPress        : http://$IP_ADDR/wp-admin"
    echo "   📍 phpMyAdmin       : http://$IP_ADDR/phpmyadmin"
    echo "   📍 DVWA             : http://$IP_ADDR/setup.php"
    echo ""
    echo -e "${YELLOW}🔑 LOGIN:${NC}"
    echo "   📍 phpMyAdmin : root / rootpass123"
    echo "   📍 DVWA       : admin / password"
    echo ""
    echo -e "${CYAN}💻 REMOTE:${NC}"
    echo "   📍 SSH    : ssh root@$IP_ADDR"
    echo "   📍 Samba  : \\\\$IP_ADDR\\wikrama-share"
    echo ""
}

# =================== MENU UTAMA ===================
show_menu() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}        MENU INSTALLASI SERVER          ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${YELLOW}📊 STATUS SAAT INI:${NC}"
    echo -e "   ${CYAN}├ Interface :${NC} ${GREEN}${INTERFACE:-Belum diset}${NC}"
    echo -e "   ${CYAN}├ IP Address:${NC} ${GREEN}${IP_ADDR:-Belum diset}${NC}"
    echo -e "   ${CYAN}└ Domain    :${NC} ${GREEN}${DOMAIN:-Belum diset}${NC}"
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN} 1)${NC} Setting IP Address (BEBAS)"
    echo -e "${GREEN} 2)${NC} Setup DHCP Server (Range 100-200)"
    echo -e "${GREEN} 3)${NC} Setup DNS Server"
    echo -e "${GREEN} 4)${NC} Install Apache2 & PHP"
    echo -e "${GREEN} 5)${NC} Install WordPress"
    echo -e "${GREEN} 6)${NC} Install phpMyAdmin"
    echo -e "${GREEN} 7)${NC} Buat CRUD Siswa (Nama, NIS, Rombel)"
    echo -e "${GREEN} 8)${NC} Setup SSH & Samba"
    echo -e "${GREEN} 9)${NC} Clone GitHub & DVWA"
    echo -e "${GREEN}10)${NC} Test NSLOOKUP"
    echo -e "${CYAN}11)${NC} INSTALL SEMUA SEKALIGUS (REKOMENDASI)"
    echo -e "${RED} 0)${NC} EXIT"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# =================== MAIN LOOP ===================
while true; do
    show_banner
    show_menu
    read -p "➡️  Pilih menu [0-11]: " choice
    
    case $choice in
        1) menu_set_ip ;;
        2) menu_set_dhcp ;;
        3) menu_set_dns ;;
        4) menu_set_apache ;;
        5) menu_set_wordpress ;;
        6) menu_set_phpmyadmin ;;
        7) menu_set_crud ;;
        8) menu_set_samba ;;
        9) menu_set_github_dvwa ;;
        10) menu_test_dns ;;
        11) menu_install_all ;;
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
