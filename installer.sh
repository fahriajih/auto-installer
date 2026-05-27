#!/bin/bash

# ======================================================
# AUTOMATION SCRIPT - Server Web SMK Wikrama
# Fungsi: Setting IP, DHCP, DNS, Apache2, WordPress,
#         phpMyAdmin, CRUD, Samba, GitHub Clone, DVWA
# ======================================================

# Warna biar keren
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Script ini harus dijalankan sebagai root!${NC}"
   exit 1
fi

# =================== FUNGSI ===================

# Fungsi validasi IP range 100-200
validate_ip() {
    local ip=$1
    local valid=1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        last_octet=${octets[3]}
        if [[ $last_octet -ge 100 && $last_octet -le 200 ]]; then
            valid=0
        fi
    fi
    return $valid
}

# Cek interface jaringan
list_interfaces() {
    echo -e "${GREEN}Interface jaringan yang tersedia:${NC}"
    ip link show | grep -E '^[0-9]+: ens|eth' | awk -F': ' '{print $2}'
}

# =================== 1. SETUP IP ADDRESS ===================
echo -e "${YELLOW}==================== SETUP IP ADDRESS ====================${NC}"
list_interfaces
read -p "Masukkan nama interface (contoh: ens33): " INTERFACE

if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo -e "${RED}Interface tidak ditemukan!${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Contoh IP yang valid: 192.168.1.150 (oktett terakhir 100-200)${NC}"
while true; do
    read -p "Masukkan IP address untuk $INTERFACE: " IP_ADDR
    if validate_ip "$IP_ADDR"; then
        break
    else
        echo -e "${RED}IP tidak valid! Oktett terakhir harus antara 100-200.${NC}"
    fi
done

read -p "Masukkan Netmask (default 255.255.255.0): " NETMASK
NETMASK=${NETMASK:-255.255.255.0}
read -p "Masukkan Gateway: " GATEWAY

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
echo -e "${GREEN}IP Address $IP_ADDR telah diset ke $INTERFACE${NC}"

# =================== 2. INSTALL DHCP SERVER ===================
echo -e "${YELLOW}==================== INSTALL DHCP SERVER ====================${NC}"
apt update && apt install isc-dhcp-server -y

cat > /etc/dhcp/dhcpd.conf <<EOF
subnet ${IP_ADDR%.*}.0 netmask $NETMASK {
    range ${IP_ADDR%.*}.100 ${IP_ADDR%.*}.200;
    option routers $GATEWAY;
    option domain-name-servers $IP_ADDR, 8.8.8.8;
}
EOF

sed -i "s/INTERFACESv4=\".*\"/INTERFACESv4=\"$INTERFACE\"/" /etc/default/isc-dhcp-server
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server
echo -e "${GREEN}DHCP Server berjalan dengan range ${IP_ADDR%.*}.100 - ${IP_ADDR%.*}.200${NC}"

# =================== 3. SETUP DNS (resolv.conf.local + db.dns + db.ip) ===================
echo -e "${YELLOW}==================== SETUP DNS ====================${NC}"
echo "Contoh domain: smkwikrama.local | IP: $IP_ADDR"
read -p "Masukkan nama domain (contoh: smkwikrama.local): " DOMAIN
read -p "Masukkan IP untuk domain $DOMAIN: " DNS_IP

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

# Konfigurasi named.conf.local
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

# resolv.conf (pakai resolvconf, bukan systemd-resolved)
apt install resolvconf -y
echo "nameserver $DNS_IP" | tee /etc/resolvconf/resolv.conf.d/head
systemctl restart resolvconf
systemctl restart bind9

echo -e "${GREEN}DNS Server untuk $DOMAIN ($DNS_IP) telah aktif${NC}"
echo -e "${YELLOW}Test nslookup:${NC}"
nslookup $DOMAIN localhost
nslookup www.$DOMAIN localhost

# =================== 4. APACHE2 + PHP ===================
echo -e "${YELLOW}==================== INSTALL APACHE2 & PHP ====================${NC}"
apt install apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip -y
systemctl enable apache2
systemctl restart apache2

# Web tutorial SMK Wikrama
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>SMK Wikrama - Web Tutorial</title></head>
<body>
<h1>Selamat Datang di Web Tutorial SMK Wikrama</h1>
<p>Server berjalan di $DOMAIN ($DNS_IP)</p>
<p>Akses melalui: http://$DOMAIN atau http://$DNS_IP</p>
</body>
</html>
EOF

echo -e "${GREEN}Apache2 siap. Buka browser: http://$DOMAIN${NC}"

# =================== 5. WordPress ===================
echo -e "${YELLOW}==================== INSTALL WORDPRESS ====================${NC}"
apt install mariadb-server -y
mysql_secure_installation <<EOF

