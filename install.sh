#!/usr/bin/env bash

# ============================================================
# Blueprint Framework - Universal Installer
# Supports: Ubuntu, Debian, RHEL, CentOS, AlmaLinux, Rocky,
#           Fedora, Arch Linux
# ============================================================

set -Eeuo pipefail

# ---------------- COLORS ----------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# ---------------- FUNCTIONS ----------------

log() {
    echo -e "${CYAN}[BLUEPRINT]${RESET} $1"
}

success() {
    echo -e "${GREEN}[✓]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[!]${RESET} $1"
}

error() {
    echo -e "${RED}[✗]${RESET} $1"
}

die() {
    error "$1"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ---------------- BANNER ----------------

clear

echo -e "${CYAN}"
cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║             BLUEPRINT FRAMEWORK INSTALLER                ║
║                                                          ║
║             Universal Pterodactyl Installer              ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

# ---------------- ROOT CHECK ----------------

if [[ "${EUID}" -ne 0 ]]; then
    die "Please run this installer as root."
fi

success "Running as root."

# ---------------- OS DETECTION ----------------

OS=""
OS_ID=""
OS_VERSION=""

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"
fi

echo
echo -e "${WHITE}Select your operating system:${RESET}"
echo
echo "  [1] Ubuntu"
echo "  [2] Debian"
echo "  [3] AlmaLinux"
echo "  [4] Rocky Linux"
echo "  [5] CentOS"
echo "  [6] Fedora"
echo "  [7] RHEL"
echo "  [8] Arch Linux"
echo "  [9] Auto Detect"
echo

read -rp "Enter choice [1-9]: " OS_CHOICE

case "$OS_CHOICE" in
    1)
        OS="ubuntu"
        ;;
    2)
        OS="debian"
        ;;
    3)
        OS="almalinux"
        ;;
    4)
        OS="rocky"
        ;;
    5)
        OS="centos"
        ;;
    6)
        OS="fedora"
        ;;
    7)
        OS="rhel"
        ;;
    8)
        OS="arch"
        ;;
    9)
        case "$OS_ID" in
            ubuntu)
                OS="ubuntu"
                ;;
            debian)
                OS="debian"
                ;;
            almalinux)
                OS="almalinux"
                ;;
            rocky)
                OS="rocky"
                ;;
            centos)
                OS="centos"
                ;;
            fedora)
                OS="fedora"
                ;;
            rhel)
                OS="rhel"
                ;;
            arch|manjaro)
                OS="arch"
                ;;
            *)
                die "Unsupported operating system: $OS_ID"
                ;;
        esac
        ;;
    *)
        die "Invalid selection."
        ;;
esac

success "Selected OS: $OS"
log "Detected system: ${OS_ID} ${OS_VERSION}"

# ---------------- ARCHITECTURE ----------------

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64)
        BLUEPRINT_ARCH="amd64"
        ;;
    aarch64|arm64)
        BLUEPRINT_ARCH="arm64"
        ;;
    *)
        warn "Architecture $ARCH may not be supported."
        BLUEPRINT_ARCH="$ARCH"
        ;;
esac

log "Architecture: $ARCH"

# ---------------- PTERODACTYL CHECK ----------------

echo
log "Checking Pterodactyl installation..."

PTERODACTYL_DIR=""

POSSIBLE_PATHS=(
    "/var/www/pterodactyl"
    "/var/www/panel"
    "/var/www/html"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [[ -f "$path/artisan" ]]; then
        PTERODACTYL_DIR="$path"
        break
    fi
done

if [[ -z "$PTERODACTYL_DIR" ]]; then
    echo
    warn "Pterodactyl installation was not automatically detected."
    echo

    read -rp "Enter your Pterodactyl directory [/var/www/pterodactyl]: " CUSTOM_DIR

    PTERODACTYL_DIR="${CUSTOM_DIR:-/var/www/pterodactyl}"
fi

if [[ ! -f "$PTERODACTYL_DIR/artisan" ]]; then
    die "Pterodactyl was not found at: $PTERODACTYL_DIR"
fi

success "Pterodactyl found: $PTERODACTYL_DIR"

cd "$PTERODACTYL_DIR"

# ---------------- PACKAGE INSTALLATION ----------------

echo
log "Installing required packages..."

case "$OS" in

    ubuntu|debian)

        export DEBIAN_FRONTEND=noninteractive

        apt-get update -y

        apt-get install -y \
            curl \
            wget \
            unzip \
            tar \
            git \
            ca-certificates \
            sudo \
            jq \
            openssl \
            rsync

        ;;

    almalinux|rocky|centos|rhel)

        if command_exists dnf; then
            dnf install -y \
                curl \
                wget \
                unzip \
                tar \
                git \
                ca-certificates \
                sudo \
                jq \
                openssl \
                rsync
        else
            yum install -y \
                curl \
                wget \
                unzip \
                tar \
                git \
                ca-certificates \
                sudo \
                jq \
                openssl \
                rsync
        fi

        ;;

    fedora)

        dnf install -y \
            curl \
            wget \
            unzip \
            tar \
            git \
            ca-certificates \
            sudo \
            jq \
            openssl \
            rsync

        ;;

    arch)

        pacman -Sy --noconfirm \
            curl \
            wget \
            unzip \
            tar \
            git \
            ca-certificates \
            sudo \
            jq \
            openssl \
            rsync

        ;;

    *)
        die "Unsupported OS package manager."
        ;;
esac

success "Required packages installed."

# ---------------- VERIFY TOOLS ----------------

