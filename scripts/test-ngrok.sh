#!/bin/bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Helpers
print_header() {
    echo ""
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

extract_public_url() {
    python3 -c 'import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for tunnel in data.get("tunnels", []):
    url = tunnel.get("public_url") or ""
    if url.startswith("https://"):
        print(url)
        break
'
}

print_header "🧪 Ngrok test — domain retrieval"

# Stop running containers
print_warning "Stopping all containers..."
docker compose down > /dev/null 2>&1 || true
docker stop $(docker ps -q) > /dev/null 2>&1 || true
docker network prune -f > /dev/null 2>&1 || true

# Read token
echo "Enter your Ngrok authtoken:"
read -p "Ngrok authtoken: " NGROK_AUTHTOKEN

if [ -z "$NGROK_AUTHTOKEN" ]; then
    print_error "Authtoken is required!"
    exit 1
fi

# Update .env
print_warning "Updating .env..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/NGROK_AUTHTOKEN='.*'/NGROK_AUTHTOKEN='$NGROK_AUTHTOKEN'/" .env
else
    sed -i "s/NGROK_AUTHTOKEN='.*'/NGROK_AUTHTOKEN='$NGROK_AUTHTOKEN'/" .env
fi
print_success "Authtoken saved to .env"

# Start frontend + ngrok
print_header "🚀 Starting Ngrok container"
echo "Starting Ngrok with frontend..."
COMPOSE_PROFILES=frontend,ngrok docker compose up --build &
DOCKER_PID=$!

print_warning "Waiting for Ngrok to start..."
for i in {1..30}; do
    if docker ps --format '{{.Names}}' | grep -w ngrokFront > /dev/null; then
        print_success "Ngrok container detected!"
        break
    fi

    if ! kill -0 "$DOCKER_PID" 2>/dev/null; then
        print_error "docker compose process exited!"
        exit 1
    fi

    echo "Attempt $i/30: waiting for container..."
    sleep 2
done

if ! docker ps --format '{{.Names}}' | grep -w ngrokFront > /dev/null; then
    print_error "Ngrok container did not start within 60s!"
    exit 1
fi

print_header "🔍 Looking for Ngrok domain"

if ! command -v curl >/dev/null 2>&1; then
    print_error "curl is required for this test."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    print_error "python3 is required to parse the Ngrok inspect API."
    exit 1
fi

NGROK_API_URL=${NGROK_API_URL:-"http://localhost:4040/api/tunnels"}
NGROK_DOMAIN=""
LAST_RESPONSE=""

for i in {1..30}; do
    RESPONSE=$(curl -s --max-time 5 "$NGROK_API_URL" || true)
    if [ -n "$RESPONSE" ]; then
        LAST_RESPONSE="$RESPONSE"
        NGROK_DOMAIN=$(printf '%s' "$RESPONSE" | extract_public_url)
    fi

    if [ ! -z "$NGROK_DOMAIN" ]; then
        print_success "Domain found: $NGROK_DOMAIN"
        break
    fi

    echo "Attempt $i/30: polling inspect API..."
    sleep 2
done

print_header "📋 Test results"

if [ ! -z "$NGROK_DOMAIN" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|VIRTUAL_HOST='.*'|VIRTUAL_HOST='$NGROK_DOMAIN'|" .env
    else
        sed -i "s|VIRTUAL_HOST='.*'|VIRTUAL_HOST='$NGROK_DOMAIN'|" .env
    fi
    
    print_success "VIRTUAL_HOST updated in .env"
    echo ""
    echo "Test the domain:"
    echo "Frontend: ${BLUE}$NGROK_DOMAIN${NC}"
    echo ""
else
    print_error "Failed to obtain an Ngrok domain"
    if [ -n "$LAST_RESPONSE" ]; then
        echo ""
        echo "Inspect API response:"
        echo "$LAST_RESPONSE"
    fi
    echo ""
    echo "Logs:"
    docker logs ngrokFront 2>&1 || true
fi

echo ""
print_warning "Stop containers via Ctrl+C or docker compose down"
echo ""

trap 'echo ""; print_warning "Stopping containers..."; docker compose down; exit 0' INT
wait

