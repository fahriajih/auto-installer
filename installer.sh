#!/bin/bash

# ======================================================
# FINAL INSTALLER - FAHRITECH SMK WIKRAMA
# ======================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variabel
INTERFACE=""
IP_ADDR=""
DOMAIN=""
DNS_IP=""

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Script ini harus dijalankan sebagai root!${NC}"
   exit 1
fi

# =================== BANNER ===================
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    FAHRITECH AUTO INSTALLER                          ║"
    echo "║                   SMK WIKRAMA - FULL VERSION                         ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    sleep 1
}

# =================== VALIDASI IP ===================
validate_ip() {
    [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0 || return 1
}

# =================== MENU 1: SETTING IP (SIMPLIFIED) ===================
menu_set_ip() {
    echo -e "${BLUE}══════════════════ 1. SETTING IP ADDRESS ══════════════════${NC}"
    
    # Tampilkan interface
    echo -e "${GREEN}Pilih interface:${NC}"
    interfaces=($(ip link show | grep -E '^[0-9]+: ens|eth' | awk -F': ' '{print $2}' | cut -d'@' -f1))
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        interfaces=($(ip link show | grep -E '^[0-9]+:' | grep -v lo | awk -F': ' '{print $2}' | cut -d'@' -f1 | head -2))
    fi
    
    for i in "${!interfaces[@]}"; do
        echo "  ${CYAN}$((i+1)))${NC} ${interfaces[$i]}"
    done
    
    read -p "Masukkan nomor interface: " pilih_interface
    INTERFACE="${interfaces[$((pilih_interface-1))]}"
    
    echo -e "${YELLOW}Contoh IP: 192.168.1.10, 192.168.27.50, 10.10.10.5${NC}"
    while true; do
        read -p "Masukkan IP untuk $INTERFACE: " IP_ADDR
        validate_ip "$IP_ADDR" && break || echo -e "${RED}Format IP salah!${NC}"
    done
    
    # Otomatis
    NETMASK="255.255.255.0"
    subnet=$(echo $IP_ADDR | cut -d'.' -f1-3)
    GATEWAY="${subnet}.1"
    
    # Hidupkan interface
    ip link set $INTERFACE up
    ip addr flush dev $INTERFACE 2>/dev/null
    ip addr add $IP_ADDR/24 dev $INTERFACE
    ip route add default via $GATEWAY 2>/dev/null
    
    # Simpan konfigurasi
    cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDR
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers 8.8.8.8 8.8.4.4
EOF
    
    systemctl restart networking 2>/dev/null || service networking restart 2>/dev/null
    
    echo ""
    echo -e "${GREEN}✅ IP $IP_ADDR berhasil diset ke $INTERFACE${NC}"
    echo -e "${GREEN}✅ Netmask: $NETMASK${NC}"
    echo -e "${GREEN}✅ Gateway: $GATEWAY${NC}"
}

# =================== MENU 2: DHCP ===================
menu_set_dhcp() {
    echo -e "${BLUE}══════════════════ 2. SETUP DHCP SERVER ══════════════════${NC}"
    
    apt update -qq
    apt install isc-dhcp-server -y
    
    subnet=$(echo $IP_ADDR | cut -d'.' -f1-3)
    GATEWAY="${subnet}.1"
    
    cat > /etc/dhcp/dhcpd.conf <<EOF
subnet ${subnet}.0 netmask 255.255.255.0 {
    range ${subnet}.100 ${subnet}.200;
    option routers $GATEWAY;
    option domain-name-servers $IP_ADDR, 8.8.8.8;
}
EOF
    
    sed -i "s/INTERFACESv4=\".*\"/INTERFACESv4=\"$INTERFACE\"/" /etc/default/isc-dhcp-server
    systemctl restart isc-dhcp-server
    systemctl enable isc-dhcp-server
    
    echo -e "${GREEN}✅ DHCP Server berhasil! Range: ${subnet}.100 - ${subnet}.200${NC}"
}

# =================== MENU 3: DNS ===================
menu_set_dns() {
    echo -e "${BLUE}══════════════════ 3. SETUP DNS SERVER ══════════════════${NC}"
    
    read -p "Masukkan nama domain (contoh: smkwikrama.local): " DOMAIN
    read -p "Masukkan IP untuk domain (contoh: $IP_ADDR): " DNS_IP
    
    apt install bind9 -y
    
    cat > /etc/bind/db.$DOMAIN <<EOF
\$TTL    604800
@       IN      SOA     $DOMAIN. admin.$DOMAIN. ( 2 604800 86400 2419200 604800 )
@       IN      NS      ns1.$DOMAIN.
@       IN      A       $DNS_IP
ns1     IN      A       $DNS_IP
www     IN      A       $DNS_IP
EOF
    
    reverse_ip=$(echo $DNS_IP | awk -F '.' '{print $3"."$2"."$1}')
    last_octet=$(echo $DNS_IP | awk -F '.' '{print $4}')
    
    cat > /etc/bind/db.$reverse_ip <<EOF
\$TTL    604800
@       IN      SOA     $DOMAIN. admin.$DOMAIN. ( 2 604800 86400 2419200 604800 )
@       IN      NS      ns1.$DOMAIN.
$last_octet     IN      PTR     $DOMAIN.
$last_octet     IN      PTR     www.$DOMAIN.
EOF
    
    cat >> /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" { type master; file "/etc/bind/db.$DOMAIN"; };
zone "$reverse_ip.in-addr.arpa" { type master; file "/etc/bind/db.$reverse_ip"; };
EOF
    
    echo "nameserver $DNS_IP" > /etc/resolv.conf
    systemctl restart bind9
    
    echo -e "${GREEN}✅ DNS Server berhasil! Domain: $DOMAIN -> $DNS_IP${NC}"
}

# =================== MENU 4: APACHE & PHP ===================
menu_set_apache() {
    echo -e "${BLUE}══════════════════ 4. INSTALL APACHE2 & PHP ══════════════════${NC}"
    
    apt install apache2 php libapache2-mod-php php-mysql php-curl php-gd php-mbstring php-xml php-zip -y
    systemctl enable apache2
    systemctl restart apache2
    
    echo -e "${GREEN}✅ Apache2 & PHP berhasil diinstall${NC}"
}

# =================== MENU 5: MYSQL ===================
menu_set_mysql() {
    echo -e "${BLUE}══════════════════ 5. INSTALL MYSQL ══════════════════${NC}"
    
    apt install mariadb-server -y
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpass123';" 2>/dev/null
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    echo -e "${GREEN}✅ MySQL berhasil! Password: rootpass123${NC}"
}

# =================== MENU 6: WORDPRESS ===================
menu_set_wordpress() {
    echo -e "${BLUE}══════════════════ 6. INSTALL WORDPRESS ══════════════════${NC}"
    
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS wordpress;" 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE USER IF NOT EXISTS 'wpuser'@'localhost' IDENTIFIED BY 'wppass123';" 2>/dev/null
    mysql -u root -prootpass123 -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';" 2>/dev/null
    
    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    cp -r wordpress/* /var/www/html/
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
    sed -i "s/username_here/wpuser/" /var/www/html/wp-config.php
    sed -i "s/password_here/wppass123/" /var/www/html/wp-config.php
    chown -R www-data:www-data /var/www/html/
    systemctl restart apache2
    
    echo -e "${GREEN}✅ WordPress berhasil!${NC}"
}

# =================== MENU 7: phpMYADMIN ===================
menu_set_phpmyadmin() {
    echo -e "${BLUE}══════════════════ 7. INSTALL phpMyAdmin ══════════════════${NC}"
    
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password rootpass123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password rootpass123" | debconf-set-selections
    apt install phpmyadmin -y
    echo "Include /etc/phpmyadmin/apache.conf" >> /etc/apache2/apache2.conf
    systemctl restart apache2
    
    echo -e "${GREEN}✅ phpMyAdmin berhasil! Login: root / rootpass123${NC}"
}

# =================== MENU 8: WEBSITE & CRUD ===================
menu_set_website() {
    echo -e "${BLUE}══════════════════ 8. WEBSITE UTAMA & CRUD ══════════════════${NC}"
    
    # Database
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS sekolah;" 2>/dev/null
    mysql -u root -prootpass123 -e "CREATE TABLE IF NOT EXISTS sekolah.siswa (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nama VARCHAR(100) NOT NULL,
        nis VARCHAR(20) NOT NULL UNIQUE,
        rombel VARCHAR(50) NOT NULL
    );" 2>/dev/null
    
    # Website Utama
    cat > /var/www/html/index.php << 'EOF_INDEX'
<!DOCTYPE html>
<html>
<head>
    <title>SMK Wikrama - Home</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box;}
        body{font-family:Arial;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;}
        .header{background:white;padding:15px 30px;box-shadow:0 2px 10px rgba(0,0,0,0.1);}
        .header h1{color:#667eea;}
        .nav{display:flex;gap:20px;margin-top:10px;flex-wrap:wrap;}
        .nav a{color:#333;text-decoration:none;padding:8px 15px;border-radius:5px;}
        .nav a:hover{background:#667eea;color:white;}
        .hero{text-align:center;padding:80px 20px;color:white;}
        .hero h1{font-size:48px;margin-bottom:20px;}
        .btn{display:inline-block;background:white;color:#667eea;padding:12px 30px;border-radius:30px;text-decoration:none;font-weight:bold;margin-top:20px;}
        .features{display:flex;justify-content:center;gap:30px;flex-wrap:wrap;padding:50px;background:white;}
        .card{background:#f5f5f5;padding:25px;border-radius:15px;text-align:center;width:200px;cursor:pointer;transition:0.3s;}
        .card:hover{transform:translateY(-5px);box-shadow:0 10px 20px rgba(0,0,0,0.2);}
        .card h3{margin:15px 0 10px;color:#333;}
        .footer{background:#1a1a2e;color:white;text-align:center;padding:20px;}
    </style>
</head>
<body>
    <div class="header">
        <h1>🏫 SMK Wikrama</h1>
        <div class="nav">
            <a href="index.php">🏠 Home</a>
            <a href="crud_siswa.php">📋 CRUD Siswa</a>
            <a href="wp-admin">📝 WordPress</a>
            <a href="phpmyadmin">🗄️ phpMyAdmin</a>
        </div>
    </div>
    <div class="hero">
        <h1>Selamat Datang di Web Tutorial</h1>
        <p>SMK Wikrama - Belajar Server dan Web Development</p>
        <a href="crud_siswa.php" class="btn">✨ Mulai CRUD Siswa ✨</a>
    </div>
    <div class="features">
        <div class="card" onclick="location.href='crud_siswa.php'"><div style="font-size:40px;">📋</div><h3>CRUD Siswa</h3><p>Kelola Nama, NIS, Rombel</p></div>
        <div class="card" onclick="location.href='wp-admin'"><div style="font-size:40px;">📝</div><h3>WordPress</h3><p>Blog CMS</p></div>
        <div class="card" onclick="location.href='phpmyadmin'"><div style="font-size:40px;">🗄️</div><h3>phpMyAdmin</h3><p>Manajemen Database</p></div>
    </div>
    <div class="footer"><p>© 2025 SMK Wikrama - Web Tutorial Server | FAHRITECH</p></div>
</body>
</html>
EOF_INDEX

    # CRUD SISWA
    cat > /var/www/html/crud_siswa.php << 'EOF_CRUD'
<?php
$conn = new mysqli("localhost", "root", "rootpass123", "sekolah");
if ($conn->connect_error) die("Koneksi gagal: " . $conn->connect_error);

if (isset($_POST['tambah'])) {
    $conn->query("INSERT INTO siswa (nama, nis, rombel) VALUES ('$_POST[nama]', '$_POST[nis]', '$_POST[rombel]')");
    $pesan = "✅ Data ditambahkan!";
}
if (isset($_POST['update'])) {
    $conn->query("UPDATE siswa SET nama='$_POST[nama]', nis='$_POST[nis]', rombel='$_POST[rombel]' WHERE id=$_POST[id]");
    $pesan = "✅ Data diupdate!";
}
if (isset($_GET['hapus'])) {
    $conn->query("DELETE FROM siswa WHERE id=$_GET[hapus]");
    $pesan = "✅ Data dihapus!";
}

$edit = null;
if (isset($_GET['edit'])) {
    $result = $conn->query("SELECT * FROM siswa WHERE id=$_GET[edit]");
    $edit = $result->fetch_assoc();
}
$data = $conn->query("SELECT * FROM siswa ORDER BY id DESC");
?>
<!DOCTYPE html>
<html>
<head>
    <title>CRUD Siswa - SMK Wikrama</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box;}
        body{font-family:Arial;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;padding:30px;}
        .container{max-width:1200px;margin:0 auto;}
        h1{text-align:center;color:white;margin-bottom:30px;}
        .card{background:white;border-radius:10px;padding:25px;margin-bottom:30px;box-shadow:0 5px 20px rgba(0,0,0,0.2);}
        .card h2{margin-bottom:20px;color:#667eea;}
        .form-group{margin-bottom:15px;}
        .form-group input{width:100%;padding:10px;border:1px solid #ddd;border-radius:5px;}
        button{background:linear-gradient(135deg,#667eea,#764ba2);color:white;border:none;padding:10px 20px;border-radius:5px;cursor:pointer;}
        table{width:100%;border-collapse:collapse;}
        th,td{padding:12px;text-align:left;border-bottom:1px solid #ddd;}
        th{background:linear-gradient(135deg,#667eea,#764ba2);color:white;}
        .btn-edit{background:#ffc107;color:#333;padding:5px 10px;border-radius:5px;text-decoration:none;}
        .btn-hapus{background:#dc3545;color:white;padding:5px 10px;border-radius:5px;text-decoration:none;}
        .btn-batal{background:#6c757d;color:white;padding:5px 10px;border-radius:5px;text-decoration:none;margin-left:10px;}
        .alert{padding:12px;border-radius:5px;margin-bottom:20px;text-align:center;background:#d4edda;color:#155724;}
        .nav{margin-bottom:20px;}
        .nav a{color:white;text-decoration:none;background:rgba(255,255,255,0.2);padding:8px 15px;border-radius:5px;margin-right:10px;}
    </style>
</head>
<body>
<div class="container">
    <div class="nav">
        <a href="index.php">🏠 Home</a>
        <a href="crud_siswa.php">📋 CRUD Siswa</a>
        <a href="wp-admin">📝 WordPress</a>
        <a href="phpmyadmin">🗄️ phpMyAdmin</a>
    </div>
    <h1>📋 Manajemen Data Siswa</h1>
    <?php if(isset($pesan)) echo "<div class='alert'>$pesan</div>"; ?>
    
    <div class="card">
        <h2><?php echo $edit ? '✏️ Edit Data' : '➕ Tambah Data'; ?></h2>
        <form method="POST">
            <?php if($edit): ?><input type="hidden" name="id" value="<?php echo $edit['id']; ?>"><?php endif; ?>
            <div class="form-group"><input type="text" name="nama" placeholder="Nama Lengkap" value="<?php echo $edit ? htmlspecialchars($edit['nama']) : ''; ?>" required></div>
            <div class="form-group"><input type="text" name="nis" placeholder="NIS" value="<?php echo $edit ? htmlspecialchars($edit['nis']) : ''; ?>" required></div>
            <div class="form-group"><input type="text" name="rombel" placeholder="Rombel (contoh: XI RPL 1)" value="<?php echo $edit ? htmlspecialchars($edit['rombel']) : ''; ?>" required></div>
            <?php if($edit): ?>
                <button type="submit" name="update">💾 Update</button>
                <a href="crud_siswa.php" class="btn-batal">❌ Batal</a>
            <?php else: ?>
                <button type="submit" name="tambah">💾 Simpan</button>
            <?php endif; ?>
        </form>
    </div>
    
    <div class="card">
        <h2>📋 Daftar Siswa</h2>
        <?php if($data->num_rows > 0): ?>
        <table>
            <thead><tr><th>No</th><th>Nama</th><th>NIS</th><th>Rombel</th><th>Aksi</th></tr></thead>
            <tbody>
            <?php $no=1; while($row=$data->fetch_assoc()): ?>
            <tr>
                <td><?php echo $no++; ?></td>
                <td><?php echo htmlspecialchars($row['nama']); ?></td>
                <td><?php echo htmlspecialchars($row['nis']); ?></td>
                <td><?php echo htmlspecialchars($row['rombel']); ?></td>
                <td><a href="?edit=<?php echo $row['id']; ?>" class="btn-edit">✏️ Edit</a> <a href="?hapus=<?php echo $row['id']; ?>" class="btn-hapus" onclick="return confirm('Yakin?')">🗑️ Hapus</a></td>
            </tr>
            <?php endwhile; ?>
            </tbody>
        </table>
        <?php else: ?>
        <p style="text-align:center;padding:40px;">📭 Belum ada data. Silakan tambah!</p>
        <?php endif; ?>
    </div>
</div>
</body>
</html>
EOF_CRUD

    systemctl restart apache2
    echo -e "${GREEN}✅ Website dan CRUD berhasil dibuat!${NC}"
}

# =================== MENU 9: SSH & SAMBA ===================
menu_set_samba() {
    echo -e "${BLUE}══════════════════ 9. SETUP SSH & SAMBA ══════════════════${NC}"
    
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
   create mask = 0777
   directory mask = 0777
EOF
    systemctl restart smbd
    
    echo -e "${GREEN}✅ SSH & Samba berhasil!${NC}"
}

# =================== MENU 10: DVWA ===================
menu_set_dvwa() {
    echo -e "${BLUE}══════════════════ 10. INSTALL DVWA ══════════════════${NC}"
    
    apt install git -y
    cd /tmp
    rm -rf DVWA
    git clone https://github.com/digininja/DVWA.git
    cp -r DVWA/* /var/www/html/
    cp /var/www/html/config/config.inc.php.dist /var/www/html/config/config.inc.php
    sed -i "s/p@ssw0rd/rootpass123/g" /var/www/html/config/config.inc.php
    mysql -u root -prootpass123 -e "CREATE DATABASE IF NOT EXISTS dvwa;" 2>/dev/null
    chmod 777 /var/www/html/hackable/uploads/
    systemctl restart apache2
    
    echo -e "${GREEN}✅ DVWA berhasil!${NC}"
}

# =================== MENU 11: TAMPILKAN AKSES ===================
menu_show_access() {
    echo -e "${BLUE}══════════════════ 11. INFO AKSES WEB ══════════════════${NC}"
    
    ACTUAL_IP=$(ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🌐 AKSES WEB SERVER (BUKA DI BROWSER):${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "   🔥 ${YELLOW}WEBSITE UTAMA${NC}    : ${CYAN}http://$ACTUAL_IP/${NC}"
    echo ""
    echo -e "   📋 ${YELLOW}CRUD SISWA${NC}       : ${CYAN}http://$ACTUAL_IP/crud_siswa.php${NC}"
    echo ""
    echo -e "   📝 ${YELLOW}WORDPRESS${NC}        : ${CYAN}http://$ACTUAL_IP/wp-admin${NC}"
    echo ""
    echo -e "   🗄️  ${YELLOW}PHPMYADMIN${NC}      : ${CYAN}http://$ACTUAL_IP/phpmyadmin${NC}"
    echo ""
    echo -e "   🔐 ${YELLOW}DVWA${NC}             : ${CYAN}http://$ACTUAL_IP/setup.php${NC}"
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔑 LOGIN phpMyAdmin: root / rootpass123${NC}"
    echo -e "${YELLOW}🔑 LOGIN DVWA: admin / password${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
}

# =================== MENU 12: INSTALL SEMUA ===================
menu_install_all() {
    echo -e "${BLUE}══════════════════ INSTALL SEMUA FITUR ══════════════════${NC}"
    
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
    
    systemctl restart apache2
    systemctl restart mysql
    
    menu_show_access
}

# =================== MENU UTAMA ===================
show_menu() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    MENU INSTALLASI SERVER                        ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📊 STATUS:${NC}"
    echo -e "   Interface : ${GREEN}${INTERFACE:-Belum}${NC}"
    echo -e "   IP Address: ${GREEN}${IP_ADDR:-Belum}${NC}"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  1)${NC} Setting IP (cuma minta IP aja)"
    echo -e "${GREEN}  2)${NC} DHCP Server (Range 100-200)"
    echo -e "${GREEN}  3)${NC} DNS Server"
    echo -e "${GREEN}  4)${NC} Apache2 & PHP"
    echo -e "${GREEN}  5)${NC} MySQL"
    echo -e "${GREEN}  6)${NC} WordPress"
    echo -e "${GREEN}  7)${NC} phpMyAdmin"
    echo -e "${GREEN}  8)${NC} Website + CRUD Siswa"
    echo -e "${GREEN}  9)${NC} SSH & Samba"
    echo -e "${GREEN} 10)${NC} DVWA"
    echo -e "${GREEN} 11)${NC} TAMPILKAN INFO AKSES WEB"
    echo -e "${CYAN} 12)${NC} INSTALL SEMUA SEKALIGUS ⭐"
    echo -e "${RED}  0)${NC} EXIT"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

# =================== MAIN ===================
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
        11) menu_show_access ;;
        12) menu_install_all ;;
        0) echo -e "${GREEN}Terima kasih!${NC}"; exit 0 ;;
        *) echo -e "${RED}Pilihan salah!${NC}"; sleep 1 ;;
    esac
    echo ""; read -p "Tekan ENTER untuk kembali..."
done
