#!/bin/bash

set -euo pipefail

# Colors (only when stdout is a TTY)
if [ -t 1 ]; then
    ESC="$(printf '\033')"
    RED="${ESC}[0;31m"
    GREEN="${ESC}[0;32m"
    YELLOW="${ESC}[1;33m"
    BLUE="${ESC}[0;34m"
    NC="${ESC}[0m"
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_DIR="$ROOT_DIR/versions"
ENV_FILE="$ROOT_DIR/.env"

info() { echo -e "ℹ️  $1"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

if [ ! -d "$VERSIONS_DIR" ]; then
    error "versions/ directory not found. Create at least one version before deleting."
fi

AVAILABLE_VERSIONS=()
while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    AVAILABLE_VERSIONS+=("$dir")
done < <(find "$VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

if [ "${#AVAILABLE_VERSIONS[@]}" -eq 0 ]; then
    error "versions/ contains no versions to delete."
fi

TARGET_VERSION="${1:-}"

print_versions_menu() {
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE} 📦 Available versions${NC}"
    echo -e "${BLUE}===============================================${NC}"
    local idx=1
    for name in "${AVAILABLE_VERSIONS[@]}"; do
        printf "%d) versions/%s\n" "$idx" "$name"
        idx=$((idx + 1))
    done
}

select_version_interactively() {
    print_versions_menu
    while true; do
        read -p "Enter the number of the version to delete: " answer
        if [[ "$answer" =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] && [ "$answer" -le "${#AVAILABLE_VERSIONS[@]}" ]; then
            TARGET_VERSION="${AVAILABLE_VERSIONS[$((answer-1))]}"
            break
        fi
        warn "Invalid choice. Enter a number between 1 and ${#AVAILABLE_VERSIONS[@]}."
    done
}

if [ -n "$TARGET_VERSION" ]; then
    VERSION_FOUND="false"
    for name in "${AVAILABLE_VERSIONS[@]}"; do
        if [ "$name" = "$TARGET_VERSION" ]; then
            VERSION_FOUND="true"
            break
        fi
    done

    if [ "$VERSION_FOUND" != "true" ]; then
        error "Version '$TARGET_VERSION' does not exist in versions/."
    fi
else
    select_version_interactively
fi

TARGET_DIR="$VERSIONS_DIR/$TARGET_VERSION"

if [ ! -d "$TARGET_DIR" ]; then
    error "Directory $TARGET_DIR does not exist."
fi

echo -e "${YELLOW}You are about to delete: versions/${TARGET_VERSION}${NC}"
read -p "Delete this version? (y/N): " CONFIRM
CONFIRM=${CONFIRM:-n}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    info "Deletion cancelled."
    exit 0
fi

rm -rf "$TARGET_DIR"
success "versions/${TARGET_VERSION} removed."

if [ -f "$ENV_FILE" ]; then
    CURRENT_APP_VERSION=""
    if grep -qE '^APP_VERSION=' "$ENV_FILE"; then
        CURRENT_APP_VERSION=$(grep -E '^APP_VERSION=' "$ENV_FILE" | tail -n1 | cut -d= -f2- | tr -d '[:space:]')
    fi

    if [ "$CURRENT_APP_VERSION" = "$TARGET_VERSION" ]; then
        warn "Active version in .env matched the removed one ($TARGET_VERSION). APP_VERSION line deleted."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' '/^APP_VERSION=/d' "$ENV_FILE"
        else
            sed -i '/^APP_VERSION=/d' "$ENV_FILE"
        fi
    fi
fi

info "Done. Run \`make dev-init\` and pick a new version if needed."

