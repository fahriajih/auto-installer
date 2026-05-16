#!/bin/bash

# ============================================================
#   FAHTECH - ULTIMATE FULL AUTO INSTALLER v24.0
#   4 DNS SERVER + DHCP + FTP + SAMBA + MAIL + APACHE2
#   + WORDPRESS + CRUD + WEBMAIL + ZABBIX (14 SERVICES)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                              ║"
echo "║   ███████╗ █████╗ ██╗  ██╗████████╗███████╗ ██████╗██╗  ██╗                 ║"
echo "║   ██╔════╝██╔══██╗██║  ██║╚══██╔══╝██╔════╝██╔════╝██║  ██║                 ║"
echo "║   █████╗  ███████║███████║   ██║   █████╗  ██║     ███████║                 ║"
echo "║   ██╔══╝  ██╔══██║██╔══██║   ██║   ██╔══╝  ██║     ██╔══██║                 ║"
echo "║   ██║     ██║  ██║██║  ██║   ██║   ███████╗╚██████╗██║  ██║                 ║"
echo "║   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝                 ║"
echo "║                                                                              ║"
echo "║              ULTIMATE FULL AUTO INSTALLER v24.0                             ║"
echo "║   4 DNS + DHCP + FTP + SAMBA + MAIL + APACHE2 + WP + CRUD + ZABBIX          ║"
echo "║                         14 SERVICES LENGKAP                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Jalankan sebagai root!${NC}"
    exit 1
fi

SERVER_IP=$(hostname -I | awk '{print $1}')

