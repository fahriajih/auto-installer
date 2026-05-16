#!/bin/bash

# ============================================================
#   FAHTECH - 3 DNS SERVER INSTALLER
#   TAMPILAN WEB KEREN | SEMUA SERVICE BERFUNGSI
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
echo "║                   3 DNS SERVER INSTALLER                                     ║"
echo "║            TAMPILAN WEB KEREN | LANGSUNG BISA AKSES                          ║"
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

# ======================= INSTALL 3 DNS SERVER =======================
install_3dns() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              🚀 INSTALL 3 DNS SERVER SEKALIGUS                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    # ======================= DNS 1 =======================
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📍 DNS SERVER 1 - TUTORIAL DHCP${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih interface untuk DNS Server 1:${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice1
    
    if [[ $choice1 -ge 1 && $choice1 -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r IFACE1 IP1 <<< "${INTERFACES[$((choice1-1))]}"
        echo -e "\n${MAGENTA}📝 Masukkan domain untuk DNS 1 (contoh: dhcp.fahtech.com):${NC}"
        read -p "Domain: " DOMAIN1
    else
        echo -e "${RED}❌ Pilihan tidak valid!${NC}"
        return
    fi
    
    # ======================= DNS 2 =======================
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📍 DNS SERVER 2 - TUTORIAL CRUD${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih interface untuk DNS Server 2:${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice2
    
    if [[ $choice2 -ge 1 && $choice2 -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r IFACE2 IP2 <<< "${INTERFACES[$((choice2-1))]}"
        echo -e "\n${MAGENTA}📝 Masukkan domain untuk DNS 2 (contoh: crud.fahtech.com):${NC}"
        read -p "Domain: " DOMAIN2
    else
        echo -e "${RED}❌ Pilihan tidak valid!${NC}"
        return
    fi
    
    # ======================= DNS 3 =======================
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  📍 DNS SERVER 3 - TUTORIAL APACHE2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih interface untuk DNS Server 3:${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice3
    
    if [[ $choice3 -ge 1 && $choice3 -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r IFACE3 IP3 <<< "${INTERFACES[$((choice3-1))]}"
        echo -e "\n${MAGENTA}📝 Masukkan domain untuk DNS 3 (contoh: web.fahtech.com):${NC}"
        read -p "Domain: " DOMAIN3
    else
        echo -e "${RED}❌ Pilihan tidak valid!${NC}"
        return
    fi
    
    echo -e "\n${CYAN}📦 Menginstall 3 DNS Server...${NC}"
    
    # Install paket
    apt update -qq
    apt install -y apache2 php libapache2-mod-php php-sqlite3 bind9 bind9utils wget curl
    
    # Bersihkan DNS lama
    systemctl stop bind9 2>/dev/null
    apt remove --purge -y bind9 bind9utils 2>/dev/null
    rm -rf /etc/bind
    
    # Install ulang DNS
    apt install -y bind9 bind9utils
    mkdir -p /etc/bind /var/lib/bind /var/cache/bind
    chown -R bind:bind /var/lib/bind /var/cache/bind
    
    # Konfigurasi DNS untuk 3 domain
    cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN1" {
    type master;
    file "/etc/bind/db.$DOMAIN1";
};
zone "$DOMAIN2" {
    type master;
    file "/etc/bind/db.$DOMAIN2";
};
zone "$DOMAIN3" {
    type master;
    file "/etc/bind/db.$DOMAIN3";
};
EOF
    
    cat > /etc/bind/db.$DOMAIN1 <<EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN1. admin.$DOMAIN1. ( 1 604800 86400 2419200 604800 )
@       IN      NS      ns1.$DOMAIN1.
@       IN      A       $IP1
ns1     IN      A       $IP1
www     IN      A       $IP1
EOF
    
    cat > /etc/bind/db.$DOMAIN2 <<EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN2. admin.$DOMAIN2. ( 2 604800 86400 2419200 604800 )
@       IN      NS      ns1.$DOMAIN2.
@       IN      A       $IP2
ns1     IN      A       $IP2
www     IN      A       $IP2
EOF
    
    cat > /etc/bind/db.$DOMAIN3 <<EOF
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN3. admin.$DOMAIN3. ( 3 604800 86400 2419200 604800 )
@       IN      NS      ns1.$DOMAIN3.
@       IN      A       $IP3
ns1     IN      A       $IP3
www     IN      A       $IP3
EOF
    
    cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    forwarders { 8.8.8.8; 8.8.4.4; };
    listen-on { any; };
    listen-on-v6 { none; };
};
EOF
    
    systemctl start bind9
    systemctl enable bind9
    
    # ======================= TAMPILAN WEB DNS 1 =======================
    mkdir -p /var/www/html/$DOMAIN1
    cat > /var/www/html/$DOMAIN1/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>DNS 1 - Tutorial DHCP</title>
<style>
body{background:linear-gradient(135deg,#0f2027,#203a43,#2c5364);font-family:Arial;padding:40px}
.container{max-width:1000px;margin:auto;background:#fff;border-radius:20px;padding:40px}
h1{color:#2c5364}
pre{background:#1a1a2e;color:#0f0;padding:15px;border-radius:10px}
.info{background:#e8f4f8;padding:15px;border-radius:10px;margin:20px 0}
</style>
</head>
<body>
<div class="container">
<h1>📖 TUTORIAL DHCP SERVER</h1>
<div class="info"><strong>Domain:</strong> $DOMAIN1 | <strong>IP:</strong> $IP1 | <strong>Interface:</strong> $IFACE1</div>
<h3>1. Install DHCP Server</h3>
<pre>sudo apt install isc-dhcp-server -y</pre>
<h3>2. Konfigurasi Interface</h3>
<pre>sudo nano /etc/default/isc-dhcp-server
INTERFACESv4="$IFACE1"</pre>
<h3>3. Konfigurasi DHCP</h3>
<pre>subnet ${IP1%.*}.0 netmask 255.255.255.0 {
    range ${IP1%.*}.100 ${IP1%.*}.200;
    option routers ${IP1%.*}.1;
    option domain-name-servers $IP1, 8.8.8.8;
}</pre>
<h3>4. Start DHCP Server</h3>
<pre>sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server</pre>
<p>Powered by FahTech Installer</p>
</div>
</body>
</html>
EOF
    
    # ======================= TAMPILAN WEB DNS 2 + CRUD =======================
    mkdir -p /var/www/html/crud
    mkdir -p /var/www/html/$DOMAIN2
    
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
    
    cat > /var/www/html/$DOMAIN2/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>DNS 2 - Tutorial CRUD</title>
<style>
body{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);font-family:Arial;padding:40px}
.container{max-width:1000px;margin:auto;background:#fff;border-radius:20px;padding:40px}
h1{color:#667eea}
pre{background:#1a1a2e;color:#0f0;padding:15px;border-radius:10px}
.info{background:#f0f4ff;padding:15px;border-radius:10px;margin:20px 0}
</style>
</head>
<body>
<div class="container">
<h1>📖 TUTORIAL CRUD SISWA</h1>
<div class="info"><strong>Domain:</strong> $DOMAIN2 | <strong>IP:</strong> $IP2 | <strong>Interface:</strong> $IFACE2</div>
<h3>Fitur CRUD:</h3>
<pre>➕ CREATE: INSERT INTO siswa (nama, rombel, nis) VALUES (...)
📖 READ: SELECT * FROM siswa ORDER BY id DESC
✏️ UPDATE: UPDATE siswa SET nama='...' WHERE id=...
🗑️ DELETE: DELETE FROM siswa WHERE id=...
🔍 SEARCH: SELECT * FROM siswa WHERE nama LIKE '%...%'</pre>
<h3>Akses CRUD App:</h3>
<pre>http://$IP2/crud/</pre>
<p>Powered by FahTech Installer | <a href="/crud/">🔗 Buka CRUD App</a></p>
</div>
</body>
</html>
EOF
    
    # ======================= TAMPILAN WEB DNS 3 =======================
    mkdir -p /var/www/html/$DOMAIN3
    cat > /var/www/html/$DOMAIN3/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>DNS 3 - Tutorial Apache2</title>
<style>
body{background:linear-gradient(135deg,#0f2027,#203a43,#2c5364);font-family:Arial;padding:40px}
.container{max-width:1000px;margin:auto;background:#fff;border-radius:20px;padding:40px}
h1{color:#2c5364}
pre{background:#1a1a2e;color:#0f0;padding:15px;border-radius:10px}
.info{background:#e8f4f8;padding:15px;border-radius:10px;margin:20px 0}
</style>
</head>
<body>
<div class="container">
<h1>📖 TUTORIAL APACHE2 WEB SERVER</h1>
<div class="info"><strong>Domain:</strong> $DOMAIN3 | <strong>IP:</strong> $IP3 | <strong>Interface:</strong> $IFACE3</div>
<h3>1. Install Apache2</h3>
<pre>sudo apt install apache2 -y</pre>
<h3>2. Konfigurasi Virtual Host</h3>
<pre>sudo nano /etc/apache2/sites-available/$DOMAIN3.conf
&lt;VirtualHost *:80&gt;
    ServerName $DOMAIN3
    DocumentRoot /var/www/html/$DOMAIN3
&lt;/VirtualHost&gt;</pre>
<h3>3. Aktifkan Site</h3>
<pre>sudo a2ensite $DOMAIN3.conf
sudo systemctl reload apache2</pre>
<h3>4. Install PHP</h3>
<pre>sudo apt install php libapache2-mod-php -y</pre>
<p>Powered by FahTech Installer</p>
</div>
</body>
</html>
EOF
    
    # ======================= VIRTUAL HOST =======================
    cat > /etc/apache2/sites-available/$DOMAIN1.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN1
    DocumentRoot /var/www/html/$DOMAIN1
</VirtualHost>
EOF
    
    cat > /etc/apache2/sites-available/$DOMAIN2.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN2
    DocumentRoot /var/www/html/$DOMAIN2
</VirtualHost>
EOF
    
    cat > /etc/apache2/sites-available/$DOMAIN3.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN3
    DocumentRoot /var/www/html/$DOMAIN3
</VirtualHost>
EOF
    
    a2ensite $DOMAIN1.conf $DOMAIN2.conf $DOMAIN3.conf
    a2dissite 000-default.conf
    systemctl reload apache2
    
    chown -R www-data:www-data /var/www/html/crud
    chown -R www-data:www-data /var/www/html/$DOMAIN1
    chown -R www-data:www-data /var/www/html/$DOMAIN2
    chown -R www-data:www-data /var/www/html/$DOMAIN3
    
    # ======================= HASIL =======================
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🎉 3 DNS SERVER BERHASIL DIINSTALL! 🎉${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e ""
    echo -e "${CYAN}📋 HASIL INSTALASI:${NC}"
    echo -e ""
    echo -e "${GREEN}🔍 DNS SERVER 1 - TUTORIAL DHCP${NC}"
    echo -e "   📝 Domain: ${YELLOW}$DOMAIN1${NC}"
    echo -e "   🌐 IP: ${YELLOW}$IP1${NC}"
    echo -e "   🔧 Interface: ${YELLOW}$IFACE1${NC}"
    echo -e "   🌐 Web: ${YELLOW}http://$DOMAIN1${NC}"
    echo -e ""
    echo -e "${GREEN}🗄️ DNS SERVER 2 - TUTORIAL CRUD${NC}"
    echo -e "   📝 Domain: ${YELLOW}$DOMAIN2${NC}"
    echo -e "   🌐 IP: ${YELLOW}$IP2${NC}"
    echo -e "   🔧 Interface: ${YELLOW}$IFACE2${NC}"
    echo -e "   🌐 Web: ${YELLOW}http://$DOMAIN2${NC}"
    echo -e "   🗄️ CRUD App: ${YELLOW}http://$IP2/crud/${NC}"
    echo -e ""
    echo -e "${GREEN}🌍 DNS SERVER 3 - TUTORIAL APACHE2${NC}"
    echo -e "   📝 Domain: ${YELLOW}$DOMAIN3${NC}"
    echo -e "   🌐 IP: ${YELLOW}$IP3${NC}"
    echo -e "   🔧 Interface: ${YELLOW}$IFACE3${NC}"
    echo -e "   🌐 Web: ${YELLOW}http://$DOMAIN3${NC}"
    echo -e ""
    echo -e "${CYAN}💡 CARA AKSES DARI LAPTOP/PC KAMU:${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "1. Setting IP laptop ke 1 jaringan dengan Debian:"
    echo -e "   ${GREEN}IP: 10.1.27.100, Netmask: 255.255.255.0, Gateway: 10.1.27.1${NC}"
    echo -e ""
    echo -e "2. Tambahkan ke file hosts:"
    echo -e "   Windows: ${WHITE}C:\\Windows\\System32\\drivers\\etc\\hosts${NC}"
    echo -e "   Linux/Mac: ${WHITE}/etc/hosts${NC}"
    echo -e ""
    echo -e "   Tambahkan 3 baris ini:"
    echo -e "   ${GREEN}$IP1 $DOMAIN1${NC}"
    echo -e "   ${GREEN}$IP2 $DOMAIN2${NC}"
    echo -e "   ${GREEN}$IP3 $DOMAIN3${NC}"
    echo -e ""
    echo -e "3. Buka browser dan akses:"
    echo -e "   ${GREEN}http://$DOMAIN1${NC} → Tutorial DHCP"
    echo -e "   ${GREEN}http://$DOMAIN2${NC} → Tutorial CRUD"
    echo -e "   ${GREEN}http://$DOMAIN3${NC} → Tutorial Apache2"
    echo -e "   ${GREEN}http://$IP2/crud/${NC} → Aplikasi CRUD"
    echo -e ""
    echo -e "4. Test DNS dari terminal Debian:"
    echo -e "   ${GREEN}nslookup $DOMAIN1 127.0.0.1${NC}"
    echo -e "   ${GREEN}nslookup $DOMAIN2 127.0.0.1${NC}"
    echo -e "   ${GREEN}nslookup $DOMAIN3 127.0.0.1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "Tekan Enter..."
}

# ======================= INSTALL CRUD SAJA =======================
install_crud() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🗄️ INSTALL CRUD SISWA                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    apt update -qq
    apt install -y apache2 php libapache2-mod-php php-sqlite3
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
    
    echo -e "\n${GREEN}✅ CRUD SISWA BERHASIL!${NC}"
    echo -e "   🌐 Akses: http://$SERVER_IP/crud/${NC}"
    read -p "Tekan Enter..."
}

# ======================= CEK STATUS =======================
check_status() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              📊 CEK STATUS SERVICE             ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if systemctl is-active --quiet apache2; then
        echo -e "  🌍 Apache2  | ${GREEN}✅ ACTIVE${NC}"
    else
        echo -e "  🌍 Apache2  | ${RED}❌ INACTIVE${NC}"
    fi
    
    if systemctl is-active --quiet bind9; then
        echo -e "  🔍 Bind9    | ${GREEN}✅ ACTIVE${NC}"
    else
        echo -e "  🔍 Bind9    | ${RED}❌ INACTIVE${NC}"
    fi
    
    if systemctl is-active --quiet mariadb; then
        echo -e "  🗄️ MariaDB  | ${GREEN}✅ ACTIVE${NC}"
    else
        echo -e "  🗄️ MariaDB  | ${RED}❌ INACTIVE${NC}"
    fi
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
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
        systemctl stop apache2 bind9 mariadb 2>/dev/null
        apt remove --purge -y apache2* bind9* mariadb* php* 2>/dev/null
        rm -rf /etc/apache2 /etc/bind /var/www/html /var/lib/mysql
        rm -rf /etc/roundcube /var/lib/roundcube /usr/share/roundcube
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
    echo "║                                                                             ║"
    echo "║                    🚀 FAHTECH 3 DNS SERVER INSTALLER                       ║"
    echo "║                                                                             ║"
    echo "╠════════════════════════════════════════════════════════════════════════════╣"
    echo "║                                                                             ║"
    echo "║  1.  🚀 Install 3 DNS Server SEKALIGUS (DHCP + CRUD + APACHE2)             ║"
    echo "║  2.  📚 Install CRUD Siswa (Tambah/Edit/Hapus/Cari)                        ║"
    echo "║  3.  📊 Cek Status Service                                                 ║"
    echo "║  4.  🗑️ Hapus SEMUA Service + Folder                                       ║"
    echo "║  5.  🚪 Exit                                                               ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "👉 Pilih menu [1-5]: " menu
    
    case $menu in
        1) install_3dns ;;
        2) install_crud ;;
        3) check_status ;;
        4) uninstall_all ;;
        5) 
            echo -e "${GREEN}👋 Terima kasih!${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}❌ Pilihan salah!${NC}"
            sleep 1
            ;;
    esac
done
