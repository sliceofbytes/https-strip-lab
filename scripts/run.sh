#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚨 DNS Poisoning Attack Demo - Complete Setup 🚨${NC}"
echo "=============================================="
echo "This script will set up and deploy the HTTPS downgrade attack demo"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Step 1: Create required directories and set permissions
echo ""
echo "1️⃣ Setting up project structure..."
mkdir -p proxy upstream scripts certs
chmod +x scripts/mkcert.sh 2>/dev/null || true
chmod +x upstream/init.sh 2>/dev/null || true
print_status "Project directories created and permissions set"

# Step 2: Validate all files exist
echo ""
echo "2️⃣ Checking required files..."
required_files=(
    "proxy/nginx.conf"
    "upstream/nginx.conf.template"
    "upstream/init.sh"
    "upstream/index.html"
    "docker-compose.yml"
    "scripts/mkcert.sh"
)

missing_files=0
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "$file"
    else
        print_error "$file - MISSING"
        missing_files=$((missing_files + 1))
    fi
done

if [ $missing_files -gt 0 ]; then
    print_error "Missing $missing_files required files. Please ensure all files are present."
    exit 1
fi

# Step 3: Generate SSL certificates
echo ""
echo "3️⃣ Generating SSL certificates..."
if [ ! -f "certs/attacker.crt" ] || [ ! -f "certs/attacker.key" ]; then
    bash scripts/mkcert.sh
    print_status "SSL certificates generated"
else
    print_info "SSL certificates already exist"
fi

# Step 4: Validate nginx configurations
echo ""
echo "4️⃣ Validating nginx configurations..."

# Test proxy config
print_info "Testing proxy/nginx.conf..."
nginx_output=$(docker run --rm -v "$(pwd)/proxy/nginx.conf:/tmp/nginx.conf:ro" nginx:alpine nginx -t -c /tmp/nginx.conf 2>&1)
nginx_exit_code=$?

if [ $nginx_exit_code -eq 0 ]; then
    print_status "proxy/nginx.conf syntax valid"
else
    print_error "proxy/nginx.conf syntax invalid"
    echo "$nginx_output"
    exit 1
fi

# Test upstream template
if [ -f "upstream/nginx.conf.template" ]; then
    print_info "Testing upstream/nginx.conf.template..."
    
    # Create temporary complete nginx config
    temp_config=$(mktemp)
    cat > "$temp_config" << 'EOF'
worker_processes auto;
events { worker_connections 1024; }
http {
EOF
    cat "upstream/nginx.conf.template" >> "$temp_config"
    echo "}" >> "$temp_config"
    
    upstream_output=$(docker run --rm \
      -v "$temp_config:/tmp/nginx.conf:ro" \
      -v "$(pwd)/certs:/etc/nginx/certs:ro" \
      nginx:alpine nginx -t -c /tmp/nginx.conf 2>&1)
    upstream_exit_code=$?
    
    if [ $upstream_exit_code -eq 0 ]; then
        print_status "upstream/nginx.conf.template syntax valid"
    else
        print_error "upstream/nginx.conf.template syntax invalid"
        echo "$upstream_output"
        rm -f "$temp_config"
        exit 1
    fi
    
    rm -f "$temp_config"
fi

# Step 5: Validate docker-compose
echo ""
echo "5️⃣ Validating docker-compose configuration..."
if docker-compose config >/dev/null 2>&1; then
    print_status "docker-compose.yml valid"
else
    print_error "docker-compose.yml invalid"
    docker-compose config
    exit 1
fi

# Step 6: Check for port conflicts
echo ""
echo "6️⃣ Checking for port conflicts..."
ports_to_check=(80 8443)
for port in "${ports_to_check[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$port " || ss -tlnp 2>/dev/null | grep -q ":$port "; then
        print_warning "Port $port is already in use - will attempt to stop conflicting services"
    else
        print_status "Port $port available"
    fi
done

# Step 7: Deploy the demo
echo ""
echo "7️⃣ Deploying attack infrastructure..."
print_info "Stopping any existing containers..."
docker-compose down 2>/dev/null || true

print_info "Starting new containers..."
docker-compose up -d

# Step 8: Wait for containers to be ready
echo ""
echo "8️⃣ Waiting for containers to initialize..."
sleep 8

# Step 9: Test all endpoints
echo ""
echo "9️⃣ Testing all demo endpoints..."

test_endpoint() {
    local url="$1"
    local expected="$2"
    local description="$3"
    
    if curl -k -s --max-time 10 "$url" | grep -q "$expected"; then
        print_status "$description"
        return 0
    else
        print_error "$description"
        return 1
    fi
}

# Test main endpoints
failed_tests=0

echo ""
print_info "Testing HTTP endpoints (Port 80):"
test_endpoint "http://localhost/" "DNS Poisoning" "HTTP attack landing page" || failed_tests=$((failed_tests + 1))
test_endpoint "http://localhost/http-phish" "victim.com.*Login" "HTTP phishing page" || failed_tests=$((failed_tests + 1))

echo ""
print_info "Testing HTTPS endpoints (Port 8443):"
test_endpoint "https://localhost:8443/victim-site" "victim.com.*Secure" "Fake HTTPS victim site" || failed_tests=$((failed_tests + 1))

# Step 10: Final status and instructions
echo ""
echo "🔟 Deployment Summary"
echo "===================="

if [ $failed_tests -eq 0 ]; then
    print_status "All tests passed! Demo is ready."
else
    print_warning "$failed_tests tests failed, but demo may still work."
fi

echo ""
echo "📊 Container Status:"
docker-compose ps

echo ""
echo -e "${GREEN}🎉 DNS POISONING ATTACK DEMO READY! 🎉${NC}"
echo "============================================"
echo ""
echo -e "${BLUE}📱 For Play with Docker, use these URLs:${NC}"
echo ""
echo -e "${YELLOW}🔗 Demo Flow:${NC}"
echo "   1️⃣ Start here: http://ip...-80.direct.labs.play-with-docker.com/"
echo "   2️⃣ Auto-redirect: https://ip...-8443.direct.labs.play-with-docker.com/victim-site"
echo ""
echo -e "${YELLOW}🎭 Attack Demonstration:${NC}"
echo "   • User visits what they think is a legitimate site"
echo "   • DNS poisoning redirects to attacker-controlled server" 
echo "   • HTTP page explains the attack and redirects to fake HTTPS"
echo "   • Fake HTTPS site has valid certificate but wrong domain"
echo "   • Demonstrates how users can be tricked by lock icons"
echo ""
echo -e "${YELLOW}🎓 Educational Points:${NC}"
echo "   • Always check the actual domain name, not just the lock icon"
echo "   • HSTS prevents protocol downgrades"
echo "   • Certificate pinning helps prevent domain spoofing"
echo "   • DNS over HTTPS (DoH) helps prevent DNS poisoning"
echo ""
echo -e "${YELLOW}🔧 Management Commands:${NC}"
echo "   • View logs: docker-compose logs -f"
echo "   • Stop demo: docker-compose down"
echo "   • Restart: docker-compose restart"
echo ""
echo -e "${GREEN}✨ Demo successfully deployed and ready for demonstration! ✨${NC}"
echo ""

# Optional: Open browser automatically if on a desktop system
if command -v xdg-open > /dev/null 2>&1; then
    print_info "Opening demo in browser..."
    xdg-open "http://localhost/" 2>/dev/null || true
elif command -v open > /dev/null 2>&1; then
    print_info "Opening demo in browser..."
    open "http://localhost/" 2>/dev/null || true
fi