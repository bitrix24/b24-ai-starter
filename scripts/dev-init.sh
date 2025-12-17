#!/bin/bash

set -euo pipefail

# Colors for output (disabled when stdout is not a TTY)
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

# Helpers for environment manipulations
set_env_var() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" .env 2>/dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^${key}=.*|${key}=${value}|" .env
        else
            sed -i "s|^${key}=.*|${key}=${value}|" .env
        fi
    else
        echo "${key}=${value}" >> .env
    fi
}

get_env_var() {
    local key="$1"
    local default_value="$2"
    local current_value

    current_value=$(grep -E "^${key}=" .env 2>/dev/null | tail -n1 | cut -d= -f2- )
    if [ -z "$current_value" ]; then
        echo "$default_value"
    else
        echo "$current_value"
    fi
}

generate_random_string() {
    local length="${1:-8}"
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex $((length / 2))
    else
        tr -dc 'a-z0-9' </dev/urandom | head -c "$length"
    fi
}

parse_ngrok_tunnel() {
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

# Header helper
print_header() {
    echo ""
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
}

# Success helper
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Warning helper
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Error helper
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSIONS_DIR="$REPO_ROOT/versions"
WORKDIR="$REPO_ROOT"
SELECTED_VERSION=""
ACTIVE_CONTEXT_LABEL="root directory"

# Parse arguments / env variables
REQUESTED_VERSION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            shift
            if [ $# -eq 0 ]; then
                print_error "Provide a version name (or root) for --version"
                exit 1
            fi
            REQUESTED_VERSION="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--version <name>|root]"
            exit 0
            ;;
        *)
            print_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ -z "$REQUESTED_VERSION" ] && [ -n "${DEV_INIT_VERSION:-}" ]; then
    REQUESTED_VERSION="${DEV_INIT_VERSION}"
fi

# Scan available versions
AVAILABLE_VERSIONS=()
if [ -d "$VERSIONS_DIR" ]; then
    while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        AVAILABLE_VERSIONS+=("$(basename "$dir")")
    done < <(find "$VERSIONS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

DEFAULT_VERSION_FROM_ENV=""
if [ -f "$REPO_ROOT/.env" ]; then
    if grep -qE '^APP_VERSION=' "$REPO_ROOT/.env"; then
        DEFAULT_VERSION_FROM_ENV=$(grep -E '^APP_VERSION=' "$REPO_ROOT/.env" | tail -n1 | cut -d= -f2- | tr -d '[:space:]')
    fi
fi

select_version_interactively() {
    local total="$1"
    local default_choice="$2"
    local choice=""

    while true; do
        read -p "Enter a number [${default_choice}]: " choice
        choice=${choice:-$default_choice}

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "$total" ]; then
            echo "$choice"
            return 0
        fi

        print_warning "Invalid choice, try again."
    done
}

