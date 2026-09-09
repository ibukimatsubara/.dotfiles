#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_dir/scripts/svu-power"
config_dir="$HOME/.config/svu-power"

usage() {
    cat <<'EOF'
Usage: scripts/setup-svu-power.sh <role>

Roles:
  client       Install ssh-svu on a Mac or other control machine
  coordinator  Install wake-svu on the always-on SVM
  worker       Install auto-suspend, svu-run, and optional WoWLAN on SVU

For worker setup, set SVU_WIFI_CONNECTION to the local NetworkManager
connection name when WoWLAN should also be configured.
EOF
}

ensure_local_config() {
    mkdir -p "$config_dir"
    if [[ ! -f "$config_dir/config" ]]; then
        install -m 0600 "$source_dir/config.example" "$config_dir/config"
        echo "Created $config_dir/config; fill in machine-specific values."
    fi
}

install_client() {
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$source_dir/ssh-svu.sh" "$HOME/.local/bin/ssh-svu"
    ensure_local_config
    echo "Installed client command: $HOME/.local/bin/ssh-svu"
}

install_coordinator() {
    if ! command -v perl >/dev/null 2>&1; then
        echo "Perl is required to send the wake packet." >&2
        exit 1
    fi

    mkdir -p "$HOME/.local/bin"
    ln -sfn "$source_dir/wake-svu.sh" "$HOME/.local/bin/wake-svu"
    ensure_local_config
    echo "Installed coordinator command: $HOME/.local/bin/wake-svu"
}

install_worker() {
    if [[ "$(uname -s)" != "Linux" ]] || ! command -v systemctl >/dev/null 2>&1; then
        echo "The worker role requires Linux with systemd." >&2
        exit 1
    fi

    sudo install -m 0755 "$source_dir/svu-auto-suspend.sh" \
        /usr/local/sbin/svu-auto-suspend
    sudo install -m 0755 "$source_dir/svu-run.sh" /usr/local/bin/svu-run
    sudo install -m 0644 "$source_dir/svu-auto-suspend.service" \
        /etc/systemd/system/svu-auto-suspend.service
    sudo install -m 0644 "$source_dir/svu-auto-suspend.timer" \
        /etc/systemd/system/svu-auto-suspend.timer
    sudo install -m 0644 "$source_dir/svu-auto-suspend.default" \
        /etc/default/svu-auto-suspend
    sudo install -m 0644 "$source_dir/svu-auto-suspend.tmpfiles" \
        /etc/tmpfiles.d/svu-auto-suspend.conf

    sudo systemd-tmpfiles --create /etc/tmpfiles.d/svu-auto-suspend.conf
    sudo systemctl daemon-reload
    sudo systemctl enable --now svu-auto-suspend.timer

    if [[ -n "${SVU_WIFI_CONNECTION:-}" ]]; then
        sudo nmcli connection modify "$SVU_WIFI_CONNECTION" \
            802-11-wireless.wake-on-wlan magic
        echo "Enabled magic-packet WoWLAN for the selected Wi-Fi connection."
    else
        echo "Skipped NetworkManager WoWLAN setup; SVU_WIFI_CONNECTION was not set."
    fi

    echo "Installed and enabled SVU auto-suspend."
}

if (($# != 1)); then
    usage >&2
    exit 2
fi

case "$1" in
    client) install_client ;;
    coordinator) install_coordinator ;;
    worker) install_worker ;;
    -h|--help) usage ;;
    *)
        usage >&2
        exit 2
        ;;
esac
