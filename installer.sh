#!/bin/bash

# ============================================================
#   FAHTECH - CRUD SISWA INSTALLER
#   PASTI BERHASIL | BISA AKSES WEB
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              🗄️ CRUD SISWA INSTALLER                            ║"
echo "║         (Nama + Rombel + NIS) - PASTI BERHASIL                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Jalankan sebagai root!${NC}"
    exit 1
fi

# Deteksi IP
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

# Install CRUD
install_crud() {
    clear
    echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         🗄️ INSTALL CRUD SISWA                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
    
    # Pilih IP
    show_interfaces
    echo -e "\n${YELLOW}👉 Pilih IP untuk CRUD Siswa (pilih nomor):${NC}"
    read -p "Nomor [1-${#INTERFACES[@]}]: " choice
    
    if [[ $choice -ge 1 && $choice -le ${#INTERFACES[@]} ]]; then
        IFS='|' read -r CRUD_IFACE CRUD_IP <<< "${INTERFACES[$((choice-1))]}"
        echo -e "${GREEN}✅ Terpilih: $CRUD_IFACE (IP: $CRUD_IP)${NC}"
    else
        CRUD_IP=$(hostname -I | awk '{print $1}')
        echo -e "${YELLOW}⚠️ Menggunakan IP default: $CRUD_IP${NC}"
    fi
    
    # Install Apache2 jika belum
    if ! command -v apache2 &> /dev/null; then
        apt update -qq
        apt install -y apache2 php libapache2-mod-php php-sqlite3
    fi
    
    # Hapus folder CRUD lama jika ada
    rm -rf /var/www/html/crud
    
    # Buat folder CRUD
    mkdir -p /var/www/html/crud
    
    # Buat file index.php
    cat > /var/www/html/crud/index.php <<'EOF'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRUD Siswa - FahTech</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            padding: 40px;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            padding: 35px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 {
            color: #667eea;
            margin-bottom: 5px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 20px;
            font-size: 14px;
        }
        .status {
            background: #4CAF50;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            display: inline-block;
            font-size: 12px;
            margin-bottom: 20px;
        }
        .form-card {
            background: #f8f9fa;
            padding: 25px;
            border-radius: 15px;
            margin: 20px 0;
        }
        .form-group {
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
        }
        .form-group input {
            flex: 1;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 8px;
            font-size: 14px;
        }
        .form-group input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 25px;
            border-radius: 8px;
            cursor: pointer;
            font-weight: bold;
            transition: 0.3s;
        }
        button:hover {
            background: #5a67d8;
            transform: translateY(-2px);
        }
        .search-box {
            margin: 20px 0;
            display: flex;
            gap: 10px;
        }
        .search-box input {
            flex: 1;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 8px;
        }
        .search-box button {
            padding: 12px 25px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        th {
            background: #667eea;
            color: white;
        }
        tr:hover {
            background: #f5f5f5;
        }
        .edit-btn {
            background: #3498db;
            color: white;
            padding: 5px 12px;
            border-radius: 5px;
            text-decoration: none;
            display: inline-block;
            margin-right: 5px;
        }
        .delete-btn {
            background: #e74c3c;
            color: white;
            padding: 5px 12px;
            border-radius: 5px;
            text-decoration: none;
            display: inline-block;
        }
        .edit-form {
            background: #fff3cd;
            padding: 20px;
            border-radius: 15px;
            margin-top: 30px;
            border-left: 5px solid #ffc107;
        }
        .success {
            background: #d4edda;
            color: #155724;
            padding: 12px;
            border-radius: 8px;
            margin: 15px 0;
        }
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 12px;
            border-radius: 8px;
            margin: 15px 0;
        }
        .footer {
            margin-top: 30px;
            text-align: center;
            color: #888;
            font-size: 12px;
        }
        @media (max-width: 768px) {
            .form-group { flex-direction: column; }
            .container { padding: 20px; }
            table { font-size: 12px; }
            th, td { padding: 8px; }
        }
    </style>
</head>
<body>
<div class="container">
    <h1>📚 FAHTECH CRUD - Data Siswa</h1>
    <div class="subtitle">Sistem Manajemen Data Siswa (Nama, Rombel, NIS)</div>
    <div class="status">✅ DATABASE ACTIVE | SQLite3</div>
    
    <?php
    $db = new SQLite3('/var/www/html/crud/siswa.db');
    $db->exec("CREATE TABLE IF NOT EXISTS siswa (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        rombel TEXT NOT NULL,
        nis TEXT NOT NULL UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )");
    
    // TAMBAH DATA
    if (isset($_POST['add']) && !empty($_POST['nama']) && !empty($_POST['rombel']) && !empty($_POST['nis'])) {
        $nama = SQLite3::escapeString($_POST['nama']);
        $rombel = SQLite3::escapeString($_POST['rombel']);
        $nis = SQLite3::escapeString($_POST['nis']);
        
        $check = $db->querySingle("SELECT COUNT(*) FROM siswa WHERE nis = '$nis'");
        if ($check > 0) {
            echo "<div class='error'>❌ Gagal! NIS '$nis' sudah terdaftar!</div>";
        } else {
            $db->exec("INSERT INTO siswa (nama, rombel, nis) VALUES ('$nama', '$rombel', '$nis')");
            echo "<div class='success'>✅ Data siswa berhasil ditambahkan!</div>";
        }
    }
    
    // HAPUS DATA
    if (isset($_GET['delete'])) {
        $id = (int)$_GET['delete'];
        $db->exec("DELETE FROM siswa WHERE id = $id");
        echo "<div class='success'>✅ Data berhasil dihapus!</div>";
    }
    
    // UPDATE DATA
    if (isset($_POST['update'])) {
        $id = (int)$_POST['id'];
        $nama = SQLite3::escapeString($_POST['nama']);
        $rombel = SQLite3::escapeString($_POST['rombel']);
        $nis = SQLite3::escapeString($_POST['nis']);
        
        $check = $db->querySingle("SELECT COUNT(*) FROM siswa WHERE nis = '$nis' AND id != $id");
        if ($check > 0) {
            echo "<div class='error'>❌ Gagal! NIS '$nis' sudah terdaftar untuk siswa lain!</div>";
        } else {
            $db->exec("UPDATE siswa SET nama='$nama', rombel='$rombel', nis='$nis' WHERE id=$id");
            echo "<div class='success'>✅ Data siswa berhasil diupdate!</div>";
        }
    }
    
    // PENCARIAN
    $search = isset($_GET['search']) ? SQLite3::escapeString($_GET['search']) : '';
    $where = $search ? "WHERE nama LIKE '%$search%' OR nis LIKE '%$search%' OR rombel LIKE '%$search%'" : "";
    $result = $db->query("SELECT * FROM siswa $where ORDER BY id DESC");
    ?>
    
    <!-- FORM TAMBAH DATA -->
    <div class="form-card">
        <h3 style="margin-bottom: 15px;">➕ Tambah Data Siswa</h3>
        <form method="post">
            <div class="form-group">
                <input type="text" name="nama" placeholder="Nama Lengkap *" required>
                <input type="text" name="rombel" placeholder="Rombel / Kelas *" required>
                <input type="text" name="nis" placeholder="NIS (Nomor Induk Siswa) *" required>
                <button type="submit" name="add">💾 Simpan Data</button>
            </div>
        </form>
    </div>
    
    <!-- FORM PENCARIAN -->
    <div class="search-box">
        <form method="get" style="display: flex; gap: 10px; width: 100%;">
            <input type="text" name="search" placeholder="🔍 Cari berdasarkan Nama / NIS / Rombel..." value="<?= htmlspecialchars($search) ?>">
            <button type="submit">Cari</button>
            <?php if($search): ?>
                <a href="?" style="background: #6c757d; color: white; padding: 12px 20px; border-radius: 8px; text-decoration: none;">Reset</a>
            <?php endif; ?>
        </form>
    </div>
    
    <!-- TABEL DATA -->
    <h3 style="margin: 20px 0 10px;">📋 Daftar Siswa</h3>
    <div style="overflow-x: auto;">
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Nama Lengkap</th>
                    <th>Rombel / Kelas</th>
                    <th>NIS</th>
                    <th>Tanggal Dibuat</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                <?php while ($row = $result->fetchArray()): ?>
                <tr>
                    <td><?= $row['id'] ?></td>
                    <td><strong><?= htmlspecialchars($row['nama']) ?></strong></td>
                    <td><?= htmlspecialchars($row['rombel']) ?></td>
                    <td><code><?= htmlspecialchars($row['nis']) ?></code></td>
                    <td><?= date('d/m/Y H:i', strtotime($row['created_at'])) ?></td>
                    <td>
                        <a href="?edit=<?= $row['id'] ?>" class="edit-btn">✏️ Edit</a>
                        <a href="?delete=<?= $row['id'] ?>" class="delete-btn" onclick="return confirm('Yakin hapus data ini?')">🗑️ Hapus</a>
                    </td>
                </tr>
                <?php endwhile; ?>
            </tbody>
        </table>
    </div>
    
    <?php if (isset($_GET['edit'])): 
        $id = (int)$_GET['edit'];
        $edit = $db->query("SELECT * FROM siswa WHERE id=$id")->fetchArray();
        if ($edit):
    ?>
    <div class="edit-form">
        <h3>✏️ Edit Data Siswa (ID: <?= $edit['id'] ?>)</h3>
        <form method="post">
            <input type="hidden" name="id" value="<?= $edit['id'] ?>">
            <div class="form-group">
                <input type="text" name="nama" value="<?= htmlspecialchars($edit['nama']) ?>" required>
                <input type="text" name="rombel" value="<?= htmlspecialchars($edit['rombel']) ?>" required>
                <input type="text" name="nis" value="<?= htmlspecialchars($edit['nis']) ?>" required>
                <button type="submit" name="update">💾 Update Data</button>
                <a href="?" style="background: #6c757d; color: white; padding: 12px 20px; border-radius: 8px; text-decoration: none;">Batal</a>
            </div>
        </form>
    </div>
    <?php endif; endif; ?>
    
    <div class="footer">
        <strong>FahTech CRUD - Data Siswa</strong> | Total Data: <?= $db->querySingle("SELECT COUNT(*) FROM siswa") ?> siswa
    </div>
</div>
</body>
</html>
EOF
    
    # Set permission
    chown -R www-data:www-data /var/www/html/crud
    systemctl restart apache2
    
    echo -e "\n${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   ✅ CRUD SISWA BERHASIL DIINSTALL!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════════${NC}"
    echo -e ""
    echo -e "${CYAN}🌐 AKSES CRUD:${NC}"
    echo -e "   ${GREEN}http://$CRUD_IP/crud/${NC}"
    echo -e ""
    echo -e "${CYAN}📌 FITUR:${NC}"
    echo -e "   ${GREEN}✨ Tambah Data | ✏️ Edit Data | 🗑️ Hapus Data | 🔍 Cari Data${NC}"
    echo -e ""
    echo -e "${YELLOW}💡 Jika masih 404, jalankan perintah:${NC}"
    echo -e "   ${WHITE}systemctl restart apache2${NC}"
    echo -e "   ${WHITE}ls -la /var/www/html/crud/${NC}"
    
    read -p "Tekan Enter..."
}

# ======================= MENU =======================
while true; do
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🗄️ CRUD SISWA INSTALLER                      ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║                                                                   ║"
    echo "║  1.  🗄️ Install CRUD Siswa (PASTI BERHASIL)                      ║"
    echo "║  2.  🚪 Exit                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    read -p "👉 Pilih menu [1-2]: " menu
    
    case $menu in
        1) install_crud ;;
        2) 
            echo -e "${GREEN}👋 Terima kasih!${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}❌ Pilihan salah!${NC}"
            sleep 1
            ;;
    esac
done