if [ ${#AVAILABLE_VERSIONS[@]} -gt 0 ]; then
    TOTAL_OPTIONS=${#AVAILABLE_VERSIONS[@]}
    DEFAULT_CHOICE=0

    if [ -n "$DEFAULT_VERSION_FROM_ENV" ]; then
        for idx in "${!AVAILABLE_VERSIONS[@]}"; do
            if [ "${AVAILABLE_VERSIONS[$idx]}" = "$DEFAULT_VERSION_FROM_ENV" ]; then
                DEFAULT_CHOICE=$((idx + 1))
                break
            fi
        done
    fi

    if [ -n "$REQUESTED_VERSION" ]; then
        REQ_LOWER=$(printf '%s' "$REQUESTED_VERSION" | tr '[:upper:]' '[:lower:]')
        if [ "$REQ_LOWER" = "root" ]; then
            SELECTED_VERSION=""
        else
            FOUND=false
            for name in "${AVAILABLE_VERSIONS[@]}"; do
                if [ "$name" = "$REQUESTED_VERSION" ]; then
                    FOUND=true
                    break
                fi
            done

            if [ "$FOUND" = false ]; then
                print_error "Version '$REQUESTED_VERSION' not found in versions/"
                exit 1
            fi

            SELECTED_VERSION="$REQUESTED_VERSION"
        fi
    else
        print_header "📦 Detected project versions"
        ROOT_SUFFIX=""
        if [ "$DEFAULT_CHOICE" -eq 0 ]; then
            ROOT_SUFFIX=" (default)"
        fi
        echo "0) Root directory${ROOT_SUFFIX}"
        for idx in "${!AVAILABLE_VERSIONS[@]}"; do
            num=$((idx + 1))
            suffix=""
            if [ "$num" -eq "$DEFAULT_CHOICE" ]; then
                suffix=" (default)"
            fi
            echo "${num}) versions/${AVAILABLE_VERSIONS[$idx]}${suffix}"
        done

        SELECTED_NUMBER=$(select_version_interactively "$TOTAL_OPTIONS" "$DEFAULT_CHOICE")
        if [ "$SELECTED_NUMBER" -eq 0 ]; then
            SELECTED_VERSION=""
        else
            array_index=$((SELECTED_NUMBER - 1))
            SELECTED_VERSION="${AVAILABLE_VERSIONS[$array_index]}"
        fi
    fi
else
    if [ -n "$REQUESTED_VERSION" ]; then
        REQ_LOWER=$(printf '%s' "$REQUESTED_VERSION" | tr '[:upper:]' '[:lower:]')
        if [ "$REQ_LOWER" != "root" ]; then
            print_error "versions/ directory not found, cannot select '$REQUESTED_VERSION'"
            exit 1
        fi
    fi
fi

if [ -n "$SELECTED_VERSION" ]; then
    WORKDIR="$VERSIONS_DIR/$SELECTED_VERSION"
    if [ ! -d "$WORKDIR" ]; then
        print_error "Directory versions/$SELECTED_VERSION not found"
        exit 1
    fi
    ACTIVE_CONTEXT_LABEL="versions/$SELECTED_VERSION"
else
    WORKDIR="$REPO_ROOT"
    ACTIVE_CONTEXT_LABEL="root directory"
fi

cd "$WORKDIR"

print_header "📁 Context: $ACTIVE_CONTEXT_LABEL"

# Ensure .env exists
if [ ! -f ".env" ]; then
    print_warning ".env not found. Copying from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success ".env created from .env.example"
        print_warning "IMPORTANT: Update the Ngrok auth token inside .env!"
    else
        print_error ".env.example not found!"
        print_error "Create .env.example with the required environment variables"
        exit 1
    fi
else
    print_success ".env found"
fi

print_header "🚀 Bitrix24 AI Starter — project initialization (${ACTIVE_CONTEXT_LABEL})"

# 1. Ngrok auth token
print_header "🔑 Ngrok setup"

# Check existing token in .env
EXISTING_TOKEN=$(grep "NGROK_AUTHTOKEN=" .env | cut -d"'" -f2 2>/dev/null || true)
if [ ! -z "$EXISTING_TOKEN" ] && [ "$EXISTING_TOKEN" != "your_ngrok_authtoken_here" ]; then
    echo "Existing Ngrok authtoken detected in .env"
    read -p "Use the existing token? (y/n, default y): " USE_EXISTING
    USE_EXISTING=${USE_EXISTING:-y}
    
    if [[ "$USE_EXISTING" =~ ^[Yy]$ ]]; then
        NGROK_AUTHTOKEN="$EXISTING_TOKEN"
        print_success "Using existing Ngrok authtoken"
    else
        echo "Enter a new Ngrok authtoken:"
        echo "(You can get one at https://ngrok.com/)"
        read -p "Ngrok authtoken: " NGROK_AUTHTOKEN
    fi
else
    echo "Enter your Ngrok authtoken:"
    echo "(You can get one at https://ngrok.com/)"
    read -p "Ngrok authtoken: " NGROK_AUTHTOKEN
fi

if [ -z "$NGROK_AUTHTOKEN" ]; then
    print_error "Ngrok authtoken is required!"
    exit 1
fi

# Update .env with Ngrok token
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/NGROK_AUTHTOKEN='[^']*'/NGROK_AUTHTOKEN='$NGROK_AUTHTOKEN'/" .env
else
    # Linux
    sed -i "s/NGROK_AUTHTOKEN='[^']*'/NGROK_AUTHTOKEN='$NGROK_AUTHTOKEN'/" .env
fi

print_success "Ngrok authtoken saved to .env"

# 2. Backend selection
print_header "🛠 Backend selection"
echo "Choose backend language:"
echo "1) PHP (Symfony)"
echo "2) Python (Django)" 
echo "3) Node.js (Express)"
echo ""
read -p "Enter a number (1-3): " BACKEND_CHOICE

case $BACKEND_CHOICE in
    1)
        BACKEND="php"
        SERVER_HOST="http://api-php:8000"
        ;;
    2)
        BACKEND="python"
        SERVER_HOST="http://api-python:8000"
        ;;
    3)
        BACKEND="node"
        SERVER_HOST="http://api-node:8000"
        ;;
    *)
        print_error "Invalid choice! Using PHP by default."
        BACKEND="php"
        SERVER_HOST="http://api-php:8000"
        ;;
