#!/bin/bash
# VPS setup for grasp-mobile.
# Run as your normal user (not root). Uses sudo where needed.
# Tested on Debian/Ubuntu.
#
# Usage:
#   bash install.sh --domain grasp.yourdomain.com --api-key "$(openssl rand -base64 32)"

set -euo pipefail

DOMAIN=""
API_KEY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)  DOMAIN="$2";  shift 2 ;;
        --api-key) API_KEY="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

[[ -z "$DOMAIN"  ]] && { echo "Usage: $0 --domain <domain> --api-key <key>"; exit 1; }
[[ -z "$API_KEY" ]] && { echo "--api-key required"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── System packages ──────────────────────────────────────────────────────────

echo "Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y curl git rclone

# ── Caddy ────────────────────────────────────────────────────────────────────

if ! command -v caddy &>/dev/null; then
    echo "Installing Caddy..."
    sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt-get update -qq
    sudo apt-get install -y caddy
fi

# ── uv ───────────────────────────────────────────────────────────────────────

if ! command -v uv &>/dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# ── grasp-backend ────────────────────────────────────────────────────────────

GRASP_DIR="$HOME/Code/rjsheperd/grasp"
if [[ ! -d "$GRASP_DIR" ]]; then
    echo "Cloning grasp fork..."
    mkdir -p "$(dirname "$GRASP_DIR")"
    git clone https://github.com/rjsheperd/grasp.git "$GRASP_DIR"
fi

echo "Installing grasp-backend..."
uv tool install --editable "$GRASP_DIR"

mkdir -p "$HOME/org" "$HOME/.config/grasp"
touch "$HOME/org/grasp.org"

if [[ ! -f "$HOME/.config/grasp/config.py" ]]; then
    cat > "$HOME/.config/grasp/config.py" <<'PYEOF'
from typing import List

class Config:
    @staticmethod
    def format_selection(selection: str) -> List[str]:
        if selection.startswith('__LOCAL__:'):
            first_line, _, body = selection.partition('\n\n')
            local_path = first_line[len('__LOCAL__:'):]
            name = local_path.rsplit('/', 1)[-1]
            lines = [f'[[file:{local_path}][{name}]]']
            if body.strip():
                lines += ['', '#+begin_quote', body.strip(), '#+end_quote']
            return lines
        return ['#+begin_quote', selection.strip(), '#+end_quote']

    @staticmethod
    def format_comment(comment: str) -> List[str]:
        return ['#+begin_comment', comment.strip(), '#+end_comment']
PYEOF
fi

# ── grasp-backend systemd service ────────────────────────────────────────────

mkdir -p "$HOME/.config/systemd/user"
sed "s|REPLACE_WITH_YOUR_KEY|${API_KEY}|g" \
    "$SCRIPT_DIR/grasp-backend.service" \
    > "$HOME/.config/systemd/user/grasp-backend.service"

systemctl --user daemon-reload
systemctl --user enable --now grasp-backend.service
echo "grasp-backend: $(systemctl --user is-active grasp-backend.service)"

# ── PWA static files ─────────────────────────────────────────────────────────

echo "Deploying PWA static files..."
sudo mkdir -p /srv/grasp-mobile
sudo cp -r "$SCRIPT_DIR/../"*.{html,js,json} /srv/grasp-mobile/ 2>/dev/null || true
sudo cp -r "$SCRIPT_DIR/../"*.png            /srv/grasp-mobile/ 2>/dev/null || true
sudo chown -R www-data:www-data /srv/grasp-mobile

# ── Caddy config ─────────────────────────────────────────────────────────────

sudo mkdir -p /var/log/caddy
CADDYFILE="$SCRIPT_DIR/Caddyfile"
DEPLOYED="/etc/caddy/Caddyfile"
sudo cp "$CADDYFILE" "$DEPLOYED"
sudo sed -i "s|grasp.yourdomain.com|${DOMAIN}|g" "$DEPLOYED"
sudo systemctl enable --now caddy
sudo systemctl reload caddy

echo ""
echo "Done."
echo "  Backend: $(systemctl --user is-active grasp-backend)"
echo "  Caddy:   $(systemctl is-active caddy)"
echo "  URL:     https://${DOMAIN}"
echo ""
echo "Next: configure rclone and org-sync on this VPS to sync grasp.org to S3."
echo "  See: ~/.config/org-sync/config.example"
