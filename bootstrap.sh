#!/usr/bin/env bash
# Bootstrap a fresh Debian 13 (trixie) install for Ansible, then run the playbook.
#
# Fresh machine:
#   sudo apt install -y curl
#   curl -fsSL https://raw.githubusercontent.com/CHANGEME/artisia/main/bootstrap.sh | bash
#
# Existing clone:
#   ./bootstrap.sh                 # full run
#   ./bootstrap.sh --tags java     # any extra args go to ansible-playbook
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/CHANGEME/artisia.git}"
REPO_DIR="${REPO_DIR:-$HOME/src/artisia}"

if [[ $EUID -eq 0 ]]; then
  echo "Run this as your normal user (it uses sudo where needed), not as root." >&2
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "debian" || "${VERSION_CODENAME:-}" != "trixie" ]]; then
  echo "Expected Debian 13 (trixie), found ${PRETTY_NAME:-unknown}." >&2
  exit 1
fi

echo "==> Installing Ansible and prerequisites"
sudo apt-get update
sudo apt-get install -y ansible git python3-debian curl

# If we're not already running from inside a clone, clone (or update) the repo.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/site.yml" ]]; then
  REPO_DIR="$SCRIPT_DIR"
elif [[ -d "$REPO_DIR/.git" ]]; then
  echo "==> Updating $REPO_DIR"
  git -C "$REPO_DIR" pull --ff-only
else
  echo "==> Cloning $REPO_URL to $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

echo "==> Installing Ansible collections"
ansible-galaxy collection install -r requirements.yml

echo "==> Running playbook (you'll be asked for your sudo password)"
ansible-playbook site.yml --ask-become-pass "$@"