esac

print_success "Selected backend: $BACKEND"

# Update SERVER_HOST in .env (container-to-container communication)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s|SERVER_HOST='http://api-some:8000'|SERVER_HOST='$SERVER_HOST'|" .env
else
    # Linux
    sed -i "s|SERVER_HOST='http://api-some:8000'|SERVER_HOST='$SERVER_HOST'|" .env
fi

print_success "SERVER_HOST updated in .env: $SERVER_HOST"

print_header "🐇 RabbitMQ setup"
read -p "Enable RabbitMQ for background jobs? (y/N, default n): " RABBITMQ_TOGGLE
RABBITMQ_TOGGLE=${RABBITMQ_TOGGLE:-n}

RABBITMQ_ENABLED="0"

if [[ "$RABBITMQ_TOGGLE" =~ ^[Yy]$ ]]; then
    RABBITMQ_ENABLED="1"

    print_header "⚙ RabbitMQ configuration mode"
    echo "1) Automatic (recommended)"
    echo "2) Manual"
    read -p "Choose mode [1]: " RABBITMQ_MODE
    RABBITMQ_MODE=${RABBITMQ_MODE:-1}

    if [ "$RABBITMQ_MODE" -eq 1 ]; then
        RABBITMQ_USER="queue_$(generate_random_string 6)"
        RABBITMQ_PASSWORD="$(generate_random_string 12)"
        RABBITMQ_PREFETCH="5"

        print_success "RabbitMQ will be configured automatically"
        echo "Username: $RABBITMQ_USER"
        echo "Password: $RABBITMQ_PASSWORD"
        echo "Prefetch: $RABBITMQ_PREFETCH"
    else
        EXISTING_RABBITMQ_USER=$(get_env_var "RABBITMQ_USER" "queue_user")
        read -p "Username [${EXISTING_RABBITMQ_USER}]: " RABBITMQ_USER
        RABBITMQ_USER=${RABBITMQ_USER:-$EXISTING_RABBITMQ_USER}

        EXISTING_RABBITMQ_PASSWORD=$(get_env_var "RABBITMQ_PASSWORD" "queue_password")
        read -p "Password [${EXISTING_RABBITMQ_PASSWORD}]: " RABBITMQ_PASSWORD
        RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-$EXISTING_RABBITMQ_PASSWORD}

        EXISTING_RABBITMQ_PREFETCH=$(get_env_var "RABBITMQ_PREFETCH" "5")
        read -p "Prefetch (message batch size) [${EXISTING_RABBITMQ_PREFETCH}]: " RABBITMQ_PREFETCH
        RABBITMQ_PREFETCH=${RABBITMQ_PREFETCH:-$EXISTING_RABBITMQ_PREFETCH}
    fi
else
    print_warning "RabbitMQ will be disabled. You can enable it later manually."
fi

set_env_var "ENABLE_RABBITMQ" "$RABBITMQ_ENABLED"

if [ "$RABBITMQ_ENABLED" = "1" ]; then
    set_env_var "RABBITMQ_USER" "$RABBITMQ_USER"
    set_env_var "RABBITMQ_PASSWORD" "$RABBITMQ_PASSWORD"
    set_env_var "RABBITMQ_PREFETCH" "$RABBITMQ_PREFETCH"
    set_env_var "RABBITMQ_DSN" "amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@rabbitmq:5672/%2f"
    print_success "RabbitMQ parameters saved to .env"
fi

# Remove unused backend and instruction folders
print_header "🗂 Cleaning up unused backends/instructions"

# Backends
print_warning "Removing unused backend folders..."
cd backends

for backend_dir in php python node; do
    if [ "$backend_dir" != "$BACKEND" ] && [ -d "$backend_dir" ]; then
        print_warning "Deleting backends/$backend_dir..."

        rm -rf "$backend_dir"
        
        print_success "Removed backends/$backend_dir"
    fi
done

cd ..

# Instruction folders
print_warning "Removing unused instruction folders..."
cd instructions

for instruction_dir in php python node; do
    if [ "$instruction_dir" != "$BACKEND" ] && [ -d "$instruction_dir" ]; then
        print_warning "Deleting instructions/$instruction_dir..."

        rm -rf "$instruction_dir"
        
        print_success "Removed instructions/$instruction_dir"
    fi
