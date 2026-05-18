#!/bin/bash
# ============================================================
#  SETUP SERVER OTOMATIS - TJKT SMK WIKRAMA BOGOR
#  Support: Debian 12 / Ubuntu 22.04
#  Versi  : 2.0
# ============================================================

# ─── Warna & Simbol ────────────────────────────────────────
RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
BLUE='\033[0;34m';   CYAN='\033[0;36m';  MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  BOLD='\033[1m';     RESET='\033[0m'
CHECK="✓"; CROSS="✗"; ARROW="➤"; STAR="★"

# ─── Banner ────────────────────────────────────────────────
banner() {
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ████████╗     ██╗██╗  ██╗████████╗                        ║
║       ██╔══╝    ██╔╝██║ ██╔╝╚══██╔══╝                        ║
║       ██║      ██╔╝ █████╔╝    ██║                           ║
║       ██║     ██╔╝  ██╔═██╗   ██║                            ║
║       ██║    ██╔╝   ██║  ██╗  ██║                            ║
║       ╚═╝   ╚═╝    ╚═╝  ╚═╝  ╚═╝                            ║
║                                                              ║
║         SMK WIKRAMA BOGOR  ─  Server Setup Tool              ║
║         DHCP ▪ DNS ▪ Web ▪ FTP ▪ Samba ▪ Mail ▪ WP          ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${CYAN}${BOLD}  Script Otomatis Konfigurasi Server Lengkap${RESET}"
echo -e "${YELLOW}  Debian 12 / Ubuntu 22.04  │  TJKT SMK Wikrama Bogor${RESET}"
echo ""
}