detect_interfaces() {
    INTERFACES=()
    for iface in $(ls /sys/class/net/ | grep -v lo); do
        IP=$(ip -4 addr show $iface 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
        if [[ -n $IP ]]; then
            INTERFACES+=("$iface|$IP")
        fi
    done
}

show_interfaces() {
    detect_interfaces
    echo -e "\n${GREEN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│                    📡 NETWORK INTERFACE                      │${NC}"
    echo -e "${GREEN}├─────┬─────────────────────┬─────────────────────────────────┤${NC}"
    printf "${GREEN}│${NC} ${WHITE}No${NC} │ ${WHITE}Interface${NC}          │ ${WHITE}IP Address${NC}                       │\n"
    echo -e "${GREEN}├─────┼─────────────────────┼─────────────────────────────────┤${NC}"
    for i in "${!INTERFACES[@]}"; do
        IFS='|' read -r iface ip <<< "${INTERFACES[$i]}"
        printf "${GREEN}│${NC} ${YELLOW}%2d${NC} │ ${CYAN}%-19s${NC} │ ${GREEN}%-31s${NC} │\n" "$((i+1))" "$iface" "$ip"
    done
    echo -e "${GREEN}└─────┴─────────────────────┴─────────────────────────────────┘${NC}"
}

# ======================= FIX DNS RESOLVER =======================
fix_dns_resolver() {
    echo -e "${YELLOW}🔧 Memperbaiki DNS resolver...${NC}"
    cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    apt install -y resolvconf 2>/dev/null
    echo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
    echo "nameserver 8.8.4.4" >> /etc/resolvconf/resolv.conf.d/head
    systemctl restart resolvconf 2>/dev/null
}

# ======================= 1. APACHE2 (PILIH IP) =======================
install_apache2() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              🌍 INSTALL APACHE2                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih IP untuk Apache2 (pilih nomor interface):${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice
    
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r APACHE_IFACE APACHE_IP <<< "${INTERFACES[$((choice-1))]}"
        echo -e "${GREEN}✅ Menggunakan IP: $APACHE_IP (Interface: $APACHE_IFACE)${NC}"
    else
        APACHE_IP=$SERVER_IP
        echo -e "${YELLOW}⚠️ Menggunakan IP default: $APACHE_IP${NC}"
    fi
    
    apt update -qq
    apt install -y apache2 php libapache2-mod-php php-mysql php-sqlite3 php-curl php-gd php-xml php-mbstring php-zip wget curl unzip
    
    cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>FahTech Ultimate Server</title>
<style>
body{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);font-family:Arial;text-align:center;padding:50px}
h1{color:white;font-size:48px}
.status{background:#4CAF50;padding:10px;border-radius:10px;color:white}
.services{display:grid;grid-template-columns:repeat(4,1fr);gap:15px;margin-top:30px}
.service{background:white;padding:15px;border-radius:10px}
@media (max-width:600px){.services{grid-template-columns:repeat(2,1fr)}}
</style>
</head>
<body>
<h1>⚡ FAHTECH ULTIMATE SERVER ⚡</h1>
<div class="status">✅ ALL SERVICES RUNNING</div>
<p style="color:white;">Server IP: <?php echo \$_SERVER['SERVER_ADDR']; ?></p>
<div class="services">
<div class="service">🌐 Apache2</div><div class="service">📧 Mail</div>
<div class="service">📝 WordPress</div><div class="service">🗄️ CRUD</div>
<div class="service">🌍 Webmail</div><div class="service">📁 FTP</div>
<div class="service">🖥️ Samba</div><div class="service">📊 Zabbix</div>
</div>
<p style="color:white;">Powered by FahTech Ultimate Installer v24.0</p>
</body>
</html>
EOF
    
    systemctl restart apache2
    echo -e "\n${GREEN}✅ APACHE2 BERHASIL! Akses: http://$APACHE_IP${NC}"
    read -p "Tekan Enter..."
}

# ======================= 2. DHCP SERVER (PILIH INTERFACE) =======================
install_dhcp() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              🌐 INSTALL DHCP SERVER            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih interface untuk DHCP Server:${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice
    
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r SELECTED_IFACE SELECTED_IP <<< "${INTERFACES[$((choice-1))]}"
        SUBNET=$(echo $SELECTED_IP | cut -d. -f1-3).0
        GATEWAY=$(echo $SELECTED_IP | cut -d. -f1-3).1
        RANGE_START=$(echo $SELECTED_IP | cut -d. -f1-3).100
        RANGE_END=$(echo $SELECTED_IP | cut -d. -f1-3).200
        
        apt install -y isc-dhcp-server
        echo "INTERFACESv4=\"$SELECTED_IFACE\"" > /etc/default/isc-dhcp-server
        cat > /etc/dhcp/dhcpd.conf <<EOF
subnet $SUBNET netmask 255.255.255.0 {
    range $RANGE_START $RANGE_END;
    option routers $GATEWAY;
    option domain-name-servers 8.8.8.8;
}
EOF
        systemctl restart isc-dhcp-server
        systemctl enable isc-dhcp-server
        
        echo -e "\n${GREEN}✅ DHCP BERHASIL!${NC}"
        echo -e "   📡 Interface: $SELECTED_IFACE"
        echo -e "   🌐 Subnet: $SUBNET/24"
        echo -e "   📊 Range: $RANGE_START - $RANGE_END"
    fi
    read -p "Tekan Enter..."
}

# ======================= 3. DNS SERVER (4 DOMAIN) =======================
install_dns() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              🔍 INSTALL DNS SERVER (4 DOMAIN)                    ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    declare -a DOMAINS=()
    declare -a IPS=()
    declare -a IFACES=()
    
    for dns_num in 1 2 3 4; do
        echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}  📍 DNS SERVER $dns_num${NC}"
        show_interfaces
        echo -e "\n${YELLOW}👉 Pilih interface untuk DNS $dns_num:${NC}"
        read -p "Nomor: " choice
        if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
            IFS='|' read -r IFACE IP <<< "${INTERFACES[$((choice-1))]}"
            echo -e "\n${MAGENTA}📝 Masukkan domain untuk DNS $dns_num:${NC}"
            read -p "Domain: " DOMAIN
            DOMAINS+=("$DOMAIN")
            IPS+=("$IP")
            IFACES+=("$IFACE")
        else
            echo -e "${RED}❌ Pilihan tidak valid!${NC}"
            return
        fi
    done
    
    fix_dns_resolver
    
    # Bersihkan DNS lama
    systemctl stop bind9 2>/dev/null
    apt remove --purge -y bind9 bind9utils 2>/dev/null
    rm -rf /etc/bind
    
    # Install DNS
    apt install -y bind9 bind9utils
    mkdir -p /etc/bind /var/lib/bind /var/cache/bind
    chown -R bind:bind /var/lib/bind /var/cache/bind
    
    # Konfigurasi named.conf.local
    cat > /etc/bind/named.conf.local <<EOF
