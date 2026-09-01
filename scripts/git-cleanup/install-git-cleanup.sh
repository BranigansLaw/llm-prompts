#!/usr/bin/env bash
#
# install-git-cleanup.sh — Registers the git-cleanup command on Linux.
#
# By default it creates a symlink named 'git-cleanup' in a bin directory that is
# on your PATH (~/.local/bin, falling back to /usr/local/bin) pointing at
# git-cleanup.sh next to this installer. The change is idempotent.
#
# Usage:
#   ./install-git-cleanup.sh              # install to ~/.local/bin (or override)
#   ./install-git-cleanup.sh --bin-dir DIR
#   ./install-git-cleanup.sh --uninstall  # remove the symlink
#   ./install-git-cleanup.sh --help

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$script_dir/git-cleanup.sh"

BIN_DIR=""
UNINSTALL=0

usage() {
    sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bin-dir)   BIN_DIR="${2:?--bin-dir requires a path}"; shift ;;
        --uninstall) UNINSTALL=1 ;;
        --help|-h)   usage; exit 0 ;;
        *) printf '!!  Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# Choose a bin directory if not provided.
if [[ -z "$BIN_DIR" ]]; then
    if [[ -d "$HOME/.local/bin" ]] || [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
        BIN_DIR="$HOME/.local/bin"
    else
        BIN_DIR="/usr/local/bin"
    fi
fi

link_path="$BIN_DIR/git-cleanup"

if [[ $UNINSTALL -eq 1 ]]; then
    if [[ -L "$link_path" || -e "$link_path" ]]; then
        rm -f "$link_path"
        printf 'Removed: %s\n' "$link_path"
    else
        printf 'git-cleanup is not installed at %s; nothing to remove.\n' "$link_path"
    fi
    exit 0
fi

if [[ ! -f "$target" ]]; then
    printf '!!  Could not find git-cleanup.sh at: %s\n' "$target" >&2
    exit 1
fi

# Make the script itself executable.
chmod +x "$target"

# Ensure the bin directory exists.
mkdir -p "$BIN_DIR"

# Create (or refresh) the symlink.
ln -sf "$target" "$link_path"
printf 'Installed: %s -> %s\n' "$link_path" "$target"

# Warn if the chosen bin directory is not on PATH.
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    printf '\n!!  %s is not on your PATH.\n' "$BIN_DIR"
    printf '    Add this line to your ~/.bashrc or ~/.zshrc, then restart your shell:\n'
    printf '        export PATH="%s:$PATH"\n' "$BIN_DIR"
fi

printf '\nDone. Run '\''git-cleanup'\'' from any git repository.\n'
printf 'Try '\''git-cleanup --dry-run'\'' first to preview.\n'