# ─── Fungsi Helper ─────────────────────────────────────────
log_info()    { echo -e "${CYAN}${ARROW} ${1}${RESET}"; }
log_ok()      { echo -e "${GREEN}${CHECK} ${1}${RESET}"; }
log_warn()    { echo -e "${YELLOW}⚠  ${1}${RESET}"; }
log_error()   { echo -e "${RED}${CROSS} ${1}${RESET}"; }
log_section() {
  echo ""
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${MAGENTA}${BOLD}  ${STAR} ${1}${RESET}"
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

run_cmd() {
  # Jalankan perintah dan tampilkan status
  local desc="$1"; shift
  echo -ne "  ${BLUE}${ARROW}${RESET} ${desc}... "
  if "$@" &>/dev/null; then
    echo -e "${GREEN}${CHECK}${RESET}"
    return 0
  else
    echo -e "${RED}${CROSS} (gagal, lanjut)${RESET}"
    return 1
  fi
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "Script harus dijalankan sebagai root!"
    echo -e "  Gunakan: ${YELLOW}sudo bash $0${RESET}"
    exit 1
  fi
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME="$NAME"
    OS_VER="$VERSION_ID"
  else
    log_error "OS tidak didukung (perlu Debian 12 atau Ubuntu 22.04)"
    exit 1
  fi
  log_ok "OS terdeteksi: ${OS_NAME} ${OS_VER}"
}

# ─── Deteksi Interface Jaringan ────────────────────────────
detect_interfaces() {
  mapfile -t IFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v -E '^(lo|docker|veth|br-|virbr)' | tr -d ' ')
  if [[ ${#IFACES[@]} -eq 0 ]]; then
    log_error "Tidak ada interface jaringan yang terdeteksi!"
    exit 1
  fi
}

# ─── Deteksi IP yang ada ───────────────────────────────────
detect_existing_ips() {
  mapfile -t EXISTING_IPS < <(ip -4 addr show | grep 'inet ' | awk '{print $2}' | grep -v '127.0.0.1')
}

# ─── Fungsi ambil IP dari CIDR ─────────────────────────────
cidr_to_ip()      { echo "${1%/*}"; }
cidr_to_prefix()  { echo "${1#*/}"; }
cidr_to_network() {
  local ip prefix
  ip="$1"; prefix="$2"
  IFS='.' read -r i1 i2 i3 i4 <<< "$ip"
  local mask=$(( 0xFFFFFFFF << (32 - prefix) & 0xFFFFFFFF ))
  local n1=$(( i1 & (mask>>24) ))
  local n2=$(( i2 & (mask>>16 & 0xFF) ))
  local n3=$(( i3 & (mask>>8  & 0xFF) ))
  local n4=$(( i4 & (mask     & 0xFF) ))
  echo "${n1}.${n2}.${n3}.${n4}"
}
cidr_to_netmask() {
  local prefix=$1
  local mask=""
  for i in $(seq 1 4); do
    local bits=$(( prefix > 8 ? 8 : prefix ))
    local octet=$(( 256 - (1 << (8 - bits)) ))
    mask+="${octet}"
    [[ $i -lt 4 ]] && mask+="."
    prefix=$(( prefix - bits ))
    [[ $prefix -lt 0 ]] && prefix=0
  done
  echo "$mask"
}
ip_plus() {
  # Tambah nilai ke oktet terakhir IP
  IFS='.' read -r a b c d <<< "$1"
  echo "${a}.${b}.${c}.$((d + $2))"
}

# ══════════════════════════════════════════════════════════
#  FASE 1 : INPUT INTERAKTIF
# ══════════════════════════════════════════════════════════
interactive_input() {
  log_section "KONFIGURASI AWAL — Jawab pertanyaan berikut"

  # ── 1. Pilih Interface untuk DHCP ──────────────────────
  echo ""
  echo -e "${WHITE}${BOLD}[1/4] Interface Jaringan Tersedia:${RESET}"
  for i in "${!IFACES[@]}"; do
    local iface="${IFACES[$i]}"
    local ip_now
    ip_now=$(ip -4 addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -1)
    local ip_info=""
    [[ -n "$ip_now" ]] && ip_info=" ${YELLOW}(IP saat ini: ${ip_now})${RESET}"
    echo -e "  ${CYAN}[$((i+1))]${RESET} ${iface}${ip_info}"
  done
  echo ""
  while true; do
    read -rp "$(echo -e "${GREEN}${ARROW}${RESET} Pilih interface untuk DHCP server [1-${#IFACES[@]}]: ")" iface_idx
    if [[ "$iface_idx" =~ ^[0-9]+$ ]] && (( iface_idx >= 1 && iface_idx <= ${#IFACES[@]} )); then
      DHCP_IFACE="${IFACES[$((iface_idx-1))]}"
      log_ok "Interface dipilih: ${DHCP_IFACE}"
      break
    fi
    log_warn "Masukkan angka yang valid (1-${#IFACES[@]})"
  done

  # ── 2. IP Static untuk Interface ───────────────────────
  echo ""
  echo -e "${WHITE}${BOLD}[2/4] IP Static untuk ${DHCP_IFACE}:${RESET}"
  echo -e "  ${YELLOW}Contoh: 10.1.27.1/24 atau 192.168.100.1/24${RESET}"
  while true; do
    read -rp "$(echo -e "${GREEN}${ARROW}${RESET} Masukkan IP static (format IP/prefix): ")" STATIC_CIDR
    if [[ "$STATIC_CIDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
      STATIC_IP=$(cidr_to_ip "$STATIC_CIDR")
      STATIC_PREFIX=$(cidr_to_prefix "$STATIC_CIDR")
      NETMASK=$(cidr_to_netmask "$STATIC_PREFIX")
      NETWORK=$(cidr_to_network "$STATIC_IP" "$STATIC_PREFIX")
      DHCP_RANGE_START=$(ip_plus "$STATIC_IP" 100)
      DHCP_RANGE_END=$(ip_plus "$STATIC_IP" 200)
      BROADCAST="${NETWORK%.*}.255"
      log_ok "IP Static  : ${STATIC_IP}"
      log_ok "Netmask    : ${NETMASK}"
      log_ok "Network    : ${NETWORK}/${STATIC_PREFIX}"
      log_ok "DHCP Range : ${DHCP_RANGE_START} — ${DHCP_RANGE_END}"
      break
    fi
    log_warn "Format tidak valid. Gunakan contoh: 10.1.27.1/24"
  done

  # ── 3. Domain ──────────────────────────────────────────
  echo ""
  echo -e "${WHITE}${BOLD}[3/4] Nama Domain:${RESET}"
  echo -e "  ${YELLOW}Contoh: wikrama.local atau sekolah.net${RESET}"
  while true; do
    read -rp "$(echo -e "${GREEN}${ARROW}${RESET} Masukkan nama domain: ")" DOMAIN
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$ ]] || \
       [[ "$DOMAIN" =~ ^[a-zA-Z0-9]+\.[a-zA-Z]+$ ]]; then
      log_ok "Domain : ${DOMAIN}"
      break
    fi
    log_warn "Domain tidak valid. Contoh: wikrama.local"
  done

  # ── 4. IP DNS Server ───────────────────────────────────
  echo ""
  echo -e "${WHITE}${BOLD}[4/4] IP untuk DNS Server:${RESET}"
  echo -e "  ${YELLOW}IP yang terdeteksi di sistem ini:${RESET}"
  for ip in "${EXISTING_IPS[@]}"; do
    echo -e "    ${CYAN}• ${ip}${RESET}"
  done
  echo -e "  ${YELLOW}(Anda bisa pakai ${STATIC_IP} atau IP lain)${RESET}"
  while true; do
    read -rp "$(echo -e "${GREEN}${ARROW}${RESET} Masukkan IP DNS server [default: ${STATIC_IP}]: ")" DNS_IP
    [[ -z "$DNS_IP" ]] && DNS_IP="$STATIC_IP"
    if [[ "$DNS_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      log_ok "DNS IP : ${DNS_IP}"
      break
    fi
    log_warn "Format IP tidak valid"
  done

  # ── Konfirmasi ─────────────────────────────────────────
  echo ""
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${WHITE}${BOLD}  RINGKASAN KONFIGURASI${RESET}"
  echo -e "${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  Interface DHCP   : ${CYAN}${DHCP_IFACE}${RESET}"
  echo -e "  IP Static        : ${CYAN}${STATIC_IP}${RESET}"
  echo -e "  Subnet / Mask    : ${CYAN}${NETWORK} / ${NETMASK}${RESET}"
  echo -e "  DHCP Range       : ${CYAN}${DHCP_RANGE_START} — ${DHCP_RANGE_END}${RESET}"
  echo -e "  Domain           : ${CYAN}${DOMAIN}${RESET}"
  echo -e "  IP DNS           : ${CYAN}${DNS_IP}${RESET}"
  echo -e "  Virtual Hosts    : ${CYAN}www.${DOMAIN}  mail.${DOMAIN}  crud.${DOMAIN}${RESET}"
  echo ""
  read -rp "$(echo -e "${YELLOW}Lanjutkan instalasi? (y/N): ")" CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Instalasi dibatalkan.${RESET}"
    exit 0
  fi
}

# ══════════════════════════════════════════════════════════
#  FASE 2 : HAPUS LAYANAN LAMA
# ══════════════════════════════════════════════════════════
cleanup_old_services() {
  log_section "PEMBERSIHAN — Menghapus layanan lama"

  SERVICES_TO_REMOVE=(
    apache2 mysql-server mysql-common mariadb-server mariadb-common
    php* vsftpd samba samba-common isc-dhcp-server bind9 bind9utils
    postfix dovecot-core dovecot-imapd dovecot-pop3d
    wordpress php-mysql libapache2-mod-php
  )

  run_cmd "Menghentikan semua layanan" systemctl stop apache2 mysql mariadb vsftpd smbd nmbd isc-dhcp-server named postfix dovecot 2>/dev/null || true
  run_cmd "Menghapus paket lama"       apt-get purge -y "${SERVICES_TO_REMOVE[@]}" 2>/dev/null || true
  run_cmd "Membersihkan dependensi"    apt-get autoremove -y
  run_cmd "Membersihkan apt cache"     apt-get clean

  # Hapus direktori konfigurasi
  local DIRS=(
    /etc/apache2 /etc/mysql /etc/php /etc/vsftpd.conf
    /etc/samba /etc/dhcp /etc/bind /etc/postfix /etc/dovecot
    /var/lib/mysql /var/www/html/* /var/www/wordpress
    /srv/ftp /home/ftpuser /etc/apache2/sites-available /etc/apache2/sites-enabled
  )
  for d in "${DIRS[@]}"; do
    rm -rf "$d" 2>/dev/null || true
  done
  log_ok "Pembersihan selesai"
}

# ══════════════════════════════════════════════════════════
#  FASE 3 : UPDATE & INSTALL PAKET
# ══════════════════════════════════════════════════════════
install_packages() {
  log_section "INSTALASI PAKET"
  run_cmd "Update apt repository" apt-get update -y

  PACKAGES=(
    isc-dhcp-server bind9 bind9utils bind9-doc
    apache2 php php-mysql php-curl php-gd php-xml php-mbstring php-zip
    libapache2-mod-php mariadb-server mariadb-client
    vsftpd samba samba-common-bin
    postfix postfix-mysql dovecot-core dovecot-imapd dovecot-pop3d
    wget curl unzip net-tools dnsutils
  )

  run_cmd "Menginstall semua paket" apt-get install -y "${PACKAGES[@]}"
  log_ok "Semua paket berhasil diinstall"
}

# ══════════════════════════════════════════════════════════
#  FASE 4 : KONFIGURASI IP STATIC
# ══════════════════════════════════════════════════════════
configure_static_ip() {
  log_section "KONFIGURASI IP STATIC — ${DHCP_IFACE}"

  # Deteksi apakah menggunakan netplan atau interfaces
  if [[ -d /etc/netplan ]]; then
    # Ubuntu — Netplan
    local NETPLAN_FILE="/etc/netplan/99-server-setup.yaml"
    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ${DHCP_IFACE}:
      dhcp4: false
      addresses:
        - ${STATIC_CIDR}
      nameservers:
        addresses: [${DNS_IP}, 8.8.8.8]
EOF
    run_cmd "Menerapkan konfigurasi netplan" netplan apply
  else
    # Debian — /etc/network/interfaces
    local IFACE_FILE="/etc/network/interfaces"
    # Hapus blok interface lama jika ada
    sed -i "/iface ${DHCP_IFACE}/,/^$/d" "$IFACE_FILE" 2>/dev/null || true
    cat >> "$IFACE_FILE" <<EOF

auto ${DHCP_IFACE}
iface ${DHCP_IFACE} inet static
    address ${STATIC_IP}
    netmask ${NETMASK}
    network ${NETWORK}
    broadcast ${BROADCAST}
    dns-nameservers ${DNS_IP} 8.8.8.8
EOF
    run_cmd "Merestart networking" systemctl restart networking
  fi

  # Set IP langsung agar aktif sekarang
  ip addr flush dev "$DHCP_IFACE" 2>/dev/null || true
  ip addr add "${STATIC_CIDR}" dev "$DHCP_IFACE" 2>/dev/null || true
  ip link set "$DHCP_IFACE" up 2>/dev/null || true
  log_ok "IP Static ${STATIC_IP} dikonfigurasi pada ${DHCP_IFACE}"
}

# ══════════════════════════════════════════════════════════
#  FASE 5 : DHCP SERVER
# ══════════════════════════════════════════════════════════
configure_dhcp() {
  log_section "DHCP SERVER — isc-dhcp-server"

  # Set interface
  local DHCP_DEFAULT="/etc/default/isc-dhcp-server"
  if grep -q "INTERFACESv4" "$DHCP_DEFAULT" 2>/dev/null; then
    sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"${DHCP_IFACE}\"/" "$DHCP_DEFAULT"
  else
    echo "INTERFACESv4=\"${DHCP_IFACE}\"" >> "$DHCP_DEFAULT"
  fi

  cat > /etc/dhcp/dhcpd.conf <<EOF
# DHCP Server - TJKT SMK Wikrama Bogor
# Dikonfigurasi oleh setup-server-tjkt.sh

default-lease-time 600;
max-lease-time 7200;

subnet ${NETWORK} netmask ${NETMASK} {
    range ${DHCP_RANGE_START} ${DHCP_RANGE_END};
    option routers ${STATIC_IP};
    option subnet-mask ${NETMASK};
    option domain-name "${DOMAIN}";
    option domain-name-servers ${DNS_IP}, 8.8.8.8;
    option broadcast-address ${BROADCAST};
    default-lease-time 600;
    max-lease-time 7200;
}
EOF

  run_cmd "Enable & start isc-dhcp-server" systemctl enable isc-dhcp-server && systemctl restart isc-dhcp-server
  log_ok "DHCP server aktif — range ${DHCP_RANGE_START}–${DHCP_RANGE_END}"
}

# ══════════════════════════════════════════════════════════
#  FASE 6 : DNS BIND9
# ══════════════════════════════════════════════════════════
configure_dns() {
  log_section "DNS BIND9 — 3 Nameserver"

  local ZONE_DIR="/etc/bind"
  local ZONE_FILE="${ZONE_DIR}/db.${DOMAIN}"
  local ZONE_REV="${ZONE_DIR}/db.${DNS_IP%.*}"
  local SERIAL=$(date +%Y%m%d01)
  local OCTET_REV="${DNS_IP##*.}"
  local NET_REV
  IFS='.' read -r a b c d <<< "$DNS_IP"
  NET_REV="${c}.${b}.${a}"

  # named.conf.local
  cat > "${ZONE_DIR}/named.conf.local" <<EOF
// BIND9 Zones - ${DOMAIN}

zone "${DOMAIN}" {
    type master;
    file "${ZONE_FILE}";
};

zone "${NET_REV}.in-addr.arpa" {
    type master;
    file "${ZONE_REV}";
};
EOF

  # named.conf.options
  cat > "${ZONE_DIR}/named.conf.options" <<EOF
options {
    directory "/var/cache/bind";

    forwarders {
        8.8.8.8;
        8.8.4.4;
    };

    dnssec-validation auto;
    listen-on { any; };
    allow-query { any; };
    recursion yes;
};
EOF

  # Zone forward
  cat > "$ZONE_FILE" <<EOF
\$TTL 604800
@   IN  SOA  ns1.${DOMAIN}. admin.${DOMAIN}. (
             ${SERIAL}   ; Serial
             604800      ; Refresh
             86400       ; Retry
             2419200     ; Expire
             604800 )    ; Negative Cache TTL

; Nameservers
@   IN  NS   ns1.${DOMAIN}.
@   IN  NS   ns2.${DOMAIN}.
@   IN  NS   ns3.${DOMAIN}.

; A Records Nameservers
ns1 IN  A    ${DNS_IP}
ns2 IN  A    ${DNS_IP}
ns3 IN  A    ${DNS_IP}

; A Records Virtual Hosts
@   IN  A    ${DNS_IP}
www IN  A    ${DNS_IP}
mail IN  A   ${DNS_IP}
crud IN  A   ${DNS_IP}
ftp  IN  A   ${DNS_IP}

; CNAME
smtp    IN  CNAME  mail.${DOMAIN}.
pop3    IN  CNAME  mail.${DOMAIN}.
imap    IN  CNAME  mail.${DOMAIN}.

; MX Record
@   IN  MX  10  mail.${DOMAIN}.
EOF

  # Zone reverse
  cat > "$ZONE_REV" <<EOF
\$TTL 604800
@   IN  SOA  ns1.${DOMAIN}. admin.${DOMAIN}. (
             ${SERIAL}
             604800
             86400
             2419200
             604800 )

@   IN  NS   ns1.${DOMAIN}.
@   IN  NS   ns2.${DOMAIN}.
@   IN  NS   ns3.${DOMAIN}.

${OCTET_REV}  IN  PTR  ${DOMAIN}.
${OCTET_REV}  IN  PTR  www.${DOMAIN}.
${OCTET_REV}  IN  PTR  mail.${DOMAIN}.
${OCTET_REV}  IN  PTR  crud.${DOMAIN}.
EOF

  run_cmd "Cek konfigurasi BIND9"        named-checkconf
  run_cmd "Cek zone forward"             named-checkzone "$DOMAIN" "$ZONE_FILE"
  run_cmd "Enable & restart BIND9"       systemctl enable named bind9 2>/dev/null; systemctl restart named 2>/dev/null || systemctl restart bind9
  log_ok "DNS BIND9 aktif — ns1/ns2/ns3.${DOMAIN} → ${DNS_IP}"
}

# ══════════════════════════════════════════════════════════
#  FASE 7 : APACHE2 + VIRTUAL HOSTS
# ══════════════════════════════════════════════════════════
configure_apache() {
  log_section "APACHE2 — Virtual Hosts"

  run_cmd "Enable mod_rewrite" a2enmod rewrite
  run_cmd "Enable mod_alias"   a2enmod alias

  mkdir -p /var/www/{main,mail,crud}

  # ── Halaman Utama (www.domain) ──────────────────────────
  cat > /var/www/main/index.php <<'PHPEOF'
<?php
$domain   = getenv('SERVER_DOMAIN') ?: $_SERVER['SERVER_NAME'];
$dns_ip   = getenv('DNS_IP')        ?: $_SERVER['SERVER_ADDR'];
$materi   = ['AIJ','TLJ','Pemrograman Web','Basis Data','PKK'];
$services = [
  ['icon'=>'🌐','name'=>'Web Server','url'=>"http://{$dns_ip}",'desc'=>'Apache2 Virtual Host'],
  ['icon'=>'📧','name'=>'Mail Server','url'=>"http://mail.{$domain}",'desc'=>'Postfix + Dovecot'],
  ['icon'=>'👥','name'=>'CRUD Siswa','url'=>"http://crud.{$domain}",'desc'=>'Manajemen Data Siswa'],
  ['icon'=>'📁','name'=>'FTP Server','url'=>"ftp://{$dns_ip}",'desc'=>'vsftpd — ftpuser'],
  ['icon'=>'📂','name'=>'Samba Share','url'=>"smb://{$dns_ip}/tjkt-wikrama",'desc'=>'\\\\{$dns_ip}\\tjkt-wikrama'],
];
?>
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TJKT SMK Wikrama Bogor</title>
<style>
  :root{--blue:#1e3a8a;--sky:#0ea5e9;--green:#10b981;--amber:#f59e0b;--red:#ef4444;--purple:#8b5cf6}
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#0f172a 0%,#1e3a8a 50%,#0f172a 100%);min-height:100vh;color:#e2e8f0}
  .hero{text-align:center;padding:60px 20px 40px;position:relative;overflow:hidden}
  .hero::before{content:'';position:absolute;top:-50%;left:-50%;width:200%;height:200%;background:radial-gradient(ellipse at center,rgba(14,165,233,0.1) 0%,transparent 60%);animation:pulse 4s ease-in-out infinite}
  @keyframes pulse{0%,100%{opacity:.5}50%{opacity:1}}
  .badge{display:inline-block;background:linear-gradient(90deg,var(--sky),var(--purple));padding:6px 20px;border-radius:999px;font-size:.8rem;font-weight:700;letter-spacing:2px;text-transform:uppercase;margin-bottom:20px}
  h1{font-size:3rem;font-weight:900;background:linear-gradient(90deg,#fff,var(--sky));-webkit-background-clip:text;-webkit-text-fill-color:transparent;line-height:1.1}
  .subtitle{color:#94a3b8;margin-top:12px;font-size:1.1rem}
  .ip-badge{display:inline-flex;align-items:center;gap:8px;background:rgba(14,165,233,0.15);border:1px solid rgba(14,165,233,0.3);border-radius:8px;padding:8px 16px;margin-top:16px;font-family:monospace;font-size:.95rem;color:var(--sky)}
  .container{max-width:1200px;margin:0 auto;padding:20px}
  .section-title{font-size:1.5rem;font-weight:700;color:#fff;margin-bottom:20px;display:flex;align-items:center;gap:10px}
  .section-title::after{content:'';flex:1;height:2px;background:linear-gradient(90deg,var(--sky),transparent)}
  .cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:20px;margin-bottom:40px}
  .card{background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.1);border-radius:16px;padding:24px;transition:all .3s;cursor:pointer;text-decoration:none;display:block;color:inherit}
  .card:hover{transform:translateY(-4px);border-color:var(--sky);background:rgba(14,165,233,0.1);box-shadow:0 20px 40px rgba(14,165,233,0.15)}
  .card-icon{font-size:2.5rem;margin-bottom:12px}
  .card-title{font-size:1.1rem;font-weight:700;color:#fff;margin-bottom:6px}
  .card-desc{font-size:.85rem;color:#94a3b8}
  .materi-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:16px;margin-bottom:40px}
  .materi-card{background:linear-gradient(135deg,rgba(139,92,246,0.2),rgba(14,165,233,0.1));border:1px solid rgba(139,92,246,0.3);border-radius:12px;padding:20px;text-align:center;transition:all .3s}
  .materi-card:hover{transform:scale(1.03);border-color:var(--purple)}
  .materi-num{font-size:2rem;font-weight:900;color:var(--purple);line-height:1}
  .materi-name{font-size:.95rem;font-weight:600;color:#e2e8f0;margin-top:8px}
  .status-bar{background:rgba(16,185,129,0.1);border:1px solid rgba(16,185,129,0.3);border-radius:12px;padding:16px 24px;display:flex;align-items:center;gap:12px;margin-bottom:40px}
  .status-dot{width:10px;height:10px;background:var(--green);border-radius:50%;animation:blink 1.5s infinite}
  @keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}
  footer{text-align:center;padding:30px;color:#64748b;font-size:.85rem;border-top:1px solid rgba(255,255,255,0.05)}
</style>
</head>
<body>
<div class="hero">
  <div class="badge">⚡ Server TJKT Aktif</div>
  <h1>SMK Wikrama Bogor</h1>
  <p class="subtitle">Teknik Jaringan Komputer dan Telekomunikasi</p>
  <div class="ip-badge">🖥️ IP Server: <?= htmlspecialchars($dns_ip) ?> &nbsp;|&nbsp; 🌐 Domain: <?= htmlspecialchars($domain) ?></div>
</div>

<div class="container">
  <div class="status-bar">
    <div class="status-dot"></div>
    <span style="color:#10b981;font-weight:600">Semua layanan berjalan normal</span>
    <span style="color:#64748b;margin-left:auto;font-size:.85rem"><?= date('d/m/Y H:i:s') ?></span>
  </div>

  <div class="section-title">🚀 Layanan Server</div>
  <div class="cards">
    <?php foreach($services as $s): ?>
    <a href="<?= htmlspecialchars($s['url']) ?>" class="card">
      <div class="card-icon"><?= $s['icon'] ?></div>
      <div class="card-title"><?= htmlspecialchars($s['name']) ?></div>
      <div class="card-desc"><?= htmlspecialchars($s['desc']) ?></div>
    </a>
    <?php endforeach; ?>
  </div>

  <div class="section-title">📚 Materi Pembelajaran TJKT</div>
  <div class="materi-grid">
    <?php foreach($materi as $i => $m): ?>
    <div class="materi-card">
      <div class="materi-num"><?= str_pad($i+1, 2, '0', STR_PAD_LEFT) ?></div>
      <div class="materi-name"><?= htmlspecialchars($m) ?></div>
    </div>
    <?php endforeach; ?>
  </div>
</div>
<footer>© <?= date('Y') ?> TJKT SMK Wikrama Bogor &nbsp;|&nbsp; Setup Server Otomatis v2.0</footer>
</body>
</html>
PHPEOF

  # ── Halaman Mail (mail.domain) ──────────────────────────
  cat > /var/www/mail/index.php <<'PHPEOF'
<?php $ip = $_SERVER['SERVER_ADDR']; $host = $_SERVER['SERVER_NAME']; ?>
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mail Server — TJKT Wikrama</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#1a1a2e,#16213e,#0f3460);min-height:100vh;color:#e0e0e0;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:40px 20px}
  .card{background:rgba(255,255,255,0.07);border:1px solid rgba(255,255,255,0.12);border-radius:24px;padding:48px 40px;max-width:640px;width:100%;text-align:center;backdrop-filter:blur(12px)}
  .icon{font-size:5rem;margin-bottom:16px}
  h1{font-size:2rem;font-weight:800;color:#fff;margin-bottom:8px}
  .sub{color:#94a3b8;margin-bottom:32px}
  .info-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;text-align:left;margin-bottom:32px}
  .info-item{background:rgba(255,255,255,0.06);border-radius:12px;padding:16px}
  .info-label{font-size:.75rem;color:#64748b;text-transform:uppercase;letter-spacing:1px;margin-bottom:4px}
  .info-val{font-family:monospace;font-size:.95rem;color:#67e8f9}
  .protocol-list{display:flex;flex-wrap:wrap;gap:10px;justify-content:center;margin-bottom:24px}
  .proto{background:rgba(103,232,249,0.1);border:1px solid rgba(103,232,249,0.3);color:#67e8f9;padding:6px 16px;border-radius:999px;font-size:.85rem;font-weight:600}
  .note{font-size:.8rem;color:#64748b}
</style>
</head>
<body>
<div class="card">
  <div class="icon">📧</div>
  <h1>Mail Server</h1>
  <p class="sub">Postfix (SMTP) + Dovecot (IMAP/POP3)</p>
  <div class="info-grid">
    <div class="info-item"><div class="info-label">SMTP Host</div><div class="info-val"><?=htmlspecialchars($ip)?></div></div>
    <div class="info-item"><div class="info-label">SMTP Port</div><div class="info-val">25 / 587</div></div>
    <div class="info-item"><div class="info-label">IMAP Host</div><div class="info-val"><?=htmlspecialchars($ip)?></div></div>
    <div class="info-item"><div class="info-label">IMAP Port</div><div class="info-val">143 / 993</div></div>
    <div class="info-item"><div class="info-label">POP3 Host</div><div class="info-val"><?=htmlspecialchars($ip)?></div></div>
    <div class="info-item"><div class="info-label">POP3 Port</div><div class="info-val">110 / 995</div></div>
  </div>
  <div class="protocol-list">
    <span class="proto">SMTP</span><span class="proto">IMAP</span><span class="proto">POP3</span>
    <span class="proto">Postfix</span><span class="proto">Dovecot</span>
  </div>
  <p class="note">📌 Gunakan email client (Thunderbird/Outlook) dan arahkan ke <strong><?=htmlspecialchars($ip)?></strong></p>
</div>
</body>
</html>
PHPEOF

  # ── Halaman CRUD (crud.domain) ─────────────────────────
  cat > /var/www/crud/index.php <<'PHPEOF'
<?php
// CRUD Siswa TJKT Wikrama Bogor
define('DB_HOST','localhost'); define('DB_USER','cruduser');
define('DB_PASS','CrudPass@2024'); define('DB_NAME','siswa_db');

function getDB(){
  $conn = new mysqli(DB_HOST,DB_USER,DB_PASS,DB_NAME);
  if($conn->connect_error) die(json_encode(['error'=>$conn->connect_error]));
  $conn->set_charset('utf8mb4');
  return $conn;
}

$action = $_GET['action'] ?? 'list';
$resp = [];

if($action==='list'){
  $db = getDB();
  $res = $db->query("SELECT * FROM siswa ORDER BY id DESC");
  $data = [];
  while($r = $res->fetch_assoc()) $data[] = $r;
  $resp = ['data'=>$data];
  $db->close();
} elseif($action==='add' && $_SERVER['REQUEST_METHOD']==='POST'){
  $db = getDB();
  $nis = $db->real_escape_string(trim($_POST['nis']));
  $nama = $db->real_escape_string(trim($_POST['nama']));
  $rombel = $db->real_escape_string(trim($_POST['rombel']));
  $rayon = $db->real_escape_string(trim($_POST['rayon']));
  if(!$nis||!$nama) $resp=['error'=>'NIS dan Nama wajib diisi'];
  else {
    $db->query("INSERT INTO siswa (nis,nama,rombel,rayon) VALUES ('$nis','$nama','$rombel','$rayon')");
    $resp = ['ok'=>true,'id'=>$db->insert_id];
  }
  $db->close();
} elseif($action==='delete'){
  $db = getDB();
  $id = (int)($_GET['id']??0);
  $db->query("DELETE FROM siswa WHERE id=$id");
  $resp = ['ok'=>$db->affected_rows>0];
  $db->close();
} elseif($action==='get'){
  $db = getDB();
  $id = (int)($_GET['id']??0);
  $res = $db->query("SELECT * FROM siswa WHERE id=$id");
  $resp = $res->fetch_assoc() ?: ['error'=>'not found'];
  $db->close();
} elseif($action==='update' && $_SERVER['REQUEST_METHOD']==='POST'){
  $db = getDB();
  $id = (int)($_POST['id']??0);
  $nis = $db->real_escape_string(trim($_POST['nis']));
  $nama = $db->real_escape_string(trim($_POST['nama']));
  $rombel = $db->real_escape_string(trim($_POST['rombel']));
  $rayon = $db->real_escape_string(trim($_POST['rayon']));
  $db->query("UPDATE siswa SET nis='$nis',nama='$nama',rombel='$rombel',rayon='$rayon' WHERE id=$id");
  $resp = ['ok'=>$db->affected_rows>=0];
  $db->close();
}

// Kalau ada request API
if(isset($_GET['action']) && $_GET['action']!=='page'){
  header('Content-Type: application/json');
  echo json_encode($resp);
  exit;
}
?>
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CRUD Siswa — TJKT Wikrama</title>
<style>
:root{--bg:#0d1117;--surface:#161b22;--surface2:#21262d;--border:#30363d;--accent:#58a6ff;--green:#3fb950;--red:#f85149;--amber:#e3b341;--text:#e6edf3;--muted:#8b949e}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',system-ui,sans-serif;background:var(--bg);color:var(--text);min-height:100vh}
header{background:linear-gradient(90deg,#1f2937,#111827);border-bottom:1px solid var(--border);padding:16px 32px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100;backdrop-filter:blur(8px)}
.logo{font-size:1.2rem;font-weight:700;color:#fff;display:flex;align-items:center;gap:10px}
.badge{background:linear-gradient(90deg,var(--accent),#a371f7);padding:4px 12px;border-radius:999px;font-size:.7rem;font-weight:700;color:#fff}
.container{max-width:1100px;margin:0 auto;padding:32px 20px}
.page-title{font-size:1.8rem;font-weight:800;color:#fff;margin-bottom:6px}
.page-sub{color:var(--muted);margin-bottom:32px}
.layout{display:grid;grid-template-columns:360px 1fr;gap:24px;align-items:start}
@media(max-width:768px){.layout{grid-template-columns:1fr}}
.panel{background:var(--surface);border:1px solid var(--border);border-radius:12px;overflow:hidden}
.panel-header{padding:16px 20px;border-bottom:1px solid var(--border);font-weight:700;font-size:.95rem;display:flex;align-items:center;gap:8px}
.panel-body{padding:20px}
.form-group{margin-bottom:16px}
label{display:block;font-size:.8rem;color:var(--muted);margin-bottom:6px;text-transform:uppercase;letter-spacing:.5px;font-weight:600}
input,select{width:100%;background:var(--surface2);border:1px solid var(--border);border-radius:8px;padding:10px 14px;color:var(--text);font-size:.9rem;outline:none;transition:border-color .2s}
input:focus,select:focus{border-color:var(--accent)}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;padding:10px 20px;border-radius:8px;border:none;cursor:pointer;font-size:.9rem;font-weight:600;transition:all .2s}
.btn-primary{background:var(--accent);color:#0d1117;width:100%;padding:12px}
.btn-primary:hover{background:#79c0ff;transform:translateY(-1px)}
.btn-sm{padding:6px 12px;font-size:.8rem;border-radius:6px}
.btn-danger{background:rgba(248,81,73,0.15);color:var(--red);border:1px solid rgba(248,81,73,0.3)}
.btn-danger:hover{background:rgba(248,81,73,0.3)}
.btn-edit{background:rgba(88,166,255,0.1);color:var(--accent);border:1px solid rgba(88,166,255,0.3)}
.btn-edit:hover{background:rgba(88,166,255,0.2)}
.btn-cancel{background:var(--surface2);color:var(--muted);border:1px solid var(--border);width:100%;margin-top:8px}
table{width:100%;border-collapse:collapse}
th{padding:12px 16px;text-align:left;font-size:.75rem;text-transform:uppercase;letter-spacing:.5px;color:var(--muted);border-bottom:1px solid var(--border);background:var(--surface2)}
td{padding:12px 16px;border-bottom:1px solid var(--border);font-size:.9rem;vertical-align:middle}
tr:last-child td{border-bottom:none}
tr:hover td{background:rgba(255,255,255,0.02)}
.nis-badge{background:rgba(63,185,80,0.1);color:var(--green);border:1px solid rgba(63,185,80,0.2);padding:3px 10px;border-radius:999px;font-family:monospace;font-size:.8rem}
.rombel-badge{background:rgba(88,166,255,0.1);color:var(--accent);padding:3px 10px;border-radius:6px;font-size:.8rem}
.empty{text-align:center;padding:48px;color:var(--muted)}
.empty-icon{font-size:3rem;margin-bottom:12px}
.alert{padding:12px 16px;border-radius:8px;margin-bottom:16px;font-size:.88rem}
.alert-success{background:rgba(63,185,80,0.1);border:1px solid rgba(63,185,80,0.3);color:var(--green)}
.alert-error{background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.3);color:var(--red)}
.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:24px}
.stat{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:16px;text-align:center}
.stat-num{font-size:1.8rem;font-weight:800;color:var(--accent)}
.stat-label{font-size:.75rem;color:var(--muted);margin-top:4px}
#msg{display:none}
</style>
</head>
<body>
<header>
  <div class="logo">👥 CRUD Siswa <span class="badge">TJKT Wikrama</span></div>
  <div style="color:var(--muted);font-size:.85rem"><?= date('d/m/Y') ?></div>
</header>

<div class="container">
  <div class="page-title">Manajemen Data Siswa</div>
  <div class="page-sub">TJKT — SMK Wikrama Bogor &nbsp;|&nbsp; NIS · Nama · Rombel · Rayon</div>

  <div class="stats">
    <div class="stat"><div class="stat-num" id="totalSiswa">-</div><div class="stat-label">Total Siswa</div></div>
    <div class="stat"><div class="stat-num" id="totalRombel">-</div><div class="stat-label">Rombel</div></div>
    <div class="stat"><div class="stat-num" id="totalRayon">-</div><div class="stat-label">Rayon</div></div>
  </div>

  <div class="layout">
    <div>
      <div class="panel" id="formPanel">
        <div class="panel-header">➕ <span id="formTitle">Tambah Siswa</span></div>
        <div class="panel-body">
          <div id="msg" class="alert"></div>
          <input type="hidden" id="editId">
          <div class="form-group"><label>NIS</label><input id="nis" placeholder="Nomor Induk Siswa"></div>
          <div class="form-group"><label>Nama Lengkap</label><input id="nama" placeholder="Nama lengkap siswa"></div>
          <div class="form-group"><label>Rombel</label>
            <select id="rombel">
              <option value="">Pilih Rombel</option>
              <?php foreach(['XII TJKT 1','XII TJKT 2','XII TJKT 3','XI TJKT 1','XI TJKT 2','XI TJKT 3','X TJKT 1','X TJKT 2','X TJKT 3'] as $r): ?>
              <option><?=htmlspecialchars($r)?></option>
              <?php endforeach; ?>
            </select>
          </div>
          <div class="form-group"><label>Rayon</label>
            <select id="rayon">
              <option value="">Pilih Rayon</option>
              <?php foreach(['Rayon A','Rayon B','Rayon C','Rayon D'] as $r): ?>
              <option><?=htmlspecialchars($r)?></option>
              <?php endforeach; ?>
            </select>
          </div>
          <button class="btn btn-primary" onclick="saveSiswa()">💾 Simpan Data</button>
          <button class="btn btn-cancel" id="cancelBtn" onclick="resetForm()" style="display:none">✕ Batal Edit</button>
        </div>
      </div>
    </div>

    <div class="panel">
      <div class="panel-header">📋 Daftar Siswa <span id="countBadge" style="margin-left:auto;background:rgba(88,166,255,0.15);color:var(--accent);padding:2px 10px;border-radius:999px;font-size:.75rem">0</span></div>
      <div class="panel-body" style="padding:0">
        <div id="tableWrap">
          <table>
            <thead><tr><th>#</th><th>NIS</th><th>Nama</th><th>Rombel</th><th>Rayon</th><th style="text-align:center">Aksi</th></tr></thead>
            <tbody id="tableBody"><tr><td colspan="6"><div class="empty"><div class="empty-icon">📭</div>Belum ada data</div></td></tr></tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</div>

<script>
const API = '?action=';
let siswaData = [];

async function loadSiswa(){
  const r = await fetch(API+'list');
  const j = await r.json();
  siswaData = j.data||[];
  renderTable();
  updateStats();
}

function renderTable(){
  const tb = document.getElementById('tableBody');
  if(!siswaData.length){
    tb.innerHTML='<tr><td colspan="6"><div class="empty"><div class="empty-icon">📭</div>Belum ada data siswa</div></td></tr>';
    return;
  }
  tb.innerHTML = siswaData.map((s,i)=>`
    <tr>
      <td style="color:var(--muted);font-size:.8rem">${i+1}</td>
      <td><span class="nis-badge">${s.nis}</span></td>
      <td style="font-weight:600">${s.nama}</td>
      <td><span class="rombel-badge">${s.rombel}</span></td>
      <td style="color:var(--muted)">${s.rayon}</td>
      <td style="text-align:center">
        <button class="btn btn-sm btn-edit" onclick="editSiswa(${s.id})">✏️</button>
        <button class="btn btn-sm btn-danger" onclick="delSiswa(${s.id})">🗑️</button>
      </td>
    </tr>`).join('');
  document.getElementById('countBadge').textContent = siswaData.length;
}

function updateStats(){
  document.getElementById('totalSiswa').textContent  = siswaData.length;
  document.getElementById('totalRombel').textContent = [...new Set(siswaData.map(s=>s.rombel).filter(Boolean))].length;
  document.getElementById('totalRayon').textContent  = [...new Set(siswaData.map(s=>s.rayon).filter(Boolean))].length;
}

function showMsg(txt, type='success'){
  const m = document.getElementById('msg');
  m.className = 'alert alert-'+type;
  m.textContent = txt;
  m.style.display = 'block';
  setTimeout(()=>m.style.display='none', 3000);
}

async function saveSiswa(){
  const id = document.getElementById('editId').value;
  const fd = new FormData();
  fd.append('nis',   document.getElementById('nis').value.trim());
  fd.append('nama',  document.getElementById('nama').value.trim());
  fd.append('rombel',document.getElementById('rombel').value);
  fd.append('rayon', document.getElementById('rayon').value);
  if(!fd.get('nis')||!fd.get('nama')){showMsg('NIS dan Nama wajib diisi','error');return;}
  const url = id ? API+'update' : API+'add';
  if(id) fd.append('id',id);
  const r = await fetch(url,{method:'POST',body:fd});
  const j = await r.json();
  if(j.ok||j.id){ showMsg(id?'Data berhasil diupdate!':'Siswa berhasil ditambahkan! 🎉'); resetForm(); loadSiswa(); }
  else showMsg(j.error||'Terjadi kesalahan','error');
}

function editSiswa(id){
  const s = siswaData.find(x=>x.id==id);
  if(!s) return;
  document.getElementById('editId').value  = s.id;
  document.getElementById('nis').value     = s.nis;
  document.getElementById('nama').value    = s.nama;
  document.getElementById('rombel').value  = s.rombel;
  document.getElementById('rayon').value   = s.rayon;
  document.getElementById('formTitle').textContent = 'Edit Siswa';
  document.getElementById('cancelBtn').style.display = 'block';
  window.scrollTo({top:0,behavior:'smooth'});
}

async function delSiswa(id){
  const s = siswaData.find(x=>x.id==id);
  if(!confirm(`Hapus siswa "${s?.nama}"?`)) return;
  const r = await fetch(API+'delete&id='+id);
  const j = await r.json();
  if(j.ok){ showMsg('Data berhasil dihapus'); loadSiswa(); }
}

function resetForm(){
  ['editId','nis','nama'].forEach(id=>document.getElementById(id).value='');
  ['rombel','rayon'].forEach(id=>document.getElementById(id).value='');
  document.getElementById('formTitle').textContent = 'Tambah Siswa';
  document.getElementById('cancelBtn').style.display = 'none';
}

loadSiswa();
</script>
</body>
</html>
PHPEOF

  # ── Konfigurasi Virtual Hosts ───────────────────────────
  # Default / www
  cat > /etc/apache2/sites-available/www.${DOMAIN}.conf <<EOF
<VirtualHost *:80>
    ServerName www.${DOMAIN}
    ServerAlias ${DOMAIN}
    DocumentRoot /var/www/main
    DirectoryIndex index.php index.html

    SetEnv SERVER_DOMAIN "${DOMAIN}"
    SetEnv DNS_IP "${DNS_IP}"

    <Directory /var/www/main>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/www.${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/www.${DOMAIN}-access.log combined
</VirtualHost>
EOF

  # Mail vhost
  cat > /etc/apache2/sites-available/mail.${DOMAIN}.conf <<EOF
<VirtualHost *:80>
    ServerName mail.${DOMAIN}
    DocumentRoot /var/www/mail
    DirectoryIndex index.php index.html

    <Directory /var/www/mail>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/mail.${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/mail.${DOMAIN}-access.log combined
</VirtualHost>
EOF

  # CRUD vhost
  cat > /etc/apache2/sites-available/crud.${DOMAIN}.conf <<EOF
<VirtualHost *:80>
    ServerName crud.${DOMAIN}
    DocumentRoot /var/www/crud
    DirectoryIndex index.php index.html

    <Directory /var/www/crud>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/crud.${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/crud.${DOMAIN}-access.log combined
</VirtualHost>
EOF

  # Enable sites
  a2dissite 000-default.conf 2>/dev/null || true
  a2ensite www.${DOMAIN}.conf mail.${DOMAIN}.conf crud.${DOMAIN}.conf

  run_cmd "Restart Apache2" systemctl restart apache2
  run_cmd "Enable Apache2"  systemctl enable apache2
  log_ok "Apache2 OK — 3 virtual host aktif"
}

# ══════════════════════════════════════════════════════════
#  FASE 8 : DATABASE + CRUD SETUP
# ══════════════════════════════════════════════════════════
configure_database() {
  log_section "MARIADB — Database CRUD Siswa"

  run_cmd "Start MariaDB" systemctl start mariadb && systemctl enable mariadb

  mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS siswa_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'cruduser'@'localhost' IDENTIFIED BY 'CrudPass@2024';
GRANT ALL PRIVILEGES ON siswa_db.* TO 'cruduser'@'localhost';
FLUSH PRIVILEGES;

USE siswa_db;
CREATE TABLE IF NOT EXISTS siswa (
    id     INT AUTO_INCREMENT PRIMARY KEY,
    nis    VARCHAR(20) NOT NULL UNIQUE,
    nama   VARCHAR(100) NOT NULL,
    rombel VARCHAR(50),
    rayon  VARCHAR(30),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

INSERT IGNORE INTO siswa (nis, nama, rombel, rayon) VALUES
('2024001', 'Ahmad Fauzi Ramadan',    'XII TJKT 1', 'Rayon A'),
('2024002', 'Siti Nurhaliza',         'XII TJKT 1', 'Rayon B'),
('2024003', 'Budi Santoso Pratama',   'XI TJKT 2',  'Rayon A'),
('2024004', 'Dewi Anggraini',         'XI TJKT 2',  'Rayon C'),
('2024005', 'Rizki Maulana Yusuf',    'X TJKT 3',   'Rayon D');
SQL

  log_ok "Database siswa_db siap — 5 data sample ditambahkan"
}

# ══════════════════════════════════════════════════════════
#  FASE 9 : FTP SERVER
# ══════════════════════════════════════════════════════════
configure_ftp() {
  log_section "FTP SERVER — vsftpd"

  # Buat user FTP
  useradd -m -s /bin/bash ftpuser 2>/dev/null || true
  echo "ftpuser:FtpPass@2024" | chpasswd

  mkdir -p /home/ftpuser/public
  chown -R ftpuser:ftpuser /home/ftpuser
  chmod 750 /home/ftpuser

  # Tambah file sample
  cat > /home/ftpuser/public/README.txt <<EOF
===========================
FTP Server - TJKT Wikrama
===========================
User   : ftpuser
Akses  : ftp://${DNS_IP}
Server : vsftpd

Selamat datang di FTP Server TJKT SMK Wikrama Bogor!
Direktori ini digunakan untuk berbagi file antar siswa dan guru.
EOF

  cat > /etc/vsftpd.conf <<EOF
# vsftpd - FTP Server TJKT Wikrama
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
xferlog_file=/var/log/vsftpd.log
xferlog_std_format=YES
idle_session_timeout=600
data_connection_timeout=300
ascii_upload_enable=YES
ascii_download_enable=YES
ftpd_banner=Selamat Datang di FTP Server TJKT SMK Wikrama Bogor
chroot_local_user=NO
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
local_root=/home/ftpuser
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
EOF

  run_cmd "Enable & start vsftpd" systemctl enable vsftpd && systemctl restart vsftpd
  log_ok "FTP aktif — user: ftpuser | pass: FtpPass@2024"
}

# ══════════════════════════════════════════════════════════
#  FASE 10 : SAMBA
# ══════════════════════════════════════════════════════════
configure_samba() {
  log_section "SAMBA — Share tjkt-wikrama"

  mkdir -p /srv/samba/tjkt-wikrama
  chmod 0777 /srv/samba/tjkt-wikrama

  # Tambah file contoh
  cat > /srv/samba/tjkt-wikrama/README.txt <<EOF
===========================
Samba Share - TJKT Wikrama
===========================
Nama Share : tjkt-wikrama
Path       : \\\\${DNS_IP}\\tjkt-wikrama
Akses      : Guest (tanpa password)

Gunakan folder ini untuk berbagi file di jaringan lokal.
EOF

  cat > /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   server string = TJKT SMK Wikrama Bogor
   netbios name = TJKT-SERVER
   security = user
   map to guest = bad user
   dns proxy = no
   log level = 1
   max log size = 50

[tjkt-wikrama]
   path = /srv/samba/tjkt-wikrama
   comment = Share TJKT SMK Wikrama Bogor
   browsable = yes
   writable = yes
   guest ok = yes
   guest only = yes
   create mask = 0666
   directory mask = 0777
   force user = nobody
EOF

  run_cmd "Test konfigurasi Samba"  testparm -s
  run_cmd "Enable & start Samba"    systemctl enable smbd nmbd && systemctl restart smbd nmbd
  log_ok "Samba aktif — \\\\${DNS_IP}\\tjkt-wikrama"
}

# ══════════════════════════════════════════════════════════
#  FASE 11 : MAIL SERVER
# ══════════════════════════════════════════════════════════
configure_mail() {
  log_section "MAIL SERVER — Postfix + Dovecot"

  local MYHOSTNAME="mail.${DOMAIN}"

  # ── Postfix ────────────────────────────────────────────
  debconf-set-selections <<< "postfix postfix/mailname string ${DOMAIN}"
  debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
  dpkg-reconfigure -f noninteractive postfix 2>/dev/null || true

  cat > /etc/postfix/main.cf <<EOF
# Postfix - TJKT Wikrama
smtpd_banner = \$myhostname ESMTP TJKT SMK Wikrama Bogor
biff = no
append_dot_mydomain = no
readme_directory = no

# TLS
smtpd_tls_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
smtpd_tls_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
smtpd_use_tls=yes
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache

# Network
myhostname = ${MYHOSTNAME}
myorigin = \$mydomain
mydomain = ${DOMAIN}
mydestination = \$myhostname, ${DOMAIN}, localhost.\$mydomain, localhost
relayhost =
mynetworks = 127.0.0.0/8 ${NETWORK}/${STATIC_PREFIX} [::ffff:127.0.0.0]/104 [::1]/128
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = all

home_mailbox = Maildir/
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous
broken_sasl_auth_clients = yes
smtpd_recipient_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination
EOF

  # ── Dovecot ────────────────────────────────────────────
  cat > /etc/dovecot/dovecot.conf <<EOF
protocols = imap pop3
listen = *

mail_location = maildir:~/Maildir
mail_privileged_group = mail

passdb {
  driver = pam
}

userdb {
  driver = passwd
}

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}

protocol imap {
  mail_max_userip_connections = 10
}
EOF

  run_cmd "Enable & start Postfix"  systemctl enable postfix  && systemctl restart postfix
  run_cmd "Enable & start Dovecot"  systemctl enable dovecot  && systemctl restart dovecot
  log_ok "Mail server aktif — SMTP:25/587, IMAP:143, POP3:110"
}

# ══════════════════════════════════════════════════════════
#  FASE 12 : WORDPRESS
# ══════════════════════════════════════════════════════════
configure_wordpress() {
  log_section "WORDPRESS — Instalasi"

  local WP_DIR="/var/www/html/wordpress"
  local WP_DB="wordpress"
  local WP_USER="wpuser"
  local WP_PASS="WpPass@2024"

  # Database WordPress
  mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS ${WP_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${WP_USER}'@'localhost' IDENTIFIED BY '${WP_PASS}';
GRANT ALL PRIVILEGES ON ${WP_DB}.* TO '${WP_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

  # Download WordPress
  if [[ ! -f /tmp/wordpress.tar.gz ]]; then
    run_cmd "Download WordPress" wget -q -O /tmp/wordpress.tar.gz "https://wordpress.org/latest.tar.gz"
  fi

  mkdir -p "$WP_DIR"
  run_cmd "Ekstrak WordPress" tar -xzf /tmp/wordpress.tar.gz -C /var/www/html/

  cp "${WP_DIR}/wp-config-sample.php" "${WP_DIR}/wp-config.php"
  sed -i "s/database_name_here/${WP_DB}/"    "${WP_DIR}/wp-config.php"
  sed -i "s/username_here/${WP_USER}/"        "${WP_DIR}/wp-config.php"
  sed -i "s/password_here/${WP_PASS}/"        "${WP_DIR}/wp-config.php"
  sed -i "s/localhost/localhost/"              "${WP_DIR}/wp-config.php"

  # Tambahkan secret keys
  local SALT
  SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/ 2>/dev/null || \
    echo "define('AUTH_KEY','$(openssl rand -base64 48)');")
  # Simple salt replacement fallback
  sed -i "/define( 'AUTH_KEY'/,/define( 'NONCE_SALT'/d" "${WP_DIR}/wp-config.php" 2>/dev/null || true

  chown -R www-data:www-data "$WP_DIR"
  chmod -R 755 "$WP_DIR"

  # VHost WordPress
  cat > /etc/apache2/sites-available/wordpress.conf <<EOF
<VirtualHost *:80>
    ServerName ${DNS_IP}
    DocumentRoot ${WP_DIR}
    DirectoryIndex index.php

    <Directory ${WP_DIR}>
        AllowOverride All
        Require all granted
        Options -Indexes
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/wordpress-error.log
    CustomLog \${APACHE_LOG_DIR}/wordpress-access.log combined
</VirtualHost>
EOF

  a2ensite wordpress.conf
  a2enmod rewrite
  run_cmd "Restart Apache2 untuk WordPress" systemctl restart apache2
  log_ok "WordPress siap di http://${DNS_IP}/wordpress/"
}

# ══════════════════════════════════════════════════════════
#  FASE 13 : FIREWALL & DNS RESOLVER
# ══════════════════════════════════════════════════════════
configure_firewall_and_resolver() {
  log_section "FIREWALL & DNS RESOLVER"

  # Arahkan resolv.conf ke server DNS sendiri
  cat > /etc/resolv.conf <<EOF
nameserver ${DNS_IP}
nameserver 8.8.8.8
search ${DOMAIN}
EOF
  chattr +i /etc/resolv.conf 2>/dev/null || true   # Proteksi dari overwrite

  # UFW jika tersedia
  if command -v ufw &>/dev/null; then
    ufw --force disable 2>/dev/null || true   # Disable dulu agar semua boleh lewat di lab
  fi

  # iptables rules dasar
  iptables -I INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p tcp --dport 25 -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p tcp --dport 110 -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p tcp --dport 143 -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p tcp --dport 21 -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p tcp --dport 445 -j ACCEPT 2>/dev/null || true
  iptables -I INPUT -p udp --dport 67 -j ACCEPT 2>/dev/null || true

  log_ok "Firewall dikonfigurasi — semua port layanan dibuka"
}

# ══════════════════════════════════════════════════════════
#  PANDUAN AKHIR
# ══════════════════════════════════════════════════════════
print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ✅  INSTALASI BERHASIL! SEMUA LAYANAN AKTIF               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
  echo -e "${RESET}"

  echo -e "${WHITE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${WHITE}${BOLD}  📋 PANDUAN OPERASIONAL SERVER${RESET}"
  echo -e "${WHITE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  echo ""
  echo -e "${CYAN}${BOLD}🌐 WEB SERVER (Apache2)${RESET}"
  echo -e "  Halaman Utama  : ${YELLOW}http://${DNS_IP}/${RESET}"
  echo -e "  www Virtual    : ${YELLOW}http://www.${DOMAIN}/${RESET}"
  echo -e "  CRUD Siswa     : ${YELLOW}http://crud.${DOMAIN}/${RESET}"
  echo -e "  Mail Info      : ${YELLOW}http://mail.${DOMAIN}/${RESET}"
  echo -e "  WordPress      : ${YELLOW}http://${DNS_IP}/wordpress/${RESET}"

  echo ""
  echo -e "${CYAN}${BOLD}🔍 DNS SERVER (BIND9)${RESET}"
  echo -e "  Nameserver 1   : ${YELLOW}ns1.${DOMAIN} → ${DNS_IP}${RESET}"
  echo -e "  Nameserver 2   : ${YELLOW}ns2.${DOMAIN} → ${DNS_IP}${RESET}"
  echo -e "  Nameserver 3   : ${YELLOW}ns3.${DOMAIN} → ${DNS_IP}${RESET}"
  echo -e "  Test DNS       : ${YELLOW}nslookup ${DOMAIN} ${DNS_IP}${RESET}"
  echo -e "  Test NS        : ${YELLOW}dig @${DNS_IP} ${DOMAIN} NS${RESET}"
  echo -e "  Test A record  : ${YELLOW}dig @${DNS_IP} www.${DOMAIN}${RESET}"

  echo ""
  echo -e "${CYAN}${BOLD}📡 DHCP SERVER${RESET}"
  echo -e "  Interface      : ${YELLOW}${DHCP_IFACE}${RESET}"
  echo -e "  IP Server      : ${YELLOW}${STATIC_IP}${RESET}"
  echo -e "  Range Client   : ${YELLOW}${DHCP_RANGE_START} — ${DHCP_RANGE_END}${RESET}"
  echo -e "  Cek lease      : ${YELLOW}cat /var/lib/dhcp/dhcpd.leases${RESET}"

  echo ""
  echo -e "${CYAN}${BOLD}📁 FTP SERVER (vsftpd)${RESET}"
  echo -e "  Alamat         : ${YELLOW}ftp://${DNS_IP}${RESET}"
  echo -e "  Username       : ${YELLOW}ftpuser${RESET}"
  echo -e "  Password       : ${YELLOW}FtpPass@2024${RESET}"
  echo -e "  Direktori      : ${YELLOW}/home/ftpuser/public/${RESET}"

  echo ""
  echo -e "${CYAN}${BOLD}📂 SAMBA SHARE${RESET}"
  echo -e "  Windows path   : ${YELLOW}\\\\${DNS_IP}\\tjkt-wikrama${RESET}"
  echo -e "  Linux mount    : ${YELLOW}smb://${DNS_IP}/tjkt-wikrama${RESET}"
  echo -e "  Akses          : ${YELLOW}Guest (tanpa password)${RESET}"
  echo -e "  Test          : ${YELLOW}smbclient //127.0.0.1/tjkt-wikrama -N${RESET}"

  echo ""
  echo -e "${CYAN}${BOLD}📧 MAIL SERVER (Postfix + Dovecot)${RESET}"
  echo -e "  SMTP           : ${YELLOW}${DNS_IP}:25 / 587${RESET}"
  echo -e "  IMAP           : ${YELLOW}${DNS_IP}:143${RESET}"
  echo -e "  POP3           : ${YELLOW}${DNS_IP}:110${RESET}"
  echo -e "  Test SMTP      : ${YELLOW}telnet ${DNS_IP} 25${RESET}"

  echo ""
  echo -e "${CYAN}${BOLD}🗄️  DATABASE (MariaDB)${RESET}"
  echo -e "  CRUD DB User   : ${YELLOW}cruduser / CrudPass@2024${RESET}"
  echo -e "  Database       : ${YELLOW}siswa_db${RESET}"
  echo -e "  WP DB User     : ${YELLOW}wpuser / WpPass@2024${RESET}"
  echo -e "  WP Database    : ${YELLOW}wordpress${RESET}"
  echo -e "  Akses MySQL    : ${YELLOW}mysql -u root${RESET}"

  echo ""
  echo -e "${CYAN}${BOLD}🔧 PERINTAH MANAJEMEN SERVICE${RESET}"
  echo -e "  ${YELLOW}systemctl status isc-dhcp-server${RESET}  — Cek DHCP"
  echo -e "  ${YELLOW}systemctl status named${RESET}            — Cek DNS"
  echo -e "  ${YELLOW}systemctl status apache2${RESET}          — Cek Web"
  echo -e "  ${YELLOW}systemctl status vsftpd${RESET}           — Cek FTP"
  echo -e "  ${YELLOW}systemctl status smbd${RESET}             — Cek Samba"
  echo -e "  ${YELLOW}systemctl status postfix${RESET}          — Cek Mail"
  echo -e "  ${YELLOW}journalctl -xe${RESET}                    — Lihat log error"

  echo ""
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${GREEN}${BOLD}  ${STAR} Setup selesai! TJKT SMK Wikrama Bogor ${STAR}${RESET}"
  echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""

  # Simpan ringkasan ke file
  local SUMMARY_FILE="/root/server-setup-summary.txt"
  {
    echo "=============================="
    echo " SERVER SETUP SUMMARY"
    echo " Tanggal: $(date)"
    echo "=============================="
    echo "IP Static    : ${STATIC_IP}"
    echo "DHCP Iface   : ${DHCP_IFACE}"
    echo "DHCP Range   : ${DHCP_RANGE_START} - ${DHCP_RANGE_END}"
    echo "Domain       : ${DOMAIN}"
    echo "DNS IP       : ${DNS_IP}"
    echo ""
    echo "URL Layanan:"
    echo "  Web    : http://${DNS_IP}/"
    echo "  CRUD   : http://crud.${DOMAIN}/"
    echo "  Mail   : http://mail.${DOMAIN}/"
    echo "  WP     : http://${DNS_IP}/wordpress/"
    echo ""
    echo "Credentials:"
    echo "  FTP    : ftpuser / FtpPass@2024"
    echo "  DB CRUD: cruduser / CrudPass@2024"
    echo "  DB WP  : wpuser / WpPass@2024"
    echo "=============================="
  } > "$SUMMARY_FILE"

  echo -e "  ${GREEN}${CHECK}${RESET} Ringkasan disimpan di: ${YELLOW}${SUMMARY_FILE}${RESET}"
  echo ""
}

# ══════════════════════════════════════════════════════════
#  MAIN — URUTAN EKSEKUSI
# ══════════════════════════════════════════════════════════
main() {
  clear
  banner
  check_root
  detect_os
  detect_interfaces
  detect_existing_ips

  interactive_input

  echo ""
  log_info "Memulai instalasi... ini mungkin memakan waktu 5-15 menit."
  echo ""

  cleanup_old_services
  install_packages
  configure_static_ip
  configure_dhcp
  configure_dns
  configure_database
  configure_apache
  configure_ftp
  configure_samba
  configure_mail
  configure_wordpress
  configure_firewall_and_resolver

  print_summary
}

main "$@"