EOF
    
    for i in "${!DOMAINS[@]}"; do
        cat >> /etc/bind/named.conf.local <<EOF
zone "${DOMAINS[$i]}" {
    type master;
    file "/etc/bind/db.${DOMAINS[$i]}";
};
EOF
        
        cat > /etc/bind/db.${DOMAINS[$i]} <<EOF
\$TTL    604800
@       IN      SOA     ns1.${DOMAINS[$i]}. admin.${DOMAINS[$i]}. (
                  2026051601         ; Serial
                  604800         ; Refresh
                  86400         ; Retry
                  2419200        ; Expire
                  604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.${DOMAINS[$i]}.
@       IN      A       ${IPS[$i]}
ns1     IN      A       ${IPS[$i]}
www     IN      A       ${IPS[$i]}
mail    IN      A       ${IPS[$i]}
EOF
    done
    
    cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    forwarders { 8.8.8.8; 8.8.4.4; };
    listen-on { any; };
};
EOF
    
    systemctl unmask bind9 2>/dev/null
    systemctl start bind9
    systemctl enable bind9
    
    echo -e "\n${GREEN}✅ 4 DNS SERVER BERHASIL!${NC}"
    for i in "${!DOMAINS[@]}"; do
        echo -e "   📝 ${DOMAINS[$i]} -> ${IPS[$i]} (${IFACES[$i]})"
    done
    read -p "Tekan Enter..."
}

# ======================= 4. FTP SERVER =======================
install_ftp() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              📁 INSTALL FTP SERVER             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    apt install -y vsftpd
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    echo -e "\n${GREEN}✅ FTP BERHASIL! Akses: ftp://$SERVER_IP${NC}"
    read -p "Tekan Enter..."
}

# ======================= 5. SAMBA (PILIH SHARE NAME) =======================
install_samba() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              🖥️ INSTALL SAMBA                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    read -p "📝 Nama Share (Enter untuk 'public'): " share_name
    share_name=${share_name:-public}
    
    apt install -y samba
    mkdir -p /home/share
    chmod 777 /home/share
    
    cat >> /etc/samba/smb.conf <<EOF
[$share_name]
   path = /home/share
   browseable = yes
   writable = yes
   guest ok = yes
   create mask = 0777
EOF
    
    systemctl restart smbd
    systemctl enable smbd
    
    echo -e "\n${GREEN}✅ SAMBA BERHASIL! Akses: \\\\$SERVER_IP\\$share_name${NC}"
    read -p "Tekan Enter..."
}

