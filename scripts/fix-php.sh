#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

echo "🔧 Fixing PHP backend issues"
echo "======================================"

# Stop containers
print_warning "Stopping all containers..."
docker-compose down 2>/dev/null || true

# Remove problematic files
print_warning "Cleaning vendor/ and composer.lock..."
rm -rf backends/php/vendor backends/php/composer.lock

print_success "Dependencies wiped"

# Relaunch PHP containers
print_warning "Starting PHP containers with fresh dependencies..."
make dev-php

print_success "Done! PHP containers should be up and running"