y
rootpass123
rootpass123
y
y
y
y
EOF

mysql -u root -prootpass123 -e "CREATE DATABASE wordpress;"
mysql -u root -prootpass123 -e "CREATE USER 'wpuser'@'localhost' IDENTIFIED BY 'wppass123';"
mysql -u root -prootpass123 -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';"
mysql -u root -prootpass123 -e "FLUSH PRIVILEGES;"

cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php
sed -i "s/password_here/wppass123/" /var/www/html/wp-config.php
chown -R www-data:www-data /var/www/html/
systemctl restart apache2

echo -e "${GREEN}WordPress siap: http://$DOMAIN/wp-admin${NC}"

# =================== 6. phpMyAdmin ===================
echo -e "${YELLOW}==================== INSTALL phpMyAdmin ====================${NC}"
apt install phpmyadmin -y
echo "Include /etc/phpmyadmin/apache.conf" >> /etc/apache2/apache2.conf
systemctl restart apache2

echo -e "${GREEN}phpMyAdmin: http://$DOMAIN/phpmyadmin (root/rootpass123)${NC}"

# =================== 7. CRUD Sederhana ===================
echo -e "${YELLOW}==================== MEMBUAT CRUD SEDERHANA ====================${NC}"
mysql -u root -prootpass123 -e "CREATE DATABASE crud_db; CREATE TABLE crud_db.users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100), email VARCHAR(100));"

cat > /var/www/html/crud.php <<'EOF'
<?php
$conn = new mysqli("localhost", "root", "rootpass123", "crud_db");
if ($conn->connect_error) die("Koneksi gagal: " . $conn->connect_error);

if ($_SERVER["REQUEST_METHOD"] == "POST") {
    if($_POST['action'] == 'add') $conn->query("INSERT INTO users (name, email) VALUES ('$_POST[name]', '$_POST[email]')");
    if($_POST['action'] == 'delete') $conn->query("DELETE FROM users WHERE id=$_POST[id]");
}
$result = $conn->query("SELECT * FROM users");
?>
<h1>CRUD Sederhana</h1>
<form method="post"><input name="name" placeholder="Nama"><input name="email" placeholder="Email"><button name="action" value="add">Tambah</button></form>
<table border=1><?php while($row=$result->fetch_assoc()){ echo "<tr><td>$row[name]</td><td>$row[email]</td><td><form method=post><input type=hidden name=id value=$row[id]><button name=action value=delete>Hapus</button></form></td></tr>"; } ?></table>
EOF

echo -e "${GREEN}CRUD siap: http://$DOMAIN/crud.php${NC}"

# =================== 8. SSH Remote + SAMBA ===================
echo -e "${YELLOW}==================== SSH & SAMBA ====================${NC}"
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
EOF
systemctl restart smbd

echo -e "${GREEN}SSH aktif. Remote via: ssh root@$IP_ADDR${NC}"
echo -e "${GREEN}Samba share: \\\\$IP_ADDR\\wikrama-share${NC}"

# =================== 9. Clone dari GitHub ke Apache ===================
echo -e "${YELLOW}==================== CLONE GITHUB ====================${NC}"
apt install git -y
cd /tmp
git clone https://github.com/digininja/DVWA.git
cp -r DVWA/* /var/www/html/
chown -R www-data:www-data /var/www/html/
echo -e "${GREEN}Git clone selesai. Akses: http://$DOMAIN/DVWA${NC}"

# =================== 10. DVWA Setup ===================
echo -e "${YELLOW}==================== SETUP DVWA ====================${NC}"
cp /var/www/html/config/config.inc.php.dist /var/www/html/config/config.inc.php
sed -i "s/p@ssw0rd/rootpass123/g" /var/www/html/config/config.inc.php
mysql -u root -prootpass123 -e "CREATE DATABASE dvwa;"
systemctl restart apache2

echo -e "${GREEN}DVWA siap: http://$DOMAIN/setup.php (login admin/password)${NC}"

# =================== FINISH ===================
echo -e "${GREEN}==================== SEMUA PROSES SELESAI ====================${NC}"
echo -e "${YELLOW}RINGKASAN AKSES:${NC}"
echo "1. Website Utama        : http://$DOMAIN atau http://$DNS_IP"
echo "2. WordPress Admin      : http://$DOMAIN/wp-admin"
echo "3. phpMyAdmin           : http://$DOMAIN/phpmyadmin (root/rootpass123)"
echo "4. CRUD                 : http://$DOMAIN/crud.php"
echo "5. DVWA                 : http://$DOMAIN/DVWA"
echo "6. Samba Share          : \\\\$IP_ADDR\\wikrama-share"
echo "7. SSH Remote           : ssh root@$IP_ADDR"
echo -e "${GREEN}Test nslookup: nslookup $DOMANA $DNS_IP${NC}"