# ======================= 6. MAIL SERVER (PILIH DOMAIN & USER) =======================
install_mail() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              📧 INSTALL MAIL SERVER            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih IP untuk Mail Server:${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r MAIL_IFACE MAIL_IP <<< "${INTERFACES[$((choice-1))]}"
    else
        MAIL_IP=$SERVER_IP
    fi
    
    echo -e "\n${CYAN}📝 Masukkan domain untuk email:${NC}"
    read -p "Domain (contoh: fahtech.com): " DOMAIN_UTAMA
    
    echo -e "\n${CYAN}📝 Buat akun email admin:${NC}"
    read -p "Username: " EMAIL_USER
    EMAIL_USER=${EMAIL_USER:-admin}
    read -s -p "Password: " EMAIL_PASS
    echo ""
    EMAIL_PASS=${EMAIL_PASS:-admin123}
    
    MAIL_DOMAIN="mail.$DOMAIN_UTAMA"
    hostnamectl set-hostname $MAIL_DOMAIN
    echo "$MAIL_IP $MAIL_DOMAIN" >> /etc/hosts
    
    apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d mailutils
    
    postconf -e "myhostname = $MAIL_DOMAIN"
    postconf -e "mydomain = $DOMAIN_UTAMA"
    postconf -e "myorigin = \$mydomain"
    postconf -e "inet_interfaces = all"
    postconf -e "home_mailbox = Maildir/"
    postconf -e "smtpd_sasl_type = dovecot"
    postconf -e "smtpd_sasl_path = private/auth"
    postconf -e "smtpd_sasl_auth_enable = yes"
    
    rm -rf /etc/dovecot 2>/dev/null
    cat > /etc/dovecot/dovecot.conf <<EOF
disable_plaintext_auth = no
mail_privileged_group = mail
mail_location = maildir:~/Maildir
passdb { driver = passwd-file args = scheme=PLAIN /etc/dovecot/users }
userdb { driver = passwd }
protocols = imap pop3
service auth { unix_listener /var/spool/postfix/private/auth { mode = 0660 user = postfix group = postfix } }
ssl = no
EOF
    
    mkdir -p /etc/dovecot
    echo "$EMAIL_USER@$DOMAIN_UTAMA:$EMAIL_PASS" > /etc/dovecot/users
    chmod 600 /etc/dovecot/users
    useradd -m -s /bin/false $EMAIL_USER 2>/dev/null
    echo "$EMAIL_USER:$EMAIL_PASS" | chpasswd
    mkdir -p /home/$EMAIL_USER/Maildir/{cur,new,tmp}
    chown -R $EMAIL_USER:$EMAIL_USER /home/$EMAIL_USER/Maildir
    
    systemctl restart postfix dovecot
    systemctl enable postfix dovecot
    
    echo "$DOMAIN_UTAMA" > /etc/maildomain.conf
    echo "$MAIL_IP" > /etc/mailip.conf
    echo "$EMAIL_USER" > /etc/mailuser.conf
    echo "$EMAIL_PASS" > /etc/mailpass.conf
    
    echo -e "\n${GREEN}✅ MAIL SERVER BERHASIL!${NC}"
    echo -e "   📧 Email: $EMAIL_USER@$DOMAIN_UTAMA"
    echo -e "   🔑 Password: $EMAIL_PASS"
    read -p "Tekan Enter..."
}

# ======================= 7. WEBMAIL =======================
install_webmail() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🌐 INSTALL WEBMAIL (ROUNDCUBE)         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    if [[ ! -f /etc/maildomain.conf ]]; then
        echo -e "\n${RED}❌ Mail Server belum diinstall!${NC}"
        read -p "Tekan Enter..."
        return
    fi
    
    DOMAIN_UTAMA=$(cat /etc/maildomain.conf)
    MAIL_IP=$(cat /etc/mailip.conf)
    EMAIL_USER=$(cat /etc/mailuser.conf 2>/dev/null)
    EMAIL_PASS=$(cat /etc/mailpass.conf 2>/dev/null)
    
    apt remove --purge -y roundcube* php-roundcube* dbconfig-common 2>/dev/null
    rm -rf /etc/roundcube /var/lib/roundcube /usr/share/roundcube
    apt install -y roundcube roundcube-mysql roundcube-core php-mysql
    
    DB_PASS="rcube123"
    mysql -u root <<MYSQL 2>/dev/null
