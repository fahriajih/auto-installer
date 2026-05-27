#!/bin/bash

# ======================================================
# AUTOMATION SCRIPT MENU - Server Web SMK Wikrama
# ======================================================

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# =================== FUNGSI VALIDASI ===================
validate_ip_range() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        last_octet=$(echo $ip | cut -d'.' -f4)
        if [[ $last_octet -ge 100 && $last_octet -le 200 ]]; then
            return 0
        fi
    fi
    return 1
}

list_interfaces() {
    echo -e "${GREEN}Interface yang terdeteksi:${NC}"
    interfaces=($(ip link show | grep -E '^[0-9]+: ens|eth' | awk -F': ' '{print $2}'))
    for i in "${!interfaces[@]}"; do
        echo "  $((i+1))) ${interfaces[$i]}"
    done
    echo "${#interfaces[@]}" # return jumlah interface
}

# =================== MENU 1: SETTING IP ===================
menu_set_ip() {
    echo -e "${BLUE}==================== 1. SETTING IP ADDRESS ====================${NC}"
    
    # Tampilkan interface yang tersedia
    interfaces=($(ip link show | grep -E '^[0-9]+: ens|eth' | awk -F': ' '{print $2}'))
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}Tidak ada interface ens/eth yang terdeteksi!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Pilih interface yang mau dipakai:${NC}"
    for i in "${!interfaces[@]}"; do
        echo "  $((i+1))) ${interfaces[$i]}"
    done
    read -p "Masukkan pilihan [1-${#interfaces[@]}]: " pilih_interface
    
    if [[ $pilih_interface -ge 1 && $pilih_interface -le ${#interfaces[@]} ]]; then
        INTERFACE="${interfaces[$((pilih_interface-1))]}"
    else
        echo -e "${RED}Pilihan tidak valid!${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}CONTOH IP VALID: 192.168.1.150 (angka terakhir 100-200)${NC}"
    echo "${YELLOW}CONTOH: 192.168.27.150, 10.10.10.120${NC}"
    
    while true; do
        read -p "Masukkan IP address untuk $INTERFACE: " IP_ADDR
        if validate_ip_range "$IP_ADDR"; then
            break
        else
            echo -e "${RED}IP tidak valid! Oktett terakhir harus antara 100-200.${NC}"
        fi
    done
    
    # Otomatis ambil gateway dari IP (network .1)
    subnet=$(echo $IP_ADDR | cut -d'.' -f1-3)
    GATEWAY="${subnet}.1"
    
    echo -e "${YELLOW}Gateway otomatis: $GATEWAY${NC}"
    
    # Netmask langsung 255.255.255.0
    NETMASK="255.255.255.0"
    
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
    echo -e "${GREEN}✓ IP Address $IP_ADDR berhasil diset ke $INTERFACE${NC}"
    echo -e "${GREEN}✓ Netmask: 255.255.255.0${NC}"
    echo -e "${GREEN}✓ Gateway: $GATEWAY${NC}"
}

# =================== MENU 2: DHCP SERVER ===================
menu_set_dhcp() {
    echo -e "${BLUE}==================== 2. INSTALL & SETUP DHCP SERVER ====================${NC}"
    
    # Tampilkan interface yang tersedia untuk DHCP
    interfaces=($(ip link show | grep -E '^[0-9]+: ens|eth' | awk -F': ' '{print $2}'))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}Tidak ada interface yang terdeteksi!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Pilih interface untuk DHCP Server:${NC}"
    for i in "${!interfaces[@]}"; do
        # Cek apakah interface sudah punya IP
        ip_check=$(ip addr show ${interfaces[$i]} | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [ -n "$ip_check" ]; then
            echo "  $((i+1))) ${interfaces[$i]} (IP: $ip_check)"
        else
            echo "  $((i+1))) ${interfaces[$i]} (belum ada IP)"
        fi
    done
    
    read -p "Masukkan pilihan [1-${#interfaces[@]}]: " pilih_dhcp
    
    if [[ $pilih_dhcp -ge 1 && $pilih_dhcp -le ${#interfaces[@]} ]]; then
        DHCP_INTERFACE="${interfaces[$((pilih_dhcp-1))]}"
    else
        echo -e "${RED}Pilihan tidak valid!${NC}"
        return 1
    fi
    
    # Install DHCP
    apt update
    apt install isc-dhcp-server -y
    
    # Dapatkan subnet dari IP yang sudah diset (atau pakai IP dari menu 1)
    if [ -z "$IP_ADDR" ]; then
        # Ambil IP dari interface yang dipilih
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
    
    echo -e "${GREEN}✓ DHCP Server berhasil diinstall${NC}"
    echo -e "${GREEN}✓ Interface: $DHCP_INTERFACE${NC}"
    echo -e "${GREEN}✓ Range IP: ${subnet}.100 - ${subnet}.200${NC}"
}

# =================== MENU 3: DNS SERVER ===================
menu_set_dns() {
    echo -e "${BLUE}==================== 3. INSTALL & SETUP DNS SERVER ====================${NC}"
    
    echo -e "${YELLOW}CONTOH DOMAIN: smkwikrama.local${NC}"
    echo -e "${YELLOW}CONTOH IP DOMAIN: $IP_ADDR (atau IP lain)${NC}"
    read -p "Masukkan nama domain (contoh: smkwikrama.local): " DOMAIN
    read -p "Masukkan IP untuk domain $DOMAIN (contoh: $IP_ADDR): " DNS_IP
    
    apt install bind9 -y
    
    # Forward zone
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
    
    # Reverse zone
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
    
    echo -e "${GREEN}✓ DNS Server berhasil diinstall${NC}"
    echo -e "${GREEN}✓ Domain: $DOMAIN -> $DNS_IP${NC}"
    echo -e "${YELLOW}Test nslookup: nslookup $DOMAIN $DNS_IP${NC}"
}

# =================== MENU 4: APACHE2 + PHP ===================
menu_set_apache() {
    echo -e "${BLUE}==================== 4. INSTALL APACHE2 & PHP ====================${NC}"
    
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
        body { font-family: Arial; text-align: center; padding: 50px; background: #f0f0f0; }
        h1 { color: #2c3e50; }
        .info { background: white; padding: 20px; border-radius: 10px; display: inline-block; }
    </style>
</head>
<body>
    <div class="info">
        <h1>📚 Selamat Datang di Web Tutorial SMK Wikrama</h1>
        <p>Server berjalan di <strong>$domain_web</strong></p>
        <p>Akses melalui: <a href="http://$domain_web">http://$domain_web</a></p>
        <hr>
        <h3>✅ Fitur yang tersedia:</h3>
        <p>📝 WordPress | 🗄️ phpMyAdmin | 📊 CRUD | 🔐 DVWA</p>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}✓ Apache2 & PHP berhasil diinstall${NC}"
    echo -e "${GREEN}✓ Web bisa diakses: http://${domain_web}${NC}"
}

# =================== MENU 5: WORDPRESS ===================
menu_set_wordpress() {
    echo -e "${BLUE}==================== 5. INSTALL WORDPRESS ====================${NC}"
    
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
    echo -e "${GREEN}✓ WordPress berhasil diinstall${NC}"
    echo -e "${GREEN}✓ Akses: http://${domain_web}/wp-admin${NC}"
}

# =================== MENU 6: phpMyAdmin ===================
menu_set_phpmyadmin() {
    echo -e "${BLUE}==================== 6. INSTALL phpMyAdmin ====================${NC}"
    
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password rootpass123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password rootpass123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password rootpass123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    
    apt install phpmyadmin -y
    systemctl restart apache2
    
    domain_web=${DOMAIN:-$IP_ADDR}
    echo -e "${GREEN}✓ phpMyAdmin berhasil diinstall${NC}"
    echo -e "${GREEN}✓ Akses: http://${domain_web}/phpmyadmin${NC}"
    echo -e "${YELLOW}  Login: root / rootpass123${NC}"
}

# =================== MENU 7: CRUD ===================
menu_set_crud() {
    echo -e "${BLUE}==================== 7. MEMBUAT CRUD SEDERHANA ====================${NC}"
    
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS crud_db;" 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE TABLE IF NOT EXISTS crud_db.users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100), email VARCHAR(100));" 2>/dev/null
    
    cat > /var/www/html/crud.php <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>CRUD - SMK Wikrama</title>
    <style>
        body { font-family: Arial; padding: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #2c3e50; color: white; }
        .add-form { margin-bottom: 20px; padding: 15px; background: #f0f0f0; border-radius: 5px; }
        input { padding: 5px; margin: 5px; }
        button { padding: 5px 10px; background: #2c3e50; color: white; border: none; cursor: pointer; }
    </style>
</head>
<body>
    <h1>📋 CRUD Data User</h1>
    <div class="add-form">
        <h3>Tambah User</h3>
        <form method="post">
            <input type="text" name="name" placeholder="Nama" required>
            <input type="email" name="email" placeholder="Email" required>
            <button type="submit" name="action" value="add">Tambah</button>
        </form>
    </div>
    <h3>Daftar User</h3>
    <table>
        <tr><th>ID</th><th>Nama</th><th>Email</th><th>Aksi</th></tr>
<?php
$conn = new mysqli("localhost", "root", "rootpass123", "crud_db");
if ($conn->connect_error) die("Koneksi gagal");

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    if($_POST['action'] == 'add') {
        $conn->query("INSERT INTO users (name, email) VALUES ('$_POST[name]', '$_POST[email]')");
        echo "<script>location.href='crud.php';</script>";
    }
    if($_POST['action'] == 'delete') {
        $conn->query("DELETE FROM users WHERE id=$_POST[id]");
        echo "<script>location.href='crud.php';</script>";
    }
}
$result = $conn->query("SELECT * FROM users");
while($row = $result->fetch_assoc()) {
    echo "<tr><td>{$row['id']}</td><td>{$row['name']}</td><td>{$row['email']}</td>";
    echo "<td><form method='post'><input type='hidden' name='id' value='{$row['id']}'><button type='submit' name='action' value='delete'>Hapus</button></form></td></tr>";
}
?>
    </table>
</body>
</html>
EOF
    
    domain_web=${DOMAIN:-$IP_ADDR}
    echo -e "${GREEN}✓ CRUD berhasil dibuat: http://${domain_web}/crud.php${NC}"
}

# =================== MENU 8: SSH + SAMBA ===================
menu_set_samba() {
    echo -e "${BLUE}==================== 8. SSH & SAMBA FILE SHARING ====================${NC}"
    
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
    
    echo -e "${GREEN}✓ SSH Server aktif: ssh root@$IP_ADDR${NC}"
    echo -e "${GREEN}✓ Samba Share: \\\\$IP_ADDR\\wikrama-share${NC}"
}

# =================== MENU 9: GITHUB + DVWA ===================
menu_set_github_dvwa() {
    echo -e "${BLUE}==================== 9. CLONE GITHUB & DVWA ====================${NC}"
    
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
    echo -e "${GREEN}✓ DVWA berhasil diinstall${NC}"
    echo -e "${GREEN}✓ Akses: http://${domain_web}/setup.php (Create Database)${NC}"
    echo -e "${YELLOW}  Login: admin / password${NC}"
}

# =================== MENU 10: TEST DNS ===================
menu_test_dns() {
    echo -e "${BLUE}==================== 10. TEST NSLOOKUP ====================${NC}"
    
    if [ -z "$DOMAIN" ]; then
        echo -e "${RED}Anda harus setting DNS dulu (Menu 3)!${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}nslookup $DOMAIN:${NC}"
    nslookup $DOMAIN $DNS_IP 2>/dev/null || echo "Gagal"
    
    echo -e "${YELLOW}nslookup www.$DOMAIN:${NC}"
    nslookup www.$DOMAIN $DNS_IP 2>/dev/null || echo "Gagal"
}

# =================== MENU UTAMA ===================
show_menu() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   AUTOMATION SERVER SMK WIKRAMA       ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Status:${NC}"
    echo "  Interface : ${GREEN}${INTERFACE:-Belum}${NC}"
    echo "  IP Address: ${GREEN}${IP_ADDR:-Belum}${NC}"
    echo "  Domain    : ${GREEN}${DOMAIN:-Belum}${NC}"
    echo ""
    echo -e "${BLUE}Pilih Menu:${NC}"
    echo " 1) Setting IP Address"
    echo " 2) Setup DHCP Server"
    echo " 3) Setup DNS Server"
    echo " 4) Install Apache2 & PHP"
    echo " 5) Install WordPress"
    echo " 6) Install phpMyAdmin"
    echo " 7) Buat CRUD"
    echo " 8) Setup SSH & Samba"
    echo " 9) Clone GitHub & DVWA"
    echo "10) Test NSLOOKUP"
    echo " 0) EXIT"
    echo ""
}

# =================== MAIN LOOP ===================
while true; do
    show_menu
    read -p "Pilihan [0-10]: " choice
    
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
        0) 
            echo -e "${GREEN}Terima kasih!${NC}"
            exit 0
            ;;
        *) echo -e "${RED}Pilihan salah!${NC}"; sleep 1 ;;
    esac
    
    read -p "Tekan ENTER untuk lanjut..."
done