done

cd ..

# 3. Extra Django settings
if [ "$BACKEND" = "python" ]; then
    print_header "🐍 Django additional setup"
    
    read -p "Django admin username (default: admin): " DJANGO_USERNAME
    DJANGO_USERNAME=${DJANGO_USERNAME:-admin}
    
    read -p "Django admin email (default: admin@example.com): " DJANGO_EMAIL
    DJANGO_EMAIL=${DJANGO_EMAIL:-admin@example.com}
    
    read -s -p "Django admin password (default: admin123): " DJANGO_PASSWORD
    DJANGO_PASSWORD=${DJANGO_PASSWORD:-admin123}
    echo ""
    
    # Update Django settings inside .env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/DJANGO_SUPERUSER_USERNAME=\"admin\"/DJANGO_SUPERUSER_USERNAME=\"$DJANGO_USERNAME\"/" .env
        sed -i '' "s/DJANGO_SUPERUSER_EMAIL=\"admin@example.com\"/DJANGO_SUPERUSER_EMAIL=\"$DJANGO_EMAIL\"/" .env
        sed -i '' "s/DJANGO_SUPERUSER_PASSWORD=\"password\"/DJANGO_SUPERUSER_PASSWORD=\"$DJANGO_PASSWORD\"/" .env
    else
        # Linux
        sed -i "s/DJANGO_SUPERUSER_USERNAME=\"admin\"/DJANGO_SUPERUSER_USERNAME=\"$DJANGO_USERNAME\"/" .env
        sed -i "s/DJANGO_SUPERUSER_EMAIL=\"admin@example.com\"/DJANGO_SUPERUSER_EMAIL=\"$DJANGO_EMAIL\"/" .env
        sed -i "s/DJANGO_SUPERUSER_PASSWORD=\"password\"/DJANGO_SUPERUSER_PASSWORD=\"$DJANGO_PASSWORD\"/" .env
    fi
    
    print_success "Django settings updated"
fi

# 4. Two-phase container start
print_header "🐳 Two-phase Docker startup"

# Temporary file for docker output
TEMP_OUTPUT="/tmp/docker_output_$$"

# Clean previous containers/networks
print_warning "Cleaning previous containers and networks..."
docker-compose down --remove-orphans --volumes > /dev/null 2>&1 || true
docker container rm -f $(docker container ls -aq --filter "name=b24-ai-starter\|frontend\|ngrok") > /dev/null 2>&1 || true
# Aggressive network cleanup
docker network rm b24-ai-starter_internal-net > /dev/null 2>&1 || true
docker network prune -f > /dev/null 2>&1 || true
docker volume prune -f > /dev/null 2>&1 || true
sleep 5  # give Docker time to finish cleanup

# Remove stuck containers if needed
for stuck_container in frontend ngrokFront; do
    if docker ps -a --format '{{.Names}}' | grep -qx "$stuck_container"; then
        print_warning "Removing stuck container $stuck_container..."
        docker rm -f "$stuck_container" > /dev/null 2>&1 || true
    fi
done

# Phase 1: start Ngrok + minimal frontend to obtain the domain
print_header "🌐 Phase 1: obtaining Ngrok public URL"
echo "Starting Ngrok to get a public domain..."
echo "Important: only frontend + Ngrok are started; the database is not required."

# Start only frontend + Ngrok
if ! COMPOSE_PROFILES=frontend,ngrok docker compose up frontend ngrok --build -d > "$TEMP_OUTPUT" 2>&1; then
    print_error "Failed to start frontend/ngrok containers during phase one."
    if [ -s "$TEMP_OUTPUT" ]; then
        echo ""
        echo "=== docker compose output ==="
        cat "$TEMP_OUTPUT"
        echo "=== end output ==="
    fi
    exit 1
fi

# Wait for Ngrok
print_warning "Waiting for Ngrok to start..."
NGROK_STARTED=false
for i in {1..30}; do
    if docker ps --filter "name=ngrokFront" --format "{{.Names}}" | grep -q ngrokFront; then
        print_success "Ngrok container is running!"
        NGROK_STARTED=true
        break
    fi
    
    if [ $((i % 5)) -eq 0 ]; then
        echo "Attempt $i/30: still waiting for Ngrok..."
    fi
    
    if [ $i -eq 30 ]; then
        print_error "Ngrok did not start within 60 seconds!"
        echo "Docker output:"
        cat "$TEMP_OUTPUT"
        echo -e "\n=== Container status ==="
        docker ps -a
        echo -e "\n=== Ngrok logs (if container exists) ==="
        docker logs ngrokFront 2>/dev/null || echo "ngrokFront container not found"
        echo -e "\n=== Docker networks ==="
        docker network ls
        exit 1
    fi
    
    sleep 2