DROP DATABASE IF EXISTS roundcubemail;
CREATE DATABASE roundcubemail;
CREATE USER IF NOT EXISTS 'roundcube'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON roundcubemail.* TO 'roundcube'@'localhost';
FLUSH PRIVILEGES;
MYSQL
    
    mysql roundcubemail < /usr/share/roundcube/SQL/mysql.initial.sql 2>/dev/null
    
    cat > /etc/roundcube/config.inc.php <<PHP
<?php \$config = []; \$config['db_dsnw'] = 'mysql://roundcube:rcube123@localhost/roundcubemail'; \$config['default_host'] = 'localhost'; \$config['smtp_server'] = 'localhost'; \$config['smtp_port'] = 25; \$config['smtp_user'] = '%u'; \$config['smtp_pass'] = '%p'; \$config['product_name'] = 'FahTech Webmail - $DOMAIN_UTAMA'; \$config['plugins'] = ['archive', 'zipdownload']; \$config['skin'] = 'elastic';
PHP
    
    cat > /etc/apache2/conf-available/roundcube.conf <<APACHE
Alias /roundcube /usr/share/roundcube
<Directory /usr/share/roundcube/> Options +FollowSymLinks AllowOverride All Require all granted </Directory>
APACHE
    
    a2enconf roundcube
    a2enmod rewrite
    systemctl restart apache2 postfix dovecot
    
    echo -e "\n${GREEN}✅ WEBMAIL BERHASIL! Akses: http://$MAIL_IP/roundcube/${NC}"
    echo -e "   📧 Login: $EMAIL_USER@$DOMAIN_UTAMA / $EMAIL_PASS"
    read -p "Tekan Enter..."
}

# ======================= 8. WORDPRESS (PILIH IP) =======================
install_wordpress() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              📝 INSTALL WORDPRESS              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih IP untuk WordPress:${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r WP_IFACE WP_IP <<< "${INTERFACES[$((choice-1))]}"
    else
        WP_IP=$SERVER_IP
    fi
    
    apt install -y mariadb-server
    systemctl restart mariadb
    
    DB_PASS=$(openssl rand -base64 12 | tr -d "=/+" | cut -c1-16)
    
    mysql -u root <<MYSQL_SCRIPT 2>/dev/null
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
    
    echo -e "\n${GREEN}✅ WORDPRESS BERHASIL! Akses: http://$WP_IP/wp-admin/install.php${NC}"
    echo -e "${YELLOW}   🔑 DB Password: $DB_PASS${NC}"
    read -p "Tekan Enter..."
}

