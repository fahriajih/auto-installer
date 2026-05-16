#!/bin/bash

# ============================================================
# FAHTECH AUTOMATION - FINAL FIXED VERSION
# Dengan akses /crud (tanpa .php) dan permission fix
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
        local num=$((i+1))
        echo "  $num. ${IP_LIST[$i]}"
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

# Fix permission function
fix_permission() {
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    systemctl restart apache2
}

# Enable mod_rewrite untuk akses tanpa .php
enable_rewrite() {
    a2enmod rewrite
    systemctl restart apache2
}

# 1. Apache2 + Landing Page
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
            animation: fadeIn 0.8s ease-in;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        h1 {
            font-size: 2.5em;
            background: linear-gradient(135deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        h2 { color: #4a5568; margin-bottom: 20px; font-size: 1.2em; }
        .tagline { font-size: 1.2em; color: #4a5568; margin: 20px 0; }
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
            transition: transform 0.3s;
        }
        .feature-card:hover { transform: scale(1.05); }
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
        <div class="tagline">🌟 Menjadi Pusat Unggulan Teknologi Informasi dan Komunikasi 🌟</div>
        <div class="features">
            <div class="feature-card">💻 Networking Expert</div>
            <div class="feature-card">🔧 Server Administrator</div>
            <div class="feature-card">🌐 Web Development</div>
            <div class="feature-card">📡 Cybersecurity</div>
        </div>
        <p>Selamat datang di layanan auto-configuration Fahtech!</p>
        <p>🚀 Siap menjadi teknisi jaringan handal 🚀</p>
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

# 2. DHCP Server
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

# 3. Single DNS Server
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

# 4. Triple DNS Server
install_dns_triple() {
    echo "[INSTALL] Memulai instalasi 3 DNS Server..."
    pilih_ip
    
    apt update && apt install -y bind9 apache2
    enable_rewrite
    
    declare -a DOMAINS
    
    for i in 1 2 3; do
        read -p "Masukkan domain ke-$i (contoh: domain$i.com): " DOM
        
        mkdir -p /var/www/$DOM
        
        cat > /var/www/$DOM/index.html << EOF
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>$DOM - TJKT Wikrama</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #${RANDOM:0:6}, #${RANDOM:0:6});
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .card {
            background: rgba(255,255,255,0.95);
            border-radius: 20px;
            padding: 50px;
            text-align: center;
            max-width: 600px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            animation: fadeIn 0.8s ease-in;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: scale(0.9); }
            to { opacity: 1; transform: scale(1); }
        }
        h1 { color: #667eea; margin-bottom: 20px; font-size: 2.5em; }
        .domain { color: #764ba2; font-size: 1.3em; margin: 20px 0; font-weight: bold; }
        .info { background: #f0f0f0; padding: 15px; border-radius: 10px; margin: 20px 0; }
        .badge {
            display: inline-block;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            padding: 8px 20px;
            border-radius: 25px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>🚀 $DOM</h1>
        <div class="domain">✨ Layanan DNS Server Ke-$i ✨</div>
        <div class="info">
            <p>🏫 TJKT SMK WIKRAMA</p>
            <p>📡 Teknik Jaringan & Telekomunikasi</p>
            <p>🔧 Dikonfigurasi oleh Fahtech Automation</p>
            <p>🌐 Domain: $DOM</p>
        </div>
        <div class="badge">✅ DNS Resolving Aktif</div>
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
*       IN      A       $SELECTED_IP
EOF

        cat > /etc/apache2/sites-available/$DOM.conf << EOF
<VirtualHost *:80>
    ServerName $DOM
    ServerAlias www.$DOM
    DocumentRoot /var/www/$DOM
    <Directory /var/www/$DOM>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/${DOM}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOM}_access.log combined
</VirtualHost>
EOF
        
        a2ensite $DOM.conf 2>/dev/null
    done
    
    systemctl restart bind9
    systemctl reload apache2
    
    for i in 1 2 3; do
        chown -R www-data:www-data /var/www/${DOMAINS[$i]}
        chmod -R 755 /var/www/${DOMAINS[$i]}
    done
    
    for i in 1 2 3; do
        if ! grep -q "${DOMAINS[$i]}" /etc/hosts; then
            echo "$SELECTED_IP ${DOMAINS[$i]} www.${DOMAINS[$i]}" >> /etc/hosts
        fi
    done
    
    echo ""
    echo "[SUCCESS] 3 DNS Server BERHASIL!"
    echo "============================================================"
    for i in 1 2 3; do
        echo "  DOMAIN $i: http://${DOMAINS[$i]}"
    done
    echo "============================================================"
    echo ""
}

# 5. FTP Server
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

# 6. Samba Server
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

# 7. CRUD Application (FIXED - bisa akses /crud tanpa .php)
install_crud() {
    echo "[INSTALL] Memulai instalasi CRUD Application..."
    pilih_ip
    apt update
    apt install -y apache2 php php-mysql libapache2-mod-php
    
    enable_rewrite
    
    if command -v mysql &> /dev/null; then
        echo "MySQL sudah terinstall"
    else
        apt install -y mariadb-server mariadb-client
        systemctl start mariadb
        systemctl enable mariadb
    fi
    
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
('12346', 'Budi Santoso', 'TJKT-2', 'Bogor'),
('12347', 'Citra Dewi', 'TJKT-1', 'Sukasari'),
('12348', 'Dani Ramdani', 'TJKT-3', 'Cibinong');
EOF
    
    # Buat file crud.php
    cat > /var/www/html/crud.php << 'EOF'
<?php
$conn = new mysqli('localhost', 'root', '', 'siswa_wikrama');
if ($conn->connect_error) die("Koneksi gagal: " . $conn->connect_error);

if(isset($_POST['add'])) {
    $conn->query("INSERT INTO data_siswa (nis, nama, rombel, rayon) VALUES 
        ('{$_POST['nis']}', '{$_POST['nama']}', '{$_POST['rombel']}', '{$_POST['rayon']}')");
    echo "<script>alert('Data ditambahkan!'); window.location='crud';</script>";
}

if(isset($_POST['update'])) {
    $conn->query("UPDATE data_siswa SET nis='{$_POST['nis']}', nama='{$_POST['nama']}', 
        rombel='{$_POST['rombel']}', rayon='{$_POST['rayon']}' WHERE id={$_POST['id']}");
    echo "<script>alert('Data diupdate!'); window.location='crud';</script>";
}

if(isset($_GET['delete'])) {
    $conn->query("DELETE FROM data_siswa WHERE id={$_GET['delete']}");
    echo "<script>alert('Data dihapus!'); window.location='crud';</script>";
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
    <meta charset="UTF-8">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Arial; background: linear-gradient(135deg, #667eea, #764ba2); padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 15px; padding: 30px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); }
        h1 { color: #667eea; margin-bottom: 5px; }
        h2 { color: #764ba2; margin-bottom: 20px; font-size: 1.1em; }
        .form-group { display: inline-block; margin-right: 10px; margin-bottom: 15px; }
        input, select { padding: 10px; border: 2px solid #ddd; border-radius: 8px; font-size: 14px; width: 200px; }
        button { background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 10px 25px; border: none; border-radius: 8px; cursor: pointer; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #667eea; color: white; }
        tr:hover { background: #f5f5f5; }
        .edit-btn { background: #4CAF50; color: white; padding: 5px 10px; text-decoration: none; border-radius: 5px; margin-right: 5px; display: inline-block; }
        .delete-btn { background: #f44336; color: white; padding: 5px 10px; text-decoration: none; border-radius: 5px; display: inline-block; }
        .stats { background: #e7f3ff; padding: 15px; border-radius: 10px; margin: 20px 0; }
        .success { background: #d4edda; color: #155724; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
    </style>
</head>
<body>
<div class="container">
    <h1>🚀 TJKT SMK WIKRAMA</h1>
    <h2>📚 Manajemen Data Siswa (Create, Read, Update, Delete)</h2>
    
    <?php
    $total = $conn->query("SELECT COUNT(*) as total FROM data_siswa")->fetch_assoc()['total'];
    ?>
    
    <div class="stats">📊 Total Data Siswa: <strong><?php echo $total; ?></strong> orang</div>
    
    <form method="POST">
        <input type="hidden" name="id" value="<?php echo $edit['id'] ?? ''; ?>">
        <div class="form-group"><input type="text" name="nis" placeholder="NIS" value="<?php echo $edit['nis'] ?? ''; ?>" required></div>
        <div class="form-group"><input type="text" name="nama" placeholder="Nama Lengkap" value="<?php echo $edit['nama'] ?? ''; ?>" required></div>
        <div class="form-group"><input type="text" name="rombel" placeholder="Rombel" value="<?php echo $edit['rombel'] ?? ''; ?>" required></div>
        <div class="form-group"><input type="text" name="rayon" placeholder="Rayon" value="<?php echo $edit['rayon'] ?? ''; ?>" required></div>
        <?php if($edit_data): ?>
            <button type="submit" name="update">🔄 Update</button>
            <a href="crud" style="margin-left:10px;">➕ Batal</a>
        <?php else: ?>
            <button type="submit" name="add">➕ Tambah Data</button>
        <?php endif; ?>
    </form>
    
    <h3>📋 Daftar Siswa:</h3>
    <table>
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
            <td>
                <a href="crud?edit=<?php echo $row['id']; ?>" class="edit-btn">✏️ Edit</a>
                <a href="crud?delete=<?php echo $row['id']; ?>" class="delete-btn" onclick="return confirm('Yakin hapus?')">🗑️ Hapus</a>
            </td>
        </tr>
        <?php endwhile; ?>
    </table>
</div>
</body>
</html>
EOF
    
    # Buat file .htaccess untuk rewrite rule
    cat > /var/www/html/.htaccess << 'EOF'
RewriteEngine On
RewriteRule ^crud$ crud.php [L]
EOF
    
    # Buat juga file index di folder crud (alternatif)
    mkdir -p /var/www/html/crud
    cat > /var/www/html/crud/index.php << 'EOF'
<?php
header('Location: ../crud.php');
exit;
?>
EOF
    
    chmod 755 /var/www/html/crud.php
    chmod 755 /var/www/html/.htaccess
    fix_permission
    
    echo ""
    echo "[SUCCESS] CRUD Application BERHASIL!"
    echo "[ACCESS] http://$SELECTED_IP/crud"
    echo "[INFO] Bisa akses dengan atau tanpa .php"
    echo ""
}

# 8. WordPress
install_wordpress() {
    echo "[INSTALL] Memulai instalasi WordPress..."
    pilih_ip
    apt update
    apt install -y apache2 php php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip libapache2-mod-php
    
    enable_rewrite
    
    if command -v mysql &> /dev/null; then
        echo "MySQL sudah terinstall"
    else
        apt install -y mariadb-server mariadb-client
        systemctl start mariadb
        systemctl enable mariadb
    fi
    
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

# 9. Mail Server
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

# 10. Zabbix Server
install_zabbix() {
    echo "[INSTALL] Memulai instalasi Zabbix Server..."
    pilih_ip
    apt update && apt install -y wget gnupg2
    
    wget -q https://repo.zabbix.com/zabbix/6.4/debian/pool/main/z/zabbix-release/zabbix-release_6.4-1+debian12_all.deb
    dpkg -i zabbix-release_6.4-1+debian12_all.deb
    apt update
    
    apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
    
    if command -v mysql &> /dev/null; then
        echo "MySQL sudah terinstall"
    else
        apt install -y mariadb-server mariadb-client
        systemctl start mariadb
        systemctl enable mariadb
    fi
    
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

# 11. Hapus Semua Service
hapus_semua() {
    echo "============================================================"
    echo "  PERINGATAN: Ini akan menghapus SEMUA service!"
    echo "============================================================"
    read -p "Yakin? (ketik 'YA' untuk lanjut): " CONFIRM
    if [ "$CONFIRM" != "YA" ]; then
        echo "[BATAL]"
        return
    fi
    
    systemctl stop apache2 mysql mariadb postfix dovecot bind9 isc-dhcp-server vsftpd smbd zabbix-server 2>/dev/null
    
    apt remove --purge -y apache2 mysql-server mariadb-server php* postfix dovecot* bind9 isc-dhcp-server vsftpd samba zabbix-server-mysql zabbix-frontend-php 2>/dev/null
    apt autoremove -y
    
    rm -rf /var/www/html/* /etc/bind/* /etc/dhcp/* /srv/samba/* /var/lib/mysql /etc/zabbix 2>/dev/null
    
    echo ""
    echo "[SUCCESS] Semua service telah dihapus!"
    echo ""
}

# 12. Install Semua Service
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
    echo "  7.  CRUD Application (Data Siswa) - Akses via /crud"
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
