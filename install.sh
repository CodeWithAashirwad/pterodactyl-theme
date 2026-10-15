bash
#!/bin/bash

set -Eeuo pipefail

# ============================================================
# VANTIXGLASS - PTERODACTYL THEME INSTALLER
# Author: AashirwadGamerzz
# ============================================================

THEME_NAME="VantixGlass"
PANEL_DIR="/var/www/pterodactyl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE="$SCRIPT_DIR/pterodactyl-vantix-theme.zip"
TEMP_DIR="/tmp/vantixglass-install"
BACKUP_DIR="/var/backups/pterodactyl-vantixglass-$(date +%Y%m%d-%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

fail() {
    error "$1"
    exit 1
}

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo
echo "============================================================"
echo "              VANTIXGLASS INSTALLER"
echo "              Pterodactyl Theme"
echo "============================================================"
echo

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [ "$(id -u)" != "0" ]; then
    fail "Please run this installer as root."
fi

success "Running as root."

# ------------------------------------------------------------
# Detect Pterodactyl
# ------------------------------------------------------------

if [ ! -d "$PANEL_DIR" ]; then
    fail "Pterodactyl was not found at $PANEL_DIR"
fi

if [ ! -f "$PANEL_DIR/artisan" ]; then
    fail "$PANEL_DIR exists, but this does not look like a Pterodactyl Panel."
fi

success "Pterodactyl Panel detected."

cd "$PANEL_DIR"

# ------------------------------------------------------------
# Check required commands
# ------------------------------------------------------------

for command in php unzip cp mv mkdir chown; do
    if ! command -v "$command" >/dev/null 2>&1; then
        fail "Required command '$command' was not found."
    fi
done

success "Required system commands found."

# ------------------------------------------------------------
# Check package
# ------------------------------------------------------------

if [ ! -f "$PACKAGE" ]; then
    fail "pterodactyl-vantix-theme.zip was not found next to install.sh."
fi

success "Theme package found."

# ------------------------------------------------------------
# Check PHP
# ------------------------------------------------------------

PHP_VERSION="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)"

if [ -z "$PHP_VERSION" ]; then
    fail "Unable to detect PHP version."
fi

info "PHP version: $PHP_VERSION"

# ------------------------------------------------------------
# Create backup
# ------------------------------------------------------------

info "Creating backup..."

mkdir -p "$BACKUP_DIR"

# Backup only files that this installer changes.
tar -czf "$BACKUP_DIR/panel-files.tar.gz" \
    app/Models \
    app/Http/Controllers \
    database/migrations \
    resources/views \
    resources/css \
    resources/js \
    routes \
    2>/dev/null || true

success "Backup created: $BACKUP_DIR"

# ------------------------------------------------------------
# Extract package
# ------------------------------------------------------------

info "Extracting theme package..."

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

unzip -q "$PACKAGE" -d "$TEMP_DIR"

PACKAGE_ROOT="$TEMP_DIR/pterodactyl-vantix-theme"

if [ ! -d "$PACKAGE_ROOT" ]; then
    # Handle ZIP files that don't contain a root folder.
    PACKAGE_ROOT="$TEMP_DIR"
fi

success "Theme package extracted."

# ------------------------------------------------------------
# Verify important files
# ------------------------------------------------------------

REQUIRED_FILES=(
    "database/migrations/2026_10_15_000000_create_theme_tables.php"
    "app/Models/ThemeSetting.php"
    "app/Models/ThemeBackground.php"
    "app/Models/ThemeAnnouncement.php"
    "app/Http/Controllers/Theme/ThemeAdminController.php"
    "resources/css/theme.css"
    "resources/js/theme.js"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$PACKAGE_ROOT/$file" ]; then
        fail "Package is missing: $file"
    fi
done

success "Theme package verified."

# ------------------------------------------------------------
# Copy migration
# ------------------------------------------------------------

info "Installing database migration..."

mkdir -p "$PANEL_DIR/database/migrations"

cp -f \
    "$PACKAGE_ROOT/database/migrations/2026_10_15_000000_create_theme_tables.php" \
    "$PANEL_DIR/database/migrations/"

success "Database migration installed."

# ------------------------------------------------------------
# Copy models
# ------------------------------------------------------------

info "Installing theme models..."

mkdir -p "$PANEL_DIR/app/Models"

cp -f "$PACKAGE_ROOT/app/Models/ThemeSetting.php" \
      "$PANEL_DIR/app/Models/ThemeSetting.php"

cp -f "$PACKAGE_ROOT/app/Models/ThemeBackground.php" \
      "$PANEL_DIR/app/Models/ThemeBackground.php"

cp -f "$PACKAGE_ROOT/app/Models/ThemeAnnouncement.php" \
      "$PANEL_DIR/app/Models/ThemeAnnouncement.php"

success "Theme models installed."

# ------------------------------------------------------------
# Copy controller
# ------------------------------------------------------------

info "Installing theme controller..."

mkdir -p "$PANEL_DIR/app/Http/Controllers/Theme"

cp -f \
    "$PACKAGE_ROOT/app/Http/Controllers/Theme/ThemeAdminController.php" \
    "$PANEL_DIR/app/Http/Controllers/Theme/ThemeAdminController.php"

success "Theme controller installed."

# ------------------------------------------------------------
# Copy CSS
# ------------------------------------------------------------

info "Installing theme CSS..."

mkdir -p "$PANEL_DIR/resources/css"

cp -f \
    "$PACKAGE_ROOT/resources/css/theme.css" \
    "$PANEL_DIR/resources/css/theme.css"

success "Theme CSS installed."

# ------------------------------------------------------------
# Copy JS
# ------------------------------------------------------------

info "Installing theme JavaScript..."

mkdir -p "$PANEL_DIR/resources/js"

cp -f \
    "$PACKAGE_ROOT/resources/js/theme.js" \
    "$PANEL_DIR/resources/js/theme.js"

success "Theme JavaScript installed."

# ------------------------------------------------------------
# Copy Blade views
# ------------------------------------------------------------

info "Installing Blade views..."

mkdir -p "$PANEL_DIR/resources/views/theme/partials"

cp -f \
    "$PACKAGE_ROOT/resources/views/theme/admin.blade.php" \
    "$PANEL_DIR/resources/views/theme/admin.blade.php"

cp -f \
    "$PACKAGE_ROOT/resources/views/theme/login-remember-me.blade.php" \
    "$PANEL_DIR/resources/views/theme/login-remember-me.blade.php"

cp -f \
    "$PACKAGE_ROOT/resources/views/theme/partials/config.blade.php" \
    "$PANEL_DIR/resources/views/theme/partials/config.blade.php"

cp -f \
    "$PACKAGE_ROOT/resources/views/theme/partials/announcements.blade.php" \
    "$PANEL_DIR/resources/views/theme/partials/announcements.blade.php"

success "Blade views installed."

# ------------------------------------------------------------
# Install route file separately
# ------------------------------------------------------------

mkdir -p "$PANEL_DIR/routes"

cp -f \
    "$PACKAGE_ROOT/routes/theme.php" \
    "$PANEL_DIR/routes/theme.php"

success "Theme routes installed."

# ------------------------------------------------------------
# Database migration
# ------------------------------------------------------------

info "Running database migration..."

cd "$PANEL_DIR"

if ! php artisan migrate --force; then
    error "Database migration failed."
    echo
    echo "Your files were backed up here:"
    echo "$BACKUP_DIR"
    exit 1
fi

success "Database migration completed."

# ------------------------------------------------------------
# Storage/cache permissions
# ------------------------------------------------------------

info "Fixing permissions..."

if id www-data >/dev/null 2>&1; then
    chown -R www-data:www-data \
        "$PANEL_DIR/storage" \
        "$PANEL_DIR/bootstrap/cache" \
        2>/dev/null || true
fi

success "Permissions updated."

# ------------------------------------------------------------
# Clear Laravel cache
# ------------------------------------------------------------

info "Clearing Laravel caches..."

php artisan optimize:clear

success "Laravel caches cleared."

# ------------------------------------------------------------
# Try to cache configuration
# ------------------------------------------------------------

info "Rebuilding Laravel configuration cache..."

php artisan config:cache 2>/dev/null || warn "Config cache could not be rebuilt."

# ------------------------------------------------------------
# Finish
# ------------------------------------------------------------

echo
echo "============================================================"
echo -e "${GREEN}VANTIXGLASS INSTALLATION COMPLETE${NC}"
echo "============================================================"
echo
echo "Installed:"
echo "  ✓ Theme database"
echo "  ✓ Theme models"
echo "  ✓ Theme controller"
echo "  ✓ Theme CSS"
echo "  ✓ Theme JavaScript"
echo "  ✓ Admin theme view"
echo "  ✓ Background gallery"
echo "  ✓ Announcement system"
echo "  ✓ Login Remember Me view"
echo
echo "Backup:"
echo "  $BACKUP_DIR"
echo
echo -e "${YELLOW}IMPORTANT:${NC}"
echo
echo "The following integration is intentionally not automatically"
echo "forced into your existing Pterodactyl source:"
echo
echo "  1. Main Panel layout"
echo "  2. Existing login controller"
echo "  3. Existing frontend build configuration"
echo "  4. Existing admin route registration"
echo
echo "This prevents the installer from overwriting Pterodactyl"
echo "version-specific files."
echo
echo "Theme admin:"
echo "  /admin/theme"
echo
echo "Remember Me:"
echo "  Add the supplied login-remember-me.blade.php to the"
echo "  existing Pterodactyl login form and pass the remember"
echo "  value to Laravel authentication."
echo
echo "============================================================"