# ======================= 9. CRUD SISWA (PILIH IP) =======================
install_crud() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🗄️ INSTALL CRUD SISWA                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih IP untuk CRUD Siswa:${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r CRUD_IFACE CRUD_IP <<< "${INTERFACES[$((choice-1))]}"
    else
        CRUD_IP=$SERVER_IP
    fi
    
    apt install -y php-sqlite3
    mkdir -p /var/www/html/crud
    
    cat > /var/www/html/crud/index.php <<'PHP'
<!DOCTYPE html>
<html>
<head><title>CRUD Siswa</title>
<style>
body{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);font-family:Arial;padding:40px}
.container{max-width:800px;margin:auto;background:#fff;border-radius:20px;padding:30px}
h1{color:#667eea}
input,button{padding:10px;margin:5px;border-radius:5px}
button{background:#667eea;color:#fff;border:none;cursor:pointer}
table{width:100%;border-collapse:collapse}
th,td{padding:10px;text-align:left;border-bottom:1px solid #ddd}
th{background:#667eea;color:#fff}
.delete-btn{background:#e74c3c;color:#fff;padding:5px 10px;text-decoration:none;border-radius:5px}
.edit-btn{background:#3498db;color:#fff;padding:5px 10px;text-decoration:none;border-radius:5px}
</style>
</head>
<body>
<div class="container">
<h1>📚 CRUD Data Siswa</h1>
<?php
$db=new SQLite3('/var/www/html/crud/siswa.db');
$db->exec("CREATE TABLE IF NOT EXISTS siswa (id INTEGER PRIMARY KEY, nama TEXT, rombel TEXT, nis TEXT)");
if(isset($_POST['add'])){$db->exec("INSERT INTO siswa (nama,rombel,nis) VALUES ('".$_POST['nama']."','".$_POST['rombel']."','".$_POST['nis']."')");}
if(isset($_GET['delete'])){$db->exec("DELETE FROM siswa WHERE id=".(int)$_GET['delete']);}
if(isset($_POST['update'])){$db->exec("UPDATE siswa SET nama='".$_POST['nama']."',rombel='".$_POST['rombel']."',nis='".$_POST['nis']."' WHERE id=".(int)$_POST['id']);}
$res=$db->query("SELECT * FROM siswa");
?>
<form method="post">
<input type="text" name="nama" placeholder="Nama" required>
<input type="text" name="rombel" placeholder="Rombel" required>
<input type="text" name="nis" placeholder="NIS" required>
<button type="submit" name="add">Tambah</button>
</form>
<h3>Daftar Siswa</h3>
<table border="1" cellpadding="10">
<tr><th>Nama</th><th>Rombel</th><th>NIS</th><th>Aksi</th></tr>
<?php while($row=$res->fetchArray()){echo "<tr><td>".$row['nama']."</td><td>".$row['rombel']."</td><td>".$row['nis']."</td><td><a class='edit-btn' href='?edit=".$row['id']."'>Edit</a> <a class='delete-btn' href='?delete=".$row['id']."'>Hapus</a></td></tr>";}?>
</table>
<?php if(isset($_GET['edit'])){$id=(int)$_GET['edit'];$edit=$db->query("SELECT * FROM siswa WHERE id=$id")->fetchArray();if($edit){?>
<h3>Edit Data</h3>
<form method="post"><input type="hidden" name="id" value="<?=$edit['id']?>"><input type="text" name="nama" value="<?=$edit['nama']?>"><input type="text" name="rombel" value="<?=$edit['rombel']?>"><input type="text" name="nis" value="<?=$edit['nis']?>"><button type="submit" name="update">Update</button></form>
<?php }?>
</div>
</body>
</html>
PHP
    
    chown -R www-data:www-data /var/www/html/crud
    systemctl restart apache2
    
    echo -e "\n${GREEN}✅ CRUD SISWA BERHASIL! Akses: http://$CRUD_IP/crud/${NC}"
    read -p "Tekan Enter..."
}

# ======================= 10. ZABBIX SERVER (VERSI STABLE) =======================
install_zabbix() {
    clear
    echo -e "${MAGENTA}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║              📊 INSTALL ZABBIX SERVER          ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════╝${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih IP untuk Zabbix:${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r ZABBIX_IFACE ZABBIX_IP <<< "${INTERFACES[$((choice-1))]}"
    else
        ZABBIX_IP=$SERVER_IP
    fi
    
    # Install Zabbix repository (versi 6.0 LTS yang lebih stabil)
    wget -q https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_6.0-4+debian12_all.deb
    dpkg -i zabbix-release_6.0-4+debian12_all.deb
    apt update -qq
    
    # Install Zabbix server and frontend
    apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
    
    # Install database
    mysql -u root <<MYSQL 2>/dev/null
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY 'zabbix123';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
MYSQL
    
    # Import Zabbix database schema
    if [ -f /usr/share/zabbix-sql-scripts/mysql/server.sql.gz ]; then
        zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u root zabbix 2>/dev/null
    fi
    
    # Configure Zabbix server
    sed -i "s/# DBPassword=/DBPassword=zabbix123/" /etc/zabbix/zabbix_server.conf
    
    # Configure PHP timezone
    if [ -f /etc/zabbix/apache.conf ]; then
        sed -i "s/# php_value date.timezone Europe\/Riga/php_value date.timezone Asia\/Jakarta/" /etc/zabbix/apache.conf
    fi
    
    # Start Zabbix services
    systemctl restart zabbix-server zabbix-agent apache2 2>/dev/null
    systemctl enable zabbix-server zabbix-agent 2>/dev/null
    
    rm -f zabbix-release_6.0-4+debian12_all.deb
    
    echo -e "\n${GREEN}✅ ZABBIX SERVER BERHASIL!${NC}"
    echo -e "   🌐 Akses: http://$ZABBIX_IP/zabbix/"
    echo -e "   📝 Login default: ${YELLOW}Admin / zabbix${NC}"
    echo -e "   ⚠️  Password wajib diubah saat pertama login"
    read -p "Tekan Enter..."
}

# ======================= 11. INSTALL SEMUA =======================
install_all() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         ⚡ INSTALL SEMUA SERVICE LENGKAP       ║${NC}"
    echo -e "${GREEN}║   WAKTU INSTALASI: 30-45 MENIT                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}⚠️ Proses akan memakan waktu 30-45 menit. Lanjutkan? (y/n):${NC}"
    read confirm
    if [[ "$confirm" == "y" ]]; then
        fix_dns_resolver
        install_apache2
        install_dhcp
        install_dns
        install_ftp
        install_samba
        install_mail
        install_webmail
        install_wordpress
        install_crud
        install_zabbix
        
        DOMAIN_UTAMA=$(cat /etc/maildomain.conf 2>/dev/null || echo "domain-anda.com")
        EMAIL_USER=$(cat /etc/mailuser.conf 2>/dev/null || echo "admin")
        EMAIL_PASS=$(cat /etc/mailpass.conf 2>/dev/null || echo "admin123")
        
        echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}   🎉 SEMUA SERVICE BERHASIL DIINSTALL! 🎉                                    ║${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════║${NC}"
        echo -e "${GREEN}                                                                             ║${NC}"
        echo -e "${GREEN}   🌐 LANDING PAGE:  http://$SERVER_IP                                       ║${NC}"
        echo -e "${GREEN}   📚 CRUD:          http://$SERVER_IP/crud/                                ║${NC}"
        echo -e "${GREEN}   📧 WEBMAIL:       http://$SERVER_IP/roundcube/                           ║${NC}"
        echo -e "${GREEN}   📝 WORDPRESS:     http://$SERVER_IP/wp-admin                             ║${NC}"
        echo -e "${GREEN}   📁 FTP:           ftp://$SERVER_IP                                       ║${NC}"
        echo -e "${GREEN}   🖥️ SAMBA:         \\\\$SERVER_IP\\public                                   ║${NC}"
        echo -e "${GREEN}   📊 ZABBIX:        http://$SERVER_IP/zabbix/ (Admin/zabbix)              ║${NC}"
        echo -e "${GREEN}                                                                             ║${NC}"
        echo -e "${GREEN}   📧 LOGIN WEBMAIL: $EMAIL_USER@$DOMAIN_UTAMA / $EMAIL_PASS                ║${NC}"
        echo -e "${GREEN}                                                                             ║${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════╝${NC}"
    fi
    read -p "Tekan Enter..."
}

# ======================= CEK STATUS =======================
check_status() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              📊 CEK STATUS SERVICE             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    services=("apache2" "bind9" "isc-dhcp-server" "vsftpd" "smbd" "postfix" "dovecot" "mariadb" "zabbix-server")
    names=("🌍 Apache2" "🔍 DNS Server" "🌐 DHCP Server" "📁 FTP Server" "🖥️ Samba" "📧 Postfix" "📧 Dovecot" "🗄️ MariaDB" "📊 Zabbix")
    
    for i in "${!services[@]}"; do
        if systemctl is-active --quiet ${services[$i]}; then
            echo -e "  ${names[$i]} | ${GREEN}✅ ACTIVE${NC}"
        else
            echo -e "  ${names[$i]} | ${RED}❌ INACTIVE${NC}"
        fi
    done
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ -f /etc/bind/named.conf.local ]]; then
        echo -e "\n📋 DNS ZONES TERDAFTAR:"
        grep -E "zone.*{" /etc/bind/named.conf.local 2>/dev/null | sed 's/zone/  📝/g' | sed 's/ {//g'
    fi
    
    read -p "Tekan Enter..."
}

# ======================= HAPUS SEMUA =======================
uninstall_all() {
    clear
    echo -e "${RED}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              🗑️ HAPUS SEMUA SERVICE            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${YELLOW}⚠️ Yakin akan menghapus SEMUA service? (y/n):${NC}"
    read confirm
    if [[ "$confirm" == "y" ]]; then
        systemctl stop apache2 bind9 isc-dhcp-server vsftpd smbd postfix dovecot mariadb zabbix-server 2>/dev/null
        apt remove --purge -y apache2* bind9* isc-dhcp-server* vsftpd* samba* postfix* dovecot* mariadb* mysql* roundcube* wordpress* zabbix* 2>/dev/null
        rm -rf /etc/apache2 /etc/bind /etc/dhcp /etc/postfix /etc/dovecot /etc/samba /var/www/html /var/lib/mysql /etc/zabbix
        rm -rf /etc/roundcube /var/lib/roundcube /usr/share/roundcube /home/share /home/*/Maildir
        rm -rf /etc/maildomain.conf /etc/mailip.conf /etc/mailuser.conf /etc/mailpass.conf
        apt autoremove --purge -y
        echo -e "\n${GREEN}✅ SEMUA SERVICE DAN FOLDER BERHASIL DIHAPUS!${NC}"
    fi
    read -p "Tekan Enter..."
}

# ======================= MENU UTAMA =======================
while true; do
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║            🚀 FAHTECH ULTIMATE FULL AUTO INSTALLER v24.0                   ║"
    echo "║       4 DNS + DHCP + FTP + SAMBA + MAIL + APACHE2 + WP + CRUD + ZABBIX     ║"
    echo "╠════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                             ║"
    echo "║  1.  ⚡ INSTALL SEMUA SERVICE (30-45 menit) - REKOMENDED                    ║"
    echo "║  2.  🌍 Install Apache2 (Pilih IP)                                         ║"
    echo "║  3.  🌐 Install DHCP Server (Pilih Interface)                              ║"
    echo "║  4.  🔍 Install DNS Server (4 Domain - Pilih Interface & Domain)           ║"
    echo "║  5.  📁 Install FTP Server                                                 ║"
    echo "║  6.  🖥️ Install Samba (Pilih Nama Share)                                   ║"
    echo "║  7.  📧 Install Mail Server + Webmail (Pilih IP, Domain, User)             ║"
    echo "║  8.  📝 Install WordPress (Pilih IP)                                       ║"
    echo "║  9.  🗄️ Install CRUD Siswa (Pilih IP)                                      ║"
    echo "║  10. 📊 Install Zabbix Server (Pilih IP)                                   ║"
    echo "║  11. 📊 Cek Status Service                                                 ║"
    echo "║  12. 🗑️ Hapus SEMUA Service + Folder                                       ║"
    echo "║  13. 🚪 Exit                                                               ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "👉 Pilih menu [1-13]: " menu
    
    case $menu in
        1) install_all ;;
        2) install_apache2 ;;
        3) install_dhcp ;;
        4) install_dns ;;
        5) install_ftp ;;
        6) install_samba ;;
        7) 
            install_mail
            install_webmail
            ;;
        8) install_wordpress ;;
        9) install_crud ;;
        10) install_zabbix ;;
        11) check_status ;;
        12) uninstall_all ;;
        13) 
            echo -e "${GREEN}👋 Terima kasih!${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}❌ Pilihan salah!${NC}"
            sleep 1
            ;;
    esac
done
