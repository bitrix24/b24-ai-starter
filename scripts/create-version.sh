#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_DIR="$ROOT_DIR/versions"
ENV_FILE="$ROOT_DIR/.env"

if [ -t 1 ]; then
    INFO_PREFIX="ℹ️ "
    SUCCESS_PREFIX="✅ "
    WARN_PREFIX="⚠️ "
    ERROR_PREFIX="❌ "
else
    INFO_PREFIX="[i] "
    SUCCESS_PREFIX="[ok] "
    WARN_PREFIX="[warn] "
    ERROR_PREFIX="[err] "
fi

info() { echo "${INFO_PREFIX}$1"; }
success() { echo "${SUCCESS_PREFIX}$1"; }
warn() { echo "${WARN_PREFIX}$1"; }
error() { echo "${ERROR_PREFIX}$1" >&2; exit 1; }

command -v rsync >/dev/null 2>&1 || error "rsync not found. Install it and try again."

mkdir -p "$VERSIONS_DIR"

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if [ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]; then
        warn "Working tree has uncommitted changes. Make sure you're ready to copy them into the new version."
    else
        info "Git working tree is clean."
    fi
fi

CURRENT_VERSION="current working copy"
if [ -f "$ENV_FILE" ]; then
    if CURRENT_ENV_VERSION=$(grep -E '^APP_VERSION=' "$ENV_FILE" | tail -n1 | cut -d= -f2-); then
        if [ -n "$CURRENT_ENV_VERSION" ]; then
            CURRENT_VERSION="$CURRENT_ENV_VERSION"
        fi
    fi
else
    warn ".env file not found — skipping APP_VERSION read/update."
fi

NEW_VERSION="${1:-}"
if [ -z "$NEW_VERSION" ]; then
    read -rp "Enter the new version name (e.g. v2): " NEW_VERSION
fi
NEW_VERSION="$(echo "$NEW_VERSION" | tr -d '[:space:]')"
[ -z "$NEW_VERSION" ] && error "Version name cannot be empty."

TARGET_DIR="$VERSIONS_DIR/$NEW_VERSION"
[ -e "$TARGET_DIR" ] && error "Version $NEW_VERSION already exists: $TARGET_DIR"

info "Current version: $CURRENT_VERSION"
info "Creating version: $NEW_VERSION"

RSYNC_OPTS=(
    "-a"
    "--exclude=.git/"
    "--exclude=versions/"
    "--exclude=node_modules/"
    "--exclude=.nuxt/"
    "--exclude=vendor/"
    "--exclude=.venv/"
    "--exclude=logs/"
)

rsync "${RSYNC_OPTS[@]}" "$ROOT_DIR/" "$TARGET_DIR/"
success "Folder versions/$NEW_VERSION created."

if [ -f "$ENV_FILE" ]; then
    tmp_env="$(mktemp)"
    cleanup() { rm -f "$tmp_env"; }
    trap cleanup EXIT

    if grep -q '^APP_VERSION=' "$ENV_FILE"; then
        sed "s/^APP_VERSION=.*/APP_VERSION=$NEW_VERSION/" "$ENV_FILE" >"$tmp_env"
    else
        cat "$ENV_FILE" >"$tmp_env"
        printf '\nAPP_VERSION=%s\n' "$NEW_VERSION" >>"$tmp_env"
    fi

    mv "$tmp_env" "$ENV_FILE"
    trap - EXIT
    success ".env updated: APP_VERSION=$NEW_VERSION"
fi

cat <<EOF

Next steps:
1. cd $TARGET_DIR
2. Launch the desired stack (for example, "make dev-php")
3. Validate that the version works before proceeding with development

By default the versions/ folder is tracked by Git. Add it to .gitignore or delete copies before committing if you want them to stay local.

EOF

success "Version $NEW_VERSION is ready."

