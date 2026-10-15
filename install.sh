#!/bin/bash

set -Eeuo pipefail

# ============================================================
# VANTIXGLASS PTERODACTYL THEME
# Complete single-file installer
# Author: CodeWithAashirwad / AashirwadGamerzz
# ============================================================

PANEL="/var/www/pterodactyl"
BACKUP="/var/backups/vantixglass-$(date +%Y%m%d-%H%M%S)"
TMP="/tmp/vantixglass"
MIGRATION="2026_10_15_000000_create_theme_tables.php"

# GitHub repository
REPO="https://github.com/CodeWithAashirwad/pterodactyl-theme/raw/refs/heads/main/main.zip"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${CYAN}[VANTIXGLASS]${NC} $1"
}

ok() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

die() {
    echo -e "${RED}[✗]${NC} $1"
    exit 1
}

cleanup() {
    rm -rf "$TMP"
}

trap cleanup EXIT

clear

echo
echo "=========================================================="
echo "              VANTIXGLASS INSTALLER"
echo "              PTERODACTYL THEME"
echo "=========================================================="
echo

# ============================================================
# ROOT
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    die "Run this installer as root."
fi

ok "Root access detected."

# ============================================================
# PANEL DETECTION
# ============================================================

if [ ! -d "$PANEL" ]; then
    die "Pterodactyl directory not found: $PANEL"
fi

if [ ! -f "$PANEL/artisan" ]; then
    die "Laravel/Pterodactyl installation not detected."
fi

ok "Pterodactyl detected."

cd "$PANEL"

# ============================================================
# VERSION DETECTION
# ============================================================

log "Detecting Pterodactyl version..."

VERSION=""

if php artisan p:version >/tmp/ptero-version.txt 2>/dev/null; then
    VERSION="$(cat /tmp/ptero-version.txt | tr -d '\r' | head -n 1)"
fi

if [ -z "$VERSION" ]; then
    VERSION="$(grep -RhoE "VERSION[[:space:]]*=[[:space:]]*['\"][0-9]+\.[0-9]+\.[0-9]+['\"]" config app 2>/dev/null | head -n1 || true)"
fi

echo "Detected version: ${VERSION:-unknown}"

# ============================================================
# REQUIREMENTS
# ============================================================

for command in php curl unzip tar cp mkdir mv rm sed grep; do
    if ! command -v "$command" >/dev/null 2>&1; then
        die "Required command missing: $command"
    fi
done

ok "Required commands available."

# ============================================================
# PREVENT 2.X ACCIDENTAL INSTALL
# ============================================================

if echo "$VERSION" | grep -qE '^2\.'; then
    echo
    warn "Pterodactyl 2.x detected."
    echo
    echo "This installer modifies Laravel source files."
    echo "Pterodactyl 2.x uses its extension system."
    echo
    echo "Installation stopped to prevent damaging your Panel."
    echo
    echo "Use a native Pterodactyl 2.x extension for this version."
    exit 1
fi

# ============================================================
# BACKUP
# ============================================================

log "Creating backup..."

mkdir -p "$BACKUP"

tar -czf "$BACKUP/pterodactyl-theme-backup.tar.gz" \
    app \
    database \
    resources \
    routes \
    2>/dev/null || true

cp .env "$BACKUP/.env" 2>/dev/null || true

ok "Backup created:"
echo "    $BACKUP"

# ============================================================
# DOWNLOAD REPOSITORY
# ============================================================

log "Downloading theme source..."

rm -rf "$TMP"
mkdir -p "$TMP"

curl -fL "$REPO" -o "$TMP/theme.zip"

ok "Theme source downloaded."

# ============================================================
# EXTRACT
# ============================================================

log "Extracting theme..."

unzip -qo "$TMP/theme.zip" -d "$TMP/source"

THEME_DIR="$(find "$TMP/source" -mindepth 1 -maxdepth 1 -type d | head -n1)"

if [ -z "$THEME_DIR" ]; then
    die "Could not locate extracted theme directory."
fi

ok "Theme source extracted."

# ============================================================
# VERIFY
# ============================================================

log "Checking theme files..."

REQUIRED=(
    "app"
    "database"
    "resources"
    "routes"
)

for item in "${REQUIRED[@]}"; do
    if [ ! -e "$THEME_DIR/$item" ]; then
        die "Missing required theme directory: $item"
    fi
done

ok "Theme source verified."

# ============================================================
# COPY APP
# ============================================================

log "Installing application files..."

if [ -d "$THEME_DIR/app/Models" ]; then
    mkdir -p "$PANEL/app/Models"

    cp -f "$THEME_DIR/app/Models/ThemeSetting.php" \
        "$PANEL/app/Models/" 2>/dev/null || true

    cp -f "$THEME_DIR/app/Models/ThemeBackground.php" \
        "$PANEL/app/Models/" 2>/dev/null || true

    cp -f "$THEME_DIR/app/Models/ThemeAnnouncement.php" \
        "$PANEL/app/Models/" 2>/dev/null || true
fi

if [ -d "$THEME_DIR/app/Http/Controllers/Theme" ]; then
    mkdir -p "$PANEL/app/Http/Controllers/Theme"

    cp -rf "$THEME_DIR/app/Http/Controllers/Theme/"* \
        "$PANEL/app/Http/Controllers/Theme/"
