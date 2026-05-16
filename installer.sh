#!/bin/bash

# ============================================================
#   FAHTECH - MULTI-SERVICE INSTALLER PRO v4.0
#   SEMUA OTOMATIS | TINGGAL PILIH NOMOR
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Header
clear
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                           ║"
echo "║   ███████╗ █████╗ ██╗  ██╗████████╗███████╗ ██████╗██╗  ██╗║"
echo "║   ██╔════╝██╔══██╗██║  ██║╚══██╔══╝██╔════╝██╔════╝██║  ██║║"
echo "║   █████╗  ███████║███████║   ██║   █████╗  ██║     ███████║║"
echo "║   ██╔══╝  ██╔══██║██╔══██║   ██║   ██╔══╝  ██║     ██╔══██║║"
echo "║   ██║     ██║  ██║██║  ██║   ██║   ███████╗╚██████╗██║  ██║║"
echo "║   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝║"
echo "║                                                           ║"
echo "║        AUTO INSTALLER PROFESSIONAL - PLUG AND PLAY        ║"
echo "║              TINGGAL PILIH, SEMUA OTOMATIS                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Cek root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Jalankan sebagai root!${NC}"
    exit 1
fi

# ============================================================
# DETEKSI INTERFACE OTOMATIS
# ============================================================
detect_interfaces() {
    INTERFACES=()
    INTERFACE_LIST=()
    
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        IP=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        if [[ -n $IP ]]; then
            INTERFACES+=("$iface|$IP")
            INTERFACE_LIST+=("$iface")
        fi
    done
}