for tool in curl wget unzip tar git jq; do
    if ! command_exists "$tool"; then
        die "Required command '$tool' is missing."
    fi
done

success "Required tools verified."

# ---------------- BACKUP ----------------

BACKUP_DIR="/root/blueprint-backup-$(date +%Y%m%d-%H%M%S)"

echo
log "Creating Pterodactyl backup..."

mkdir -p "$BACKUP_DIR"

if [[ -d "$PTERODACTYL_DIR/resources" ]]; then
    cp -a "$PTERODACTYL_DIR/resources" "$BACKUP_DIR/" || true
fi

if [[ -d "$PTERODACTYL_DIR/app" ]]; then
    cp -a "$PTERODACTYL_DIR/app" "$BACKUP_DIR/" || true
fi

success "Backup created: $BACKUP_DIR"

# ---------------- BLUEPRINT DOWNLOAD ----------------

echo
log "Downloading latest Blueprint Framework..."

TMP_DIR="/tmp/blueprint-install"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

cd "$TMP_DIR"

BLUEPRINT_URL="https://github.com/BlueprintFramework/framework/releases/latest/download/release.zip"

if ! wget -O release.zip "$BLUEPRINT_URL"; then
    die "Failed to download Blueprint Framework."
fi

if [[ ! -s release.zip ]]; then
    die "Downloaded Blueprint archive is empty."
fi

success "Blueprint archive downloaded."

# ---------------- EXTRACT ----------------

log "Extracting Blueprint Framework..."

mkdir -p extract

unzip -q -o release.zip -d extract

success "Blueprint archive extracted."

# ---------------- FIND BLUEPRINT INSTALLER ----------------

BLUEPRINT_INSTALLER=""

if [[ -f "$TMP_DIR/extract/blueprint.sh" ]]; then
    BLUEPRINT_INSTALLER="$TMP_DIR/extract/blueprint.sh"
else
    BLUEPRINT_INSTALLER="$(find "$TMP_DIR/extract" -type f -name "blueprint.sh" -print -quit || true)"
fi

if [[ -z "$BLUEPRINT_INSTALLER" ]]; then
    echo
    warn "Blueprint installer script was not found automatically."

    find "$TMP_DIR/extract" -maxdepth 3 -type f | sort

    die "Cannot find blueprint.sh."
fi

success "Blueprint installer found:"
echo "       $BLUEPRINT_INSTALLER"

chmod +x "$BLUEPRINT_INSTALLER"

# ---------------- RUN BLUEPRINT INSTALLER ----------------

echo
echo -e "${WHITE}============================================================${RESET}"
echo -e "${WHITE}Starting Blueprint Framework installation${RESET}"
echo -e "${WHITE}============================================================${RESET}"
echo

cd "$PTERODACTYL_DIR"

# Pass the Pterodactyl directory to the installer when supported.
# Blueprint's own installer will handle its framework-specific setup.

if "$BLUEPRINT_INSTALLER" --help >/dev/null 2>&1; then
    "$BLUEPRINT_INSTALLER"
else
    bash "$BLUEPRINT_INSTALLER"
fi

# ---------------- PERMISSIONS ----------------

echo
log "Fixing Pterodactyl permissions..."

if id "www-data" >/dev/null 2>&1; then

    chown -R www-data:www-data "$PTERODACTYL_DIR/storage" 2>/dev/null || true
    chown -R www-data:www-data "$PTERODACTYL_DIR/bootstrap/cache" 2>/dev/null || true

    find "$PTERODACTYL_DIR/storage" \
        -type d \
        -exec chmod 775 {} \; 2>/dev/null || true

    find "$PTERODACTYL_DIR/bootstrap/cache" \
        -type d \
        -exec chmod 775 {} \; 2>/dev/null || true

elif id "nginx" >/dev/null 2>&1; then

    chown -R nginx:nginx "$PTERODACTYL_DIR/storage" 2>/dev/null || true
    chown -R nginx:nginx "$PTERODACTYL_DIR/bootstrap/cache" 2>/dev/null || true

fi

success "Permissions updated."

# ---------------- CLEAR CACHE ----------------

echo
log "Clearing Laravel cache..."

if [[ -f artisan ]]; then

    php artisan optimize:clear 2>/dev/null || true

fi

success "Cache cleared."

# ---------------- FINAL CHECK ----------------

echo
log "Running final checks..."

if [[ -f "$PTERODACTYL_DIR/artisan" ]]; then
    success "Pterodactyl files are present."
else
    warn "Pterodactyl artisan file could not be verified."
fi

# ---------------- CLEANUP ----------------

rm -rf "$TMP_DIR"

# ---------------- COMPLETE ----------------

echo
echo -e "${GREEN}"
cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       BLUEPRINT INSTALLATION COMPLETED                   ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

echo
echo -e "${WHITE}Installation Information${RESET}"
echo "────────────────────────────────────────"
echo "OS              : $OS"
echo "Architecture    : $ARCH"
echo "Pterodactyl     : $PTERODACTYL_DIR"
echo "Backup          : $BACKUP_DIR"
echo

success "Blueprint installation process finished."

echo
warn "If the panel does not load, restart your web server/PHP-FPM."
echo

# Try common PHP-FPM services
for service in \
    php8.4-fpm \
    php8.3-fpm \
    php8.2-fpm \
    php8.1-fpm \
    php-fpm
do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${service}.service"; then
        systemctl restart "$service" 2>/dev/null || true
    fi
done

systemctl reload nginx 2>/dev/null || true

success "Service reload completed."
echo
echo -e "${CYAN}Thank you for using Blueprint Universal Installer.${RESET}"