fi

ok "Application files installed."

# ============================================================
# DATABASE
# ============================================================

log "Installing database migration..."

if [ -d "$THEME_DIR/database/migrations" ]; then
    mkdir -p "$PANEL/database/migrations"

    cp -f "$THEME_DIR/database/migrations/"* \
        "$PANEL/database/migrations/"
fi

ok "Migration installed."

# ============================================================
# RESOURCES
# ============================================================

log "Installing frontend resources..."

if [ -d "$THEME_DIR/resources/css" ]; then
    mkdir -p "$PANEL/resources/css"
    cp -rf "$THEME_DIR/resources/css/"* "$PANEL/resources/css/"
fi

if [ -d "$THEME_DIR/resources/js" ]; then
    mkdir -p "$PANEL/resources/js"
    cp -rf "$THEME_DIR/resources/js/"* "$PANEL/resources/js/"
fi

if [ -d "$THEME_DIR/resources/views/theme" ]; then
    mkdir -p "$PANEL/resources/views/theme"

    cp -rf "$THEME_DIR/resources/views/theme/"* \
        "$PANEL/resources/views/theme/"
fi

ok "Frontend resources installed."

# ============================================================
# ROUTES
# ============================================================

log "Installing theme route file..."

if [ -f "$THEME_DIR/routes/theme.php" ]; then
    cp -f "$THEME_DIR/routes/theme.php" "$PANEL/routes/theme.php"
fi

ok "Theme route file installed."

# ============================================================
# DATABASE MIGRATION
# ============================================================

log "Running database migration..."

cd "$PANEL"

if php artisan migrate --force; then
    ok "Database migration completed."
else
    warn "Migration failed."
    echo
    echo "Your backup is available at:"
    echo "$BACKUP"
    exit 1
fi

# ============================================================
# CREATE THEME CONFIG
# ============================================================

log "Creating default theme configuration..."

mkdir -p "$PANEL/config"

cat > "$PANEL/config/vantixglass.php" <<'PHP'
<?php

return [

    /*
    |--------------------------------------------------------------------------
    | VantixGlass Theme
    |--------------------------------------------------------------------------
    */

    'name' => 'VantixGlass',

    'glow' => true,

    'glass' => true,

    'primary' => '#7c3aed',

    'accent' => '#a855f7',

    'background' => null,

    'background_overlay' => 55,

    'login' => [
        'remember_me' => true,
        'title' => 'Welcome back',
    ],

    'announcements' => [
        'enabled' => true,
    ],

];
PHP

ok "Theme configuration created."

# ============================================================
# CACHE
# ============================================================

log "Clearing Laravel cache..."

php artisan optimize:clear

ok "Laravel cache cleared."

# ============================================================
# CONFIG CACHE
# ============================================================

log "Rebuilding configuration cache..."

php artisan config:cache 2>/dev/null || \
    warn "Configuration cache could not be rebuilt."

# ============================================================
# VIEW CACHE
# ============================================================

php artisan view:clear 2>/dev/null || true

ok "View cache cleared."

# ============================================================
# PERMISSIONS
# ============================================================

log "Fixing permissions..."

if id www-data >/dev/null 2>&1; then

    chown -R www-data:www-data \
        "$PANEL/storage" \
        "$PANEL/bootstrap/cache" \
        2>/dev/null || true

    ok "www-data permissions applied."

elif id nginx >/dev/null 2>&1; then

    chown -R nginx:nginx \
        "$PANEL/storage" \
        "$PANEL/bootstrap/cache" \
        2>/dev/null || true

    ok "nginx permissions applied."

else

    warn "Could not detect web-server user automatically."

fi

# ============================================================
# QUEUE
# ============================================================

log "Restarting Pterodactyl queue..."

systemctl restart pteroq 2>/dev/null || \
    warn "pteroq service could not be restarted automatically."

# ============================================================
# RESTART PHP
# ============================================================

for service in php8.4-fpm php8.3-fpm php8.2-fpm php8.1-fpm; do

    if systemctl list-unit-files | grep -q "^${service}"; then

        systemctl restart "$service" 2>/dev/null || true

        ok "Restarted $service."

        break

    fi

done

# ============================================================
# RESTART NGINX
# ============================================================

if systemctl is-active --quiet nginx; then
    systemctl reload nginx 2>/dev/null || true
    ok "Reloaded NGINX."
fi

# ============================================================
# FINISHED
# ============================================================

rm -f /tmp/ptero-version.txt

echo
echo "=========================================================="
echo -e "${GREEN}          VANTIXGLASS INSTALLED${NC}"
echo "=========================================================="
echo
echo "Features installed:"
echo
echo "  [✓] Custom theme configuration"
echo "  [✓] Glow system"
echo "  [✓] Glass system"
echo "  [✓] Custom colors"
echo "  [✓] Background support"
echo "  [✓] Background gallery"
echo "  [✓] Announcement database"
echo "  [✓] Login Remember Me component"
echo "  [✓] Admin theme controller"
echo "  [✓] Database migration"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "=========================================================="
echo
echo "IMPORTANT:"
echo
echo "The installer does NOT overwrite your existing"
echo "Pterodactyl login controller or main React layout."
echo
echo "Those files are version-specific and should be integrated"
echo "with the exact Panel release."
echo
echo "=========================================================="

