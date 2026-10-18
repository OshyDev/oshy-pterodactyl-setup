
#!/usr/bin/env bash
set -Eeuo pipefail

PANEL_DIR="/var/www/pterodactyl"
WINGS_BIN="/usr/local/bin/wings"

fail() {
    echo "[FEJL] $*" >&2
    exit 1
}

info() {
    echo
    echo "[+] $*"
}

check_root() {
    [[ $EUID -eq 0 ]] || fail "Kør scriptet som root."
}

check_os() {
    source /etc/os-release
    [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]] ||
        fail "Kun Ubuntu 24.04 LTS understøttes."
}

install_dependencies() {
    info "Installerer pakker"

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        ca-certificates curl gnupg unzip tar xz-utils git \
        nginx mariadb-server redis-server \
        php8.3 php8.3-cli php8.3-gd php8.3-mysql \
        php8.3-mbstring php8.3-bcmath php8.3-xml \
        php8.3-fpm php8.3-curl php8.3-zip php8.3-intl

    if ! command -v composer >/dev/null 2>&1; then
        apt-get install -y composer
    fi

    systemctl enable --now mariadb redis-server nginx php8.3-fpm
}

install_panel() {
    if [[ -e "$PANEL_DIR" ]] &&
       [[ -n "$(find "$PANEL_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
        fail "$PANEL_DIR er ikke tom. Afbryder for at beskytte eksisterende filer."
    fi

    info "Henter Pterodactyl Panel"

    mkdir -p "$PANEL_DIR"
    cd "$PANEL_DIR"

    curl -fL --retry 3 \
        https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz \
        -o /tmp/pterodactyl-panel.tar.gz

    tar -xzf /tmp/pterodactyl-panel.tar.gz -C "$PANEL_DIR"
    rm -f /tmp/pterodactyl-panel.tar.gz

    cp .env.example .env
    chmod -R 755 storage bootstrap/cache

    info "Installerer Composer-pakker"

    COMPOSER_ALLOW_SUPERUSER=1 composer install \
        --no-dev --optimize-autoloader --no-interaction

    php artisan key:generate --force

    info "Konfigurerer Panel"

    php artisan p:environment:setup
    php artisan p:environment:database

    echo
    echo "Sørg for, at database og databasebruger er oprettet."
    read -r -p "Tryk Enter for at fortsætte med migrationer..."

    php artisan migrate --seed --force
    php artisan p:user:make

    chown -R www-data:www-data "$PANEL_DIR"
    chmod -R 755 storage bootstrap/cache

    info "Panel installeret"
    echo "Konfigurer NGINX, HTTPS, cron og queue worker."
    echo "Se https://docs.pterodactyl.io/"
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
    echo "Opret en node i Panel, og gem dens konfiguration i:"
    echo "/etc/pterodactyl/config.yml"
    echo
    echo "Start Wings med: systemctl start wings"
}

main() {
    check_root
    check_os

    echo "=============================="
    echo " Pterodactyl Installer"
    echo "=============================="
    echo "1) Installer afhængigheder"
    echo "2) Installer Panel"
    echo "3) Installer Wings"
    echo "4) Installer afhængigheder + Panel"
    echo "0) Afslut"
    echo

    read -r -p "Vælg: " choice

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