done

# 5. Obtain Ngrok domain
print_header "🌐 Obtaining Ngrok public URL"

if ! command -v curl >/dev/null 2>&1; then
    print_error "curl is required to query the Ngrok inspect API."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    print_error "python3 is required to parse the Ngrok inspect API response."
    exit 1
fi

print_warning "Polling http://localhost:4040/api/tunnels for the public URL..."

NGROK_DOMAIN=""
NGROK_API_URL=${NGROK_API_URL:-"http://localhost:4040/api/tunnels"}
LAST_RESPONSE=""

for i in {1..30}; do
    RESPONSE=$(curl -s --max-time 5 "$NGROK_API_URL" || true)
    if [ -n "$RESPONSE" ]; then
        LAST_RESPONSE="$RESPONSE"
        NGROK_DOMAIN=$(printf '%s' "$RESPONSE" | parse_ngrok_tunnel)
    fi

    if [ ! -z "$NGROK_DOMAIN" ]; then
        print_success "Ngrok tunnel detected: $NGROK_DOMAIN"
        break
    fi

    if [ $((i % 5)) -eq 0 ]; then
        echo "Attempt $i/30: waiting for Ngrok tunnel..."
    fi

    sleep 2
done

if [ -z "$NGROK_DOMAIN" ]; then
    print_error "Could not detect a public Ngrok URL."
    if [ -n "$LAST_RESPONSE" ]; then
        echo ""
        echo "Last inspect API response:"
        echo "$LAST_RESPONSE" | head -20
        [ "$(printf '%s' "$LAST_RESPONSE" | wc -l)" -gt 20 ] && echo "... (truncated) ..."
    fi
    echo ""
    echo "Tips:"
    echo "  • Ensure the Ngrok authtoken is active."
    echo "  • Check logs: docker logs ngrokFront"
    echo "  • Inspect the inspect API directly: curl $NGROK_API_URL"
    echo "  • Retry: make down && docker rm -f ngrokFront frontend && make dev-init"
    exit 1
fi

# Remove temp file
[ -f "$TEMP_OUTPUT" ] && rm "$TEMP_OUTPUT"

if [ ! -z "$NGROK_DOMAIN" ]; then
    print_success "Ngrok domain found: $NGROK_DOMAIN"
    
    # Update VIRTUAL_HOST with public domain
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|VIRTUAL_HOST='.*'|VIRTUAL_HOST='$NGROK_DOMAIN'|" .env
    else
        # Linux
        sed -i "s|VIRTUAL_HOST='.*'|VIRTUAL_HOST='$NGROK_DOMAIN'|" .env
    fi
    
    print_success "VIRTUAL_HOST updated in .env: $NGROK_DOMAIN"
    
    # Phase 2 — restart services with correct env vars
    print_header "🔄 Phase 2: restart with correct environment"
    print_warning "Stopping containers before relaunching with new domain..."
    make down > /dev/null 2>&1
    
    echo "Starting full stack for backend: $BACKEND"
    case $BACKEND in
        "php")
            echo "Command: make dev-php"
            make dev-php &
            DOCKER_PID=$!
            ;;
        "python")
            echo "Command: make dev-python" 
            make dev-python &
            DOCKER_PID=$!
            ;;
        "node")
            echo "Command: make dev-node"
            make dev-node &
            DOCKER_PID=$!
            ;;
    esac
    
    print_warning "Waiting for all services to come up with the new domain..."
    sleep 20
    
    if docker ps --filter "name=ngrokFront" --format "{{.Names}}" | grep -q ngrokFront && docker ps --filter "name=frontend" --format "{{.Names}}" | grep -q frontend; then
        print_success "All containers restarted with the correct domain!"
        
        if [ "$BACKEND" = "php" ]; then
            print_header "🗄 PHP/database setup"
            
            print_warning "Waiting for PHP container to initialize..."
            sleep 10
            
            print_warning "Cleaning and reinstalling PHP dependencies..."
            docker exec -i $(docker ps | grep api | awk '{print $1}') rm -rf /var/www/vendor /var/www/composer.lock 2>/dev/null || true
            
            if make composer-install 2>&1 | grep -q "Installation failed\|Fatal error\|Error:"; then
                print_warning "Standard install failed, retrying with --ignore-platform-reqs..."
                make composer-install --ignore-platform-reqs 2>/dev/null || true
            fi
            
            if docker exec $(docker ps | grep api | awk '{print $1}') test -f /var/www/vendor/autoload.php 2>/dev/null; then
                print_success "PHP dependencies installed"
                
                print_warning "Initializing database schema..."
                if make dev-php-init-database > /dev/null 2>&1; then
                    print_success "PHP database initialized"
                else
                    print_warning "Database init issues. Run manually: make dev-php-init-database"
                fi
            else
                print_error "Failed to install PHP dependencies"
                print_warning "Run manually:"
                print_warning "  make composer-install"
                print_warning "  make dev-php-init-database"
            fi
        fi
        
    else
        print_warning "Possible restart issues — check container status."
    fi
    
