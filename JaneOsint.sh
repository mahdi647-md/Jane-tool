#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
# JANE OSINT
# Public-information reconnaissance toolkit for Termux
# ==========================================================

clear

# ---------- Colors ----------
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
RESET='\033[0m'

banner() {
    clear
    echo -e "${RED}"
    echo "     ██╗ █████╗ ███╗   ██╗███████╗"
    echo "     ██║██╔══██╗████╗  ██║██╔════╝"
    echo "     ██║███████║██╔██╗ ██║█████╗  "
    echo "██   ██║██╔══██║██║╚██╗██║██╔══╝  "
    echo "╚█████╔╝██║  ██║██║ ╚████║███████╗"
    echo " ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝"
    echo -e "${RESET}"
    echo -e "${CYAN}              J A N E  O S I N T${RESET}"
    echo -e "${WHITE}          Termux Intelligence Toolkit${RESET}"
    echo
    echo -e "${RED}================================================${RESET}"
}

pause() {
    echo
    read -rp "Press ENTER to continue..."
}

check_tools() {
    local missing=()

    for tool in curl dig whois openssl; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo -e "${YELLOW}[!] Missing tools: ${missing[*]}${RESET}"
        echo
        echo "Install with:"
        echo "pkg install curl dnsutils whois openssl"
        return 1
    fi

    return 0
}

target_menu() {
    echo -e "${CYAN}Target: ${WHITE}${TARGET}${RESET}"
    echo
    echo -e "${GREEN}[1]${RESET} DNS Recon"
    echo -e "${GREEN}[2]${RESET} WHOIS"
    echo -e "${GREEN}[3]${RESET} HTTP Headers"
    echo -e "${GREEN}[4]${RESET} TLS Certificate"
    echo -e "${GREEN}[5]${RESET} Certificate Transparency"
    echo -e "${GREEN}[6]${RESET} Run Full Scan"
    echo -e "${GREEN}[0]${RESET} Exit"
    echo
}

dns_recon() {
    echo -e "${BLUE}[*] DNS reconnaissance...${RESET}"

    {
        echo "===== A ====="
        dig +short A "$TARGET"

        echo
        echo "===== AAAA ====="
        dig +short AAAA "$TARGET"

        echo
        echo "===== MX ====="
        dig +short MX "$TARGET"

        echo
        echo "===== NS ====="
        dig +short NS "$TARGET"

        echo
        echo "===== TXT ====="
        dig +short TXT "$TARGET"
    } | tee "$OUT/dns.txt"

    echo -e "${GREEN}[+] Saved: $OUT/dns.txt${RESET}"
}

whois_lookup() {
    echo -e "${BLUE}[*] WHOIS lookup...${RESET}"

    whois "$TARGET" 2>/dev/null | tee "$OUT/whois.txt"

    echo -e "${GREEN}[+] Saved: $OUT/whois.txt${RESET}"
}

http_recon() {
    echo -e "${BLUE}[*] HTTP header reconnaissance...${RESET}"

    curl -sSIL --max-time 15 \
        "https://$TARGET" \
        | tee "$OUT/http_headers.txt"

    echo -e "${GREEN}[+] Saved: $OUT/http_headers.txt${RESET}"
}

tls_recon() {
    echo -e "${BLUE}[*] Reading TLS certificate...${RESET}"

    timeout 15 openssl s_client \
        -connect "$TARGET:443" \
        -servername "$TARGET" \
        </dev/null 2>/dev/null |
        openssl x509 -noout \
        -subject \
        -issuer \
        -dates \
        -serial \
        -ext subjectAltName |
        tee "$OUT/tls.txt"

    echo -e "${GREEN}[+] Saved: $OUT/tls.txt${RESET}"
}

crt_recon() {
    echo -e "${BLUE}[*] Certificate Transparency search...${RESET}"

    curl -sS --max-time 20 \
        "https://crt.sh/?q=%25.$TARGET&output=json" \
        > "$OUT/crt.json"

    if command -v python >/dev/null 2>&1; then
        python - "$OUT/crt.json" <<'PY' |
import json
import sys

try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))

    names = set()

    for entry in data:
        for name in entry.get("name_value", "").splitlines():
            name = name.strip().lower()

            if name.startswith("*."):
                name = name[2:]

            if name:
                names.add(name)

    for name in sorted(names):
        print(name)

except Exception as e:
    print("Unable to parse certificate data.")
PY
        tee "$OUT/subdomains.txt"
    fi

    echo -e "${GREEN}[+] Saved: $OUT/subdomains.txt${RESET}"
}

full_scan() {
    echo -e "${RED}[!] Starting JaneOsint full scan${RESET}"
    echo

    dns_recon
    echo
    whois_lookup
    echo
    http_recon
    echo
    tls_recon
    echo
    crt_recon

    echo
    echo -e "${GREEN}========================================${RESET}"
    echo -e "${GREEN}[+] FULL SCAN COMPLETE${RESET}"
    echo -e "${GREEN}[+] Results: $OUT/${RESET}"
    echo -e "${GREEN}========================================${RESET}"
}

# ---------- Startup ----------

banner

if ! check_tools; then
    pause
    exit 1
fi

echo -e "${WHITE}Enter a domain or IP address.${RESET}"
echo -e "${YELLOW}Example: example.com${RESET}"
echo

read -rp "JANE > " TARGET

if [ -z "$TARGET" ]; then
    echo -e "${RED}[!] No target supplied.${RESET}"
    exit 1
fi

OUT="JaneOsint_${TARGET//[^a-zA-Z0-9._-]/_}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

while true; do
    banner
    target_menu

    read -rp "JANE > " choice
    echo

    case "$choice" in
        1)
            dns_recon
            pause
            ;;
        2)
            whois_lookup
            pause
            ;;
        3)
            http_recon
            pause
            ;;
        4)
            tls_recon
            pause
            ;;
        5)
            crt_recon
            pause
            ;;
        6)
            full_scan
            pause
            ;;
        0)
            echo -e "${RED}[*] JaneOsint shutting down...${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Invalid option.${RESET}"
            sleep 1
            ;;
    esac
done

Termux setup

pkg update
pkg install bash curl dnsutils whois openssl python
nano JaneOsint.sh
chmod +x JaneOsint.sh
./JaneOsint.sh

This gives you the "JaneOsint.sh" name and a menu-driven interface while keeping the functionality centered on public reconnaissance rather than compromising devices or accounts.
