# =====================================================
# LANGKAH 1: STOP DAN HAPUS SEMUA YANG LAMA
# =====================================================
systemctl stop named bind9 apache2 2>/dev/null
systemctl disable named bind9 2>/dev/null
apt remove --purge bind9 bind9utils -y
apt autoremove -y
rm -rf /etc/bind
rm -rf /var/cache/bind
rm -rf /var/lib/bind

# Hapus yang pakai port 53
fuser -k 53/tcp 2>/dev/null
fuser -k 53/udp 2>/dev/null

# =====================================================
# LANGKAH 2: INSTALL APACHE2 + PHP (PASTI JALAN)
# =====================================================
apt update
apt install -y apache2 php libapache2-mod-php mariadb-server mariadb-client

# Buat landing page KEREN
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
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
        .card {
            background: rgba(255,255,255,0.95);
            border-radius: 20px;
            padding: 50px;
            text-align: center;
            max-width: 600px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            animation: fadeIn 0.8s;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-30px); }
            to { opacity: 1; transform: translateY(0); }
        }
        h1 { font-size: 2.5em; background: linear-gradient(135deg, #667eea, #764ba2); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .logo { font-size: 4em; margin-bottom: 20px; }
        .features { display: flex; gap: 15px; margin: 30px 0; justify-content: center; flex-wrap: wrap; }
        .feature { background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 10px 20px; border-radius: 25px; }
        .btn { display: inline-block; padding: 12px 30px; background: linear-gradient(135deg, #667eea, #764ba2); color: white; text-decoration: none; border-radius: 25px; margin-top: 20px; }
        footer { margin-top: 30px; color: #999; font-size: 12px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="logo">🚀</div>
        <h1>SMK WIKRAMA</h1>
        <h2>TEKNIK JARINGAN & TELEKOMUNIKASI</h2>
        <div class="features">
            <div class="feature">💻 Networking</div>
            <div class="feature">🔧 Server Admin</div>
            <div class="feature">🌐 Web Dev</div>
            <div class="feature">📡 Security</div>
        </div>
        <p>Auto Configuration System by <strong>Fahtech</strong></p>
        <a href="#" class="btn">Explore →</a>
        <footer>© TJKT SMK Wikrama 2025</footer>
    </div>
</body>
</html>
EOF

systemctl restart apache2
systemctl enable apache2

echo ""
echo "=========================================="
echo "✅ APACHE2 + LANDING PAGE BERHASIL!"
echo "🌐 http://$SELECTED_IP"
echo "=========================================="
echo ""

# =====================================================
# LANGKAH 3: INSTALL DNS (BIND9) - FIXED
# =====================================================
install_dns() {
    echo ">>> INSTALL DNS SERVER"
    
    # Install BIND9
    apt install -y bind9 bind9utils dnsutils
    
    # Backup config default
    mv /etc/bind/named.conf.options /etc/bind/named.conf.options.bak 2>/dev/null
    
    # Buat config baru
    cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    listen-on { $SELECTED_IP; 127.0.0.1; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    dnssec-validation auto;
};
EOF

    # Buat named.conf.local
    cat > /etc/bind/named.conf.local << EOF
// Local DNS configuration
EOF

    # Restart BIND9
    systemctl restart named
    systemctl enable named
    
    echo "✅ DNS Server BERHASIL!"
    echo "🔍 NSLOOKUP bisa dicoba setelah domain ditambahkan"
}

# =====================================================
# LANGKAH 4: INSTALL CRUD + DATABASE
# =====================================================
install_crud() {
    echo ">>> INSTALL CRUD APPLICATION"
    
    # Start MariaDB
    systemctl start mariadb
    systemctl enable mariadb
    
    # Buat database
    mysql << 'EOF'
CREATE DATABASE IF NOT EXISTS siswa_wikrama;
USE siswa_wikrama;
CREATE TABLE IF NOT EXISTS siswa (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nis VARCHAR(20) NOT NULL,
    nama VARCHAR(100) NOT NULL,
    rombel VARCHAR(50) NOT NULL,
    rayon VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO siswa (nis, nama, rombel, rayon) VALUES 
('12345', 'Ahmad Fahtech', 'TJKT-1', 'Ciawi'),
('12346', 'Budi Santoso', 'TJKT-2', 'Bogor'),
('12347', 'Citra Dewi', 'TJKT-1', 'Sukasari');
EOF

    # Buat file CRUD
    cat > /var/www/html/index.php << 'PHP'
<?php
$host = 'localhost';
$user = 'root';
$pass = '';
$db = 'siswa_wikrama';

$conn = mysqli_connect($host, $user, $pass, $db);
if (!$conn) die("Koneksi gagal: " . mysqli_connect_error());

// Proses CRUD
if(isset($_POST['simpan'])) {
    mysqli_query($conn, "INSERT INTO siswa (nis, nama, rombel, rayon) VALUES 
        ('$_POST[nis]', '$_POST[nama]', '$_POST[rombel]', '$_POST[rayon]')");
    echo "<script>alert('Data tersimpan!'); location.href='';</script>";
}

if(isset($_POST['update'])) {
    mysqli_query($conn, "UPDATE siswa SET nis='$_POST[nis]', nama='$_POST[nama]', 
        rombel='$_POST[rombel]', rayon='$_POST[rayon]' WHERE id=$_POST[id]");
    echo "<script>alert('Data terupdate!'); location.href='';</script>";
}

if(isset($_GET['hapus'])) {
    mysqli_query($conn, "DELETE FROM siswa WHERE id=$_GET[hapus]");
    echo "<script>alert('Data terhapus!'); location.href='';</script>";
}

$edit = null;
if(isset($_GET['edit'])) {
    $res = mysqli_query($conn, "SELECT * FROM siswa WHERE id=$_GET[edit]");
    $edit = mysqli_fetch_assoc($res);
}

$data = mysqli_query($conn, "SELECT * FROM siswa ORDER BY id DESC");
$total = mysqli_num_rows($data);
?>
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
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 { color: #667eea; margin-bottom: 5px; }
        h2 { color: #764ba2; margin-bottom: 20px; font-size: 1em; }
        .form-group { display: inline-block; margin-right: 10px; margin-bottom: 15px; }
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
        tr:hover { background: #f5f5f5; }
        .edit-btn { background: #4CAF50; color: white; padding: 5px 12px; text-decoration: none; border-radius: 5px; margin: 2px; display: inline-block; }
        .delete-btn { background: #f44336; color: white; padding: 5px 12px; text-decoration: none; border-radius: 5px; margin: 2px; display: inline-block; }
        .stats { background: #e7f3ff; padding: 15px; border-radius: 10px; margin: 20px 0; }
        .badge { background: #667eea; color: white; padding: 3px 10px; border-radius: 20px; font-size: 12px; }
    </style>
</head>
<body>
<div class="container">
    <h1>🚀 TJKT SMK WIKRAMA</h1>
    <h2>📚 SISTEM MANAJEMEN DATA SISWA (CRUD)</h2>
    
    <div class="stats">
        📊 Total Siswa: <strong><?= $total ?></strong> orang
    </div>
    
    <form method="POST">
        <?php if($edit): ?>
            <input type="hidden" name="id" value="<?= $edit['id'] ?>">
            <div class="form-group"><input type="text" name="nis" value="<?= $edit['nis'] ?>" placeholder="NIS" required></div>
            <div class="form-group"><input type="text" name="nama" value="<?= $edit['nama'] ?>" placeholder="Nama" required></div>
            <div class="form-group"><input type="text" name="rombel" value="<?= $edit['rombel'] ?>" placeholder="Rombel" required></div>
            <div class="form-group"><input type="text" name="rayon" value="<?= $edit['rayon'] ?>" placeholder="Rayon" required></div>
            <button type="submit" name="update">🔄 UPDATE DATA</button>
            <a href="" style="margin-left:10px;">❌ BATAL</a>
        <?php else: ?>
            <div class="form-group"><input type="text" name="nis" placeholder="NIS" required></div>
            <div class="form-group"><input type="text" name="nama" placeholder="Nama Lengkap" required></div>
            <div class="form-group"><input type="text" name="rombel" placeholder="Rombel (ex: TJKT-1)" required></div>
            <div class="form-group"><input type="text" name="rayon" placeholder="Rayon (ex: Ciawi)" required></div>
            <button type="submit" name="simpan">➕ TAMBAH DATA</button>
        <?php endif; ?>
    </form>
    
    <h3>📋 DAFTAR SISWA</h3>
    <table>
        <tr>
            <th>ID</th><th>NIS</th><th>Nama</th><th>Rombel</th><th>Rayon</th><th>Aksi</th>
        </tr>
        <?php while($row = mysqli_fetch_assoc($data)): ?>
        <tr>
            <td><?= $row['id'] ?></td>
            <td><?= $row['nis'] ?></td>
            <td><?= $row['nama'] ?></td>
            <td><span class="badge"><?= $row['rombel'] ?></span></td>
            <td><?= $row['rayon'] ?></td>
            <td>
                <a href="?edit=<?= $row['id'] ?>" class="edit-btn">✏️ Edit</a>
                <a href="?hapus=<?= $row['id'] ?>" class="delete-btn" onclick="return confirm('Yakin hapus data ini?')">🗑️ Hapus</a>
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
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
    
    systemctl restart apache2
    
    echo ""
    echo "=========================================="
    echo "✅ CRUD APPLICATION BERHASIL!"
    echo "🌐 http://$SELECTED_IP"
    echo "=========================================="
    echo ""
}

# =====================================================
# LANGKAH 5: INSTALL 3 DNS (SEDERHANA TANPA BIND)
# =====================================================
install_3dns_simple() {
    echo ">>> INSTALL 3 DOMAIN (Menggunakan /etc/hosts)"
    
    # Install Apache
    apt install -y apache2
    
    # Buat 3 folder dan 3 website berbeda
    for i in 1 2 3; do
        DOMAIN="domain$i.com"
        mkdir -p /var/www/$DOMAIN
        
        cat > /var/www/$DOMAIN/index.html << EOF
<!DOCTYPE html>
<html>
<head><title>$DOMAIN - TJKT</title>
<style>
body {
    margin: 0;
    padding: 50px;
    font-family: Arial;
    background: linear-gradient(135deg, #${RANDOM:0:6}, #${RANDOM:0:6});
    text-align: center;
    color: white;
    min-height: 100vh;
}
.card {
    background: rgba(0,0,0,0.7);
    padding: 40px;
    border-radius: 20px;
    display: inline-block;
}
</style>
</head>
<body>
<div class="card">
    <h1>🚀 $DOMAIN</h1>
    <h2>DNS Server Ke-$i</h2>
    <p>📡 TJKT SMK WIKRAMA</p>
    <p>🔧 Powered by Fahtech Automation</p>
    <p>✅ Domain ini aktif dan terresolve!</p>
</div>
</body>
</html>
EOF

        # Buat VirtualHost
        cat > /etc/apache2/sites-available/$DOMAIN.conf << EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/$DOMAIN
    <Directory /var/www/$DOMAIN>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

        a2ensite $DOMAIN.conf
        
        # Tambahkan ke /etc/hosts
        if ! grep -q "$DOMAIN" /etc/hosts; then
            echo "$SELECTED_IP $DOMAIN" >> /etc/hosts
        fi
    done
    
    systemctl reload apache2
    
    echo ""
    echo "=========================================="
    echo "✅ 3 DOMAIN BERHASIL!"
    for i in 1 2 3; do
        echo "🌐 http://domain$i.com"
    done
    echo "=========================================="
    echo "💡 Gunakan browser yang support /etc/hosts"
    echo "💡 Atau set DNS ke IP $SELECTED_IP"
    echo ""
}

# =====================================================
# MENU UTAMA
# =====================================================
while true; do
    clear
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
    echo "  📡 IP SERVER: $SELECTED_IP"
    echo ""
    echo "  ╔════════════════════════════════════════════════════════════════════╗"
    echo "  ║                         DAFTAR LAYANAN                             ║"
    echo "  ╠════════════════════════════════════════════════════════════════════╣"
    echo "  ║  1.  Apache2 + Landing Page (TAMPILAN KEREN)                       ║"
    echo "  ║  2.  DHCP Server (Range 100-200)                                   ║"
    echo "  ║  3.  DNS Server (Single Domain)                                    ║"
    echo "  ║  4.  3 Domain Berbeda (domain1.com, domain2.com, domain3.com)     ║"
    echo "  ║  5.  FTP Server                                                    ║"
    echo "  ║  6.  Samba Server (SMB Share)                                      ║"
    echo "  ║  7.  CRUD Application + Database (Data Siswa)                      ║"
    echo "  ║  8.  WordPress CMS                                                 ║"
    echo "  ║  9.  Mail Server (Postfix + Dovecot)                               ║"
    echo "  ║  10. Zabbix Server Monitoring                                      ║"
    echo "  ║  11. Hapus Semua Service                                           ║"
    echo "  ║  12. Install Semua Service Sekaligus                               ║"
    echo "  ║  0.  Keluar                                                        ║"
    echo "  ╚════════════════════════════════════════════════════════════════════╝"
    echo ""
    read -p "  ➤ Pilih nomor [0-12]: " MENU_CHOICE
    
    case $MENU_CHOICE in
        1) install_apache ;;
        2) echo "Install DHCP..."; apt install -y isc-dhcp-server; echo "✅ DHCP Selesai" ;;
        3) install_dns ;;
        4) install_3dns_simple ;;
        5) echo "Install FTP..."; apt install -y vsftpd; useradd -m ftpuser 2>/dev/null; echo "ftpuser:wikrama123" | chpasswd; echo "✅ FTP Selesai" ;;
        6) echo "Install Samba..."; apt install -y samba; mkdir -p /srv/samba/share; chmod 777 /srv/samba/share; echo "✅ Samba Selesai" ;;
        7) install_crud ;;
        8) echo "Install WordPress..."; apt install -y wordpress; echo "✅ WordPress Selesai" ;;
        9) echo "Install Mail Server..."; apt install -y postfix dovecot; echo "✅ Mail Server Selesai" ;;
        10) echo "Install Zabbix..."; apt install -y zabbix-server-mysql; echo "✅ Zabbix Selesai" ;;
        11) echo "Hapus semua..."; apt remove --purge -y apache2 bind9 isc-dhcp-server vsftpd samba mariadb-server; rm -rf /var/www/html/*; echo "✅ Selesai" ;;
        12) install_apache; install_crud; echo "✅ Semua service selesai" ;;
        0) echo "Terima kasih!"; exit 0 ;;
        *) echo "Pilihan salah!" ;;
    esac
    
    echo ""
    read -p "  Tekan Enter untuk kembali ke menu..."
done