# Tampilkan pilihan interface
show_interfaces() {
    detect_interfaces
    echo -e "\n${GREEN}📡 Network Interface yang terdeteksi:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    for i in "${!INTERFACES[@]}"; do
        IFS='|' read -r iface ip <<< "${INTERFACES[$i]}"
        echo -e "  ${YELLOW}$((i+1))${NC}. ${CYAN}$iface${NC} → IP: ${GREEN}$ip${NC}"
    done
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ============================================================
# 1. INSTALL DHCP - OTOMATIS DETEKSI
# ============================================================
install_dhcp() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🌐 INSTALL DHCP SERVER                  ║${NC}"
    echo -e "${GREEN}║         (Otomatis Deteksi Interface)            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    show_interfaces
    
    echo -e "\n${YELLOW}👉 Pilih interface untuk DHCP:${NC}"
    read -p "Masukkan nomor: " choice
    
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r SELECTED_IFACE SELECTED_IP <<< "${INTERFACES[$((choice-1))]}"
        echo -e "${GREEN}✅ Terpilih: $SELECTED_IFACE (IP: $SELECTED_IP)${NC}"
        
        # Ambil subnet otomatis dari IP yang dipilih
        SUBNET=$(echo $SELECTED_IP | cut -d. -f1-3).0
        GATEWAY=$(echo $SELECTED_IP | cut -d. -f1-3).1
        RANGE_START=$(echo $SELECTED_IP | cut -d. -f1-3).100
        RANGE_END=$(echo $SELECTED_IP | cut -d. -f1-3).200
        
        echo -e "\n${YELLOW}📝 Konfigurasi otomatis:${NC}"
        echo -e "   Subnet: ${GREEN}$SUBNET${NC}"
        echo -e "   Gateway: ${GREEN}$GATEWAY${NC}"
        echo -e "   Range IP: ${GREEN}$RANGE_START - $RANGE_END${NC}"
        
        echo -e "\n${YELLOW}Apakah ingin mengubah konfigurasi? (y/n):${NC}"
        read -p "" edit_confirm
        
        if [[ "$edit_confirm" == "y" ]]; then
            echo -n "Subnet (Enter untuk default $SUBNET): "
            read input_subnet
            SUBNET=${input_subnet:-$SUBNET}
            
            echo -n "Gateway (Enter untuk default $GATEWAY): "
            read input_gateway
            GATEWAY=${input_gateway:-$GATEWAY}
            
            echo -n "Range Mulai (Enter untuk default $RANGE_START): "
            read input_start
            RANGE_START=${input_start:-$RANGE_START}
            
            echo -n "Range Akhir (Enter untuk default $RANGE_END): "
            read input_end
            RANGE_END=${input_end:-$RANGE_END}
        fi
        
        echo -e "\n${CYAN}📦 Menginstall DHCP Server...${NC}"
        
        apt update -qq
        apt install isc-dhcp-server -y -qq
        
        cat > /etc/default/isc-dhcp-server <<EOF
INTERFACESv4="$SELECTED_IFACE"
INTERFACESv6=""
EOF
        
        cat > /etc/dhcp/dhcpd.conf <<EOF
subnet $SUBNET netmask 255.255.255.0 {
    range $RANGE_START $RANGE_END;
    option routers $GATEWAY;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
    default-lease-time 600;
    max-lease-time 7200;
}
EOF
        
        systemctl restart isc-dhcp-server
        systemctl enable isc-dhcp-server
        
        echo -e "\n${GREEN}✅ DHCP BERHASIL!${NC}"
        echo -e "   Interface: $SELECTED_IFACE"
        echo -e "   Subnet: $SUBNET/24"
        
    else
        echo -e "${RED}❌ Pilihan salah!${NC}"
    fi
    
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# 2. INSTALL DNS - OTOMATIS DETEKSI
# ============================================================
install_dns() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🔍 INSTALL DNS SERVER                   ║${NC}"
    echo -e "${GREEN}║         (Domain & IP Otomatis)                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    show_interfaces
    
    echo -e "\n${YELLOW}👉 Pilih interface untuk DNS Server:${NC}"
    read -p "Masukkan nomor: " choice
    
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r DNS_IFACE DNS_IP <<< "${INTERFACES[$((choice-1))]}"
        echo -e "${GREEN}✅ Terpilih: $DNS_IFACE (IP: $DNS_IP)${NC}"
        
        echo -e "\n${YELLOW}📝 Masukkan nama domain:${NC}"
        read -p "Domain (contoh: fahtech.com): " DOMAIN_NAME
        
        apt update -qq
        apt install bind9 bind9utils -y -qq
        
        cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN_NAME" {
    type master;
    file "/etc/bind/db.$DOMAIN_NAME";
};
EOF
        
        cat > /etc/bind/db.$DOMAIN_NAME <<EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN_NAME. admin.$DOMAIN_NAME. (
                  2026010501         ; Serial
                  604800         ; Refresh
                  86400         ; Retry
                  2419200        ; Expire
                  604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN_NAME.
@       IN      A       $DNS_IP
@       IN      MX 10   mail.$DOMAIN_NAME.
ns1     IN      A       $DNS_IP
www     IN      A       $DNS_IP
mail    IN      A       $DNS_IP
EOF
        
        systemctl restart bind9
        systemctl enable bind9
        
        echo -e "\n${GREEN}✅ DNS BERHASIL!${NC}"
        echo -e "   Domain: $DOMAIN_NAME"
        echo -e "   IP: $DNS_IP"
    else
        echo -e "${RED}❌ Pilihan salah!${NC}"
    fi
    
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# 3. INSTALL APACHE2 + LANDING PAGE FAHTECH
# ============================================================
install_apache2() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🌍 INSTALL APACHE2                      ║${NC}"
    echo -e "${GREEN}║         + Landing Page FahTech                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    apt update -qq
    apt install apache2 php libapache2-mod-php -y -qq
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>FahTech - Server Professional</title>
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .card {
            background: white;
            border-radius: 20px;
            padding: 50px;
            max-width: 900px;
            text-align: center;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 { color: #667eea; font-size: 52px; margin-bottom: 10px; }
        .tagline { color: #764ba2; font-size: 18px; margin-bottom: 30px; }
        .status { background: #4CAF50; color: white; padding: 12px; border-radius: 10px; margin: 20px 0; font-size: 18px; }
        .ip-box { background: #1a1a2e; color: #0f0; padding: 15px; border-radius: 10px; font-family: monospace; margin: 20px 0; font-size: 18px; }
        .services { display: grid; grid-template-columns: repeat(4,1fr); gap: 15px; margin: 30px 0; }
        .service { background: #f8f9fa; padding: 15px; border-radius: 10px; transition: transform 0.3s; }
        .service:hover { transform: translateY(-5px); background: #e9ecef; cursor: pointer; }
        .icon { font-size: 40px; display: block; margin-bottom: 10px; }
        .footer { margin-top: 30px; color: #999; font-size: 12px; }
        @media (max-width: 600px) { .services { grid-template-columns: repeat(2,1fr); } .card { padding: 30px; } h1 { font-size: 36px; } }
    </style>
</head>
<body>
    <div class="card">
        <h1>⚡ FAHTECH ⚡</h1>
        <div class="tagline">Professional Server Solutions</div>
        <div class="status">🟢 ALL SYSTEMS OPERATIONAL</div>
        <div class="ip-box">🌐 SERVER IP: <?php echo $_SERVER['SERVER_ADDR']; ?></div>
        <h2>Available Services</h2>
        <div class="services">
            <div class="service"><span class="icon">🌐</span><br>Apache2</div>
            <div class="service"><span class="icon">📁</span><br>FTP</div>
            <div class="service"><span class="icon">🔍</span><br>DNS</div>
            <div class="service"><span class="icon">💾</span><br>Samba</div>
            <div class="service"><span class="icon">📧</span><br>Mail</div>
            <div class="service"><span class="icon">📝</span><br>WordPress</div>
            <div class="service"><span class="icon">🗄️</span><br>CRUD</div>
            <div class="service"><span class="icon">⚙️</span><br>Auto Install</div>
        </div>
        <div class="footer">Powered by FahTech Auto Installer v4.0 | &copy; 2026</div>
    </div>
</body>
</html>
EOF
    
    systemctl restart apache2
    
    echo -e "\n${GREEN}✅ APACHE2 BERHASIL!${NC}"
    echo -e "   Akses: http://$SERVER_IP"
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# 4. INSTALL FTP
# ============================================================
install_ftp() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         📁 INSTALL FTP SERVER                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    apt install vsftpd -y -qq
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${GREEN}✅ FTP BERHASIL!${NC}"
    echo -e "   Server: $SERVER_IP"
    echo -e "   Port: 21"
    echo -e "\n${YELLOW}📝 Tambah user FTP: useradd -m nama && passwd nama${NC}"
    
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# 5. INSTALL SAMBA
# ============================================================
install_samba() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🖥️  INSTALL SAMBA                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    echo -n "📝 Nama share (Enter untuk 'public'): "
    read share_name
    share_name=${share_name:-public}
    
    apt install samba -y -qq
    
    mkdir -p /home/share
    chmod 777 /home/share
    
    cat >> /etc/samba/smb.conf <<EOF

[$share_name]
   path = /home/share
   browseable = yes
   writable = yes
   guest ok = yes
   public = yes
   create mask = 0777
   directory mask = 0777
EOF
    
    systemctl restart smbd
    systemctl enable smbd
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${GREEN}✅ SAMBA BERHASIL!${NC}"
    echo -e "   Akses: //$SERVER_IP/$share_name"
    
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# 6. INSTALL MAIL SERVER
# ============================================================
install_mail() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         📧 INSTALL MAIL SERVER                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    echo -n "📝 Domain untuk email (contoh: mail.fahtech.com): "
    read mail_domain
    
    debconf-set-selections <<EOF
postfix postfix/mailname string $mail_domain
postfix postfix/main_mailer_type string 'Internet Site'
EOF
    
    apt install postfix dovecot-core dovecot-imapd -y -qq
    
    systemctl restart postfix dovecot
    systemctl enable postfix dovecot
    
    echo -e "\n${GREEN}✅ MAIL SERVER BERHASIL!${NC}"
    echo -e "   Domain: $mail_domain"
    
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# 7. INSTALL WORDPRESS
# ============================================================
install_wordpress() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         📝 INSTALL WORDPRESS                   ║${NC}"
    echo -e "${GREEN}║         + Database Auto Setup                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    apt install mariadb-server php php-mysql php-curl php-gd php-xml php-mbstring php-zip unzip wget -y -qq
    
    systemctl restart mariadb
    
    DB_PASS=$(openssl rand -base64 12 | tr -d "=/+" | cut -c1-16)
    
    mysql <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    
    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    cp -r wordpress/* /var/www/html/
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    
    sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php
    sed -i "s/password_here/$DB_PASS/" /var/www/html/wp-config.php
    
    chown -R www-data:www-data /var/www/html/
    systemctl restart apache2
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${GREEN}✅ WORDPRESS BERHASIL!${NC}"
    echo -e "   🔗 Akses: http://$SERVER_IP/wp-admin/install.php"
    echo -e "   📊 DB User: wpuser"
    echo -e "   🔑 DB Pass: $DB_PASS"
    
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# 8. INSTALL CRUD WEB
# ============================================================
install_crud() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🗄️  INSTALL CRUD WEB                   ║${NC}"
    echo -e "${GREEN}║         (SQLite Database)                     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    apt install php-sqlite3 -y -qq
    
    mkdir -p /var/www/html/crud
    
    cat > /var/www/html/crud/index.php <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>FahTech - CRUD App</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: #f0f2f5; font-family: 'Segoe UI', Arial, sans-serif; padding: 40px; }
        .container { max-width: 800px; margin: 0 auto; background: white; border-radius: 15px; padding: 30px; box-shadow: 0 5px 20px rgba(0,0,0,0.1); }
        h1 { color: #667eea; margin-bottom: 10px; }
        hr { margin: 20px 0; border: none; height: 1px; background: #ddd; }
        form { display: flex; gap: 10px; margin-bottom: 30px; }
        input { flex: 1; padding: 12px; border: 1px solid #ddd; border-radius: 8px; font-size: 16px; }
        button { background: #667eea; color: white; border: none; padding: 12px 24px; border-radius: 8px; cursor: pointer; font-size: 16px; }
        button:hover { background: #5a67d8; }
        .success { background: #d4edda; color: #155724; padding: 12px; border-radius: 8px; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f8f9fa; color: #333; }
        .delete { color: red; text-decoration: none; }
        .delete:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ FahTech CRUD App</h1>
        <p>Simple Create, Read, Update, Delete dengan SQLite</p>
        <hr>
        
        <?php
        $db = new SQLite3('/var/www/html/crud/data.db');
        $db->exec("CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)");
        
        if (isset($_POST['add']) && !empty($_POST['name'])) {
            $name = SQLite3::escapeString($_POST['name']);
            $db->exec("INSERT INTO items (name) VALUES ('$name')");
            echo "<div class='success'>✅ Item berhasil ditambahkan!</div>";
        }
        
        if (isset($_GET['delete'])) {
            $id = (int)$_GET['delete'];
            $db->exec("DELETE FROM items WHERE id = $id");
            echo "<div class='success'>✅ Item berhasil dihapus!</div>";
        }
        
        $result = $db->query("SELECT * FROM items ORDER BY id DESC");
        ?>
        
        <form method="post">
            <input type="text" name="name" placeholder="Masukkan nama item..." required>
            <button type="submit" name="add">➕ Tambah Data</button>
        </form>
        
        <h2>📋 Data Items</h2>
        <table>
            <tr><th>ID</th><th>Nama Item</th><th>Tanggal Dibuat</th><th>Aksi</th></tr>
            <?php while ($row = $result->fetchArray()): ?>
            <tr>
                <td><?= $row['id'] ?></td>
                <td><?= htmlspecialchars($row['name']) ?></td>
                <td><?= $row['created_at'] ?></td>
                <td><a href="?delete=<?= $row['id'] ?>" class="delete" onclick="return confirm('Yakin hapus?')">🗑️ Hapus</a></td>
            </tr>
            <?php endwhile; ?>
        </table>
    </div>
</body>
</html>
EOF
    
    chown -R www-data:www-data /var/www/html/crud
    systemctl restart apache2
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "\n${GREEN}✅ CRUD WEB BERHASIL!${NC}"
    echo -e "   🔗 Akses: http://$SERVER_IP/crud/"
    
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# 9. INSTALL SEMUA SEKALIGUS
# ============================================================
install_all() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║      ⚡ INSTALL SEMUA SERVICE                  ║${NC}"
    echo -e "${GREEN}║      Proses akan memakan waktu beberapa menit ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}Mulai install semua service? (y/n):${NC}"
    read confirm
    
    if [[ "$confirm" == "y" ]]; then
        install_apache2
        install_dhcp
        install_dns
        install_ftp
        install_samba
        install_mail
        install_wordpress
        install_crud
        
        echo -e "\n${GREEN}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║   ✅ SEMUA SERVICE BERHASIL DIINSTALL!        ║${NC}"
        echo -e "${GREEN}║   🎉 SELAMAT! SERVER ANDA SIAP DIGUNAKAN     ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    fi
    
    echo -e "\n${YELLOW}Tekan Enter untuk kembali...${NC}"
    read
}

# ============================================================
# MENU UTAMA
# ============================================================
while true; do
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║            🚀 FAHTECH MULTI-SERVICE INSTALLER              ║"
    echo "║                                                            ║"
    echo "║         ⚡ PLUG AND PLAY | TINGGAL PILIH NOMOR ⚡          ║"
    echo "║                                                            ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║                                                            ║"
    echo "║  ${GREEN}1${NC}. ⚡ Install SEMUA Service (Auto Detect)              ║"
    echo "║  ${GREEN}2${NC}. 🌐 Install DHCP Server (Otomatis Deteksi Interface) ║"
    echo "║  ${GREEN}3${NC}. 🔍 Install DNS Server (Pilih Interface + Input Domain)║"
    echo "║  ${GREEN}4${NC}. 🌍 Install Apache2 + Landing Page FahTech         ║"
    echo "║  ${GREEN}5${NC}. 📁 Install FTP Server (vsftpd)                    ║"
    echo "║  ${GREEN}6${NC}. 🖥️  Install Samba File Server                     ║"
    echo "║  ${GREEN}7${NC}. 📧 Install Mail Server (Postfix+Dovecot)          ║"
    echo "║  ${GREEN}8${NC}. 📝 Install WordPress + Database Auto Setup        ║"
    echo "║  ${GREEN}9${NC}. 🗄️  Install CRUD Web (SQLite)                    ║"
    echo "║  ${GREEN}10${NC}. 🚪 Exit                                          ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "👉 Pilih menu [1-10]: " menu
    
    case $menu in
        1) install_all ;;
        2) install_dhcp ;;
        3) install_dns ;;
        4) install_apache2 ;;
        5) install_ftp ;;
        6) install_samba ;;
        7) install_mail ;;
        8) install_wordpress ;;
        9) install_crud ;;
        10) 
            echo -e "${GREEN}👋 Terima kasih sudah menggunakan FahTech Installer!${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}❌ Pilihan salah!${NC}"
            sleep 1
            ;;
    esac
done