else
    print_warning "Ngrok domain was not detected automatically."
    print_error "Frontend cannot be configured correctly without the domain!"
    
    if docker ps --filter "name=ngrokFront" --format "{{.Names}}" | grep -q ngrokFront; then
        echo "Ngrok container is running but the authtoken might be invalid."
        echo "Check logs: ${YELLOW}docker logs ngrokFront${NC}"
    else
        echo "Ngrok container is not running."
        echo "Check status: ${YELLOW}docker ps -a --filter name=ngrokFront${NC}"
    fi
    echo ""
    echo "How to fix:"
    echo "1. Verify the authtoken in .env"
    echo "2. Restart via ${YELLOW}make down && ./scripts/dev-init.sh${NC}"
    echo "3. Or obtain a domain manually (from \`curl http://localhost:4040/api/tunnels\`) and update VIRTUAL_HOST in .env"
    exit 1
fi

# 6. Final instructions
print_header "🎉 Initialization complete!"

echo -e "${GREEN}🎉 Project initialized via the two-phase flow!${NC}"
echo ""
echo "✅ Completed:"
echo "   - Ngrok domain: ${BLUE}$(grep VIRTUAL_HOST .env | cut -d"'" -f2)${NC}"
echo "   - Environment variables updated"
echo "   - Containers running with the correct domain"
if [ "$RABBITMQ_ENABLED" = "1" ]; then
    RABBITMQ_USER_SUMMARY="${RABBITMQ_USER:-$(get_env_var "RABBITMQ_USER" "queue_user")}"
    RABBITMQ_PASSWORD_SUMMARY="${RABBITMQ_PASSWORD:-$(get_env_var "RABBITMQ_PASSWORD" "queue_password")}"
    RABBITMQ_PREFETCH_SUMMARY="${RABBITMQ_PREFETCH:-$(get_env_var "RABBITMQ_PREFETCH" "5")}"
    echo "   - RabbitMQ enabled (queue profile)"
    echo "   - RabbitMQ credentials: ${BLUE}${RABBITMQ_USER_SUMMARY}:${RABBITMQ_PASSWORD_SUMMARY}${NC} (prefetch ${RABBITMQ_PREFETCH_SUMMARY})"
fi
if [ "$BACKEND" = "php" ]; then
echo "   - PHP database configured"
fi
echo ""
echo "🔗 App URL:"
echo "   ${BLUE}$(grep VIRTUAL_HOST .env | cut -d"'" -f2)${NC}"
echo ""
echo "📝 Next steps:"
echo "1. Create a local Bitrix24 application:"
echo "   - Bitrix24 → Developer Resources → Other → Local Applications"
echo "   - Handler path: $(grep VIRTUAL_HOST .env | cut -d"'" -f2)"
echo "   - Installation path: $(grep VIRTUAL_HOST .env | cut -d"'" -f2)/install"
echo "   - Permissions: crm, user_brief, pull, placement, userfieldconfig"
echo ""
echo "2. After registration, obtain CLIENT_ID and CLIENT_SECRET and update .env"
echo "3. Restart containers to apply the changes: make down && make dev-$BACKEND"
echo ""

if [ "$BACKEND" = "python" ]; then
    echo "Django admin panel:"
    echo "   ${BLUE}\$VIRTUAL_HOST/api/admin${NC}"
    echo "   Username: $DJANGO_USERNAME"
    echo "   Password: [hidden]"
    echo ""
fi

echo "To stop containers:"
echo "   ${YELLOW}make down${NC}"
echo ""
echo "To view logs:"
echo "   ${YELLOW}docker compose logs -f${NC}"
echo ""
print_success "Happy coding! 🚀"