
#!/usr/bin/env bash
set -Eeuo pipefail

PANEL_DIR="/var/www/pterodactyl"
WINGS_BIN="/usr/local/bin/wings"
OS_NAME=""
PHP_VERSION=""

fail() {
    echo "[FEJL] $*" >&2
    exit 1
}

info() {
    echo
    echo "[+] $*"
}

check_root() {
    [[ $EUID -eq 0 ]] || fail "Kør scriptet med sudo eller som root."
}

select_os() {
    echo "=============================="
    echo " Pterodactyl Installer"
    echo "=============================="
    echo "0) Ubuntu 24.04"
    echo "1) Debian 12"
    echo

    read -r -p "Vælg system: " os_choice

    case "$os_choice" in
        0)
            OS_NAME="ubuntu"
            PHP_VERSION="8.3"
            ;;
        1)
            OS_NAME="debian"
            PHP_VERSION="8.2"
            ;;
        *)
            fail "Ugyldigt valg. Vælg 0 eller 1."
            ;;
    esac

    source /etc/os-release

    [[ "${ID:-}" == "$OS_NAME" ]] ||
        fail "Du valgte $OS_NAME, men serveren kører ${ID:-ukendt}."

    if [[ "$OS_NAME" == "ubuntu" ]]; then
        [[ "${VERSION_ID:-}" == "24.04" ]] ||
            fail "Kun Ubuntu 24.04 understøttes."
    else
        [[ "${VERSION_ID:-}" == "12" ]] ||
            fail "Kun Debian 12 understøttes."
    fi

    info "Valgt system: $OS_NAME"
    info "PHP-version: $PHP_VERSION"
}

install_dependencies() {
    info "Installerer afhængigheder"

    apt-get update

    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates curl gnupg unzip tar xz-utils git \
        nginx mariadb-server redis-server composer \
        "php${PHP_VERSION}" \
        "php${PHP_VERSION}-cli" \
        "php${PHP_VERSION}-gd" \
        "php${PHP_VERSION}-mysql" \
        "php${PHP_VERSION}-mbstring" \
        "php${PHP_VERSION}-bcmath" \
        "php${PHP_VERSION}-xml" \
        "php${PHP_VERSION}-fpm" \
        "php${PHP_VERSION}-curl" \
        "php${PHP_VERSION}-zip" \
        "php${PHP_VERSION}-intl"

    systemctl enable --now mariadb redis-server nginx
    systemctl enable --now "php${PHP_VERSION}-fpm"

    info "Afhængigheder installeret"
}

install_panel() {
    if [[ -e "$PANEL_DIR" ]] &&
       [[ -n "$(find "$PANEL_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        fail "$PANEL_DIR er ikke tom. Afbryder for at beskytte eksisterende filer."
    fi

    info "Henter Pterodactyl Panel"

    mkdir -p "$PANEL_DIR"

    curl -fL --retry 3 \
        https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz \
        -o /tmp/pterodactyl-panel.tar.gz

    tar -xzf /tmp/pterodactyl-panel.tar.gz -C "$PANEL_DIR"
    rm -f /tmp/pterodactyl-panel.tar.gz

    cd "$PANEL_DIR"

    cp .env.example .env
    chmod -R 755 storage bootstrap/cache
    chown -R www-data:www-data "$PANEL_DIR"

    info "Installerer Composer-pakker"

    COMPOSER_ALLOW_SUPERUSER=1 composer install \
        --no-dev --optimize-autoloader --no-interaction

    php artisan key:generate --force

    info "Konfigurerer Panel"

    php artisan p:environment:setup
    php artisan p:environment:database

    echo
    echo "Kontrollér databaseoplysningerne, før du fortsætter."
    read -r -p "Tryk Enter for at fortsætte..."

    php artisan migrate --seed --force
    php artisan p:user:make

    chown -R www-data:www-data "$PANEL_DIR"
    chmod -R 755 storage bootstrap/cache

    info "Panel-filer og database er konfigureret"

    echo "NGINX, HTTPS, cron og queue worker skal konfigureres separat."
    echo "Dokumentation: https://docs.pterodactyl.io/"
}

install_wings() {
    info "Installerer Docker"

    apt-get update
    apt-get install -y ca-certificates curl
    curl -fsSL https://get.docker.com | sh

    systemctl enable --now docker

    local arch

    case "$(dpkg --print-architecture)" in
        amd64) arch="amd64" ;;
        arm64) arch="arm64" ;;
        *) fail "CPU-arkitekturen understøttes ikke." ;;
    esac

    info "Henter Wings"

    mkdir -p /etc/pterodactyl

    curl -fL --retry 3 \
        "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${arch}" \
        -o "$WINGS_BIN"

    chmod 755 "$WINGS_BIN"

    cat > /etc/systemd/system/wings.service <<'EOF'
[Unit]
Description=Pterodactyl Wings
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
ExecStart=/usr/local/bin/wings
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wings

    echo
    echo "Wings er installeret."
    echo "Opret en node i Panel og gem konfigurationen i:"
    echo "/etc/pterodactyl/config.yml"
    echo
    echo "Start Wings bagefter med:"
    echo "systemctl start wings"
}

main() {
    check_root
    select_os

    echo
    echo "=============================="
    echo " Pterodactyl - $OS_NAME"
    echo "=============================="
    echo "1) Installer afhængigheder"
    echo "2) Installer Panel"
    echo "3) Installer Wings"
    echo "4) Afhængigheder + Panel"
    echo "0) Afslut"
    echo

    read -r -p "Vælg installation: " choice

    case "$choice" in
        1) install_dependencies ;;
        2) install_panel ;;
        3) install_wings ;;
        4)
            install_dependencies
            install_panel
            ;;
        0) exit 0 ;;
        *) fail "Ugyldigt valg." ;;
    esac
}

main "$@"
