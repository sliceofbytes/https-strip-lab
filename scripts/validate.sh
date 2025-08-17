#!/bin/bash

echo "🔍 Pre-Deployment Validation"
echo "============================"

errors=0

# Check required files exist
required_files=(
    "proxy/nginx.conf"
    "upstream/nginx.conf.template"
    "upstream/init.sh"
    "upstream/index.html"
    "docker-compose.yml"
    "scripts/mkcert.sh"
)

echo "1️⃣ Checking required files..."
for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
        errors=$((errors + 1))
    fi
done

# Validate nginx config syntax
echo ""
echo "2️⃣ Validating nginx configuration..."

# First, check if certificates exist, if not, generate them
if [ ! -f "certs/attacker.crt" ] || [ ! -f "certs/attacker.key" ]; then
    echo "   Certificates not found, generating them for validation..."
    if [ -f "scripts/mkcert.sh" ]; then
        bash scripts/mkcert.sh > /dev/null 2>&1
    else
        echo "   Creating temporary self-signed certificates for validation..."
        mkdir -p certs
        openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
          -subj "/CN=temp" \
          -keyout certs/attacker.key \
          -out certs/attacker.crt > /dev/null 2>&1
    fi
fi

echo "Testing proxy/nginx.conf..."
# Capture both stdout and stderr
nginx_output=$(docker run --rm -v "$(pwd)/proxy/nginx.conf:/tmp/nginx.conf:ro" nginx:alpine nginx -t -c /tmp/nginx.conf 2>&1)
nginx_exit_code=$?

if [ $nginx_exit_code -eq 0 ]; then
    echo "✅ proxy/nginx.conf syntax valid"
    echo "   $nginx_output"
else
    echo "❌ proxy/nginx.conf syntax invalid"
    echo "   Error details:"
    echo "$nginx_output" | sed 's/^/   /'
    errors=$((errors + 1))
fi

# Test the upstream template by wrapping it in a complete nginx config
if [ -f "upstream/nginx.conf.template" ]; then
    echo ""
    echo "Testing upstream/nginx.conf.template..."
    
    # Create a temporary complete nginx config with the template content
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
        echo "✅ upstream/nginx.conf.template syntax valid"
    else
        echo "❌ upstream/nginx.conf.template syntax invalid"
        echo "   Error details:"
        echo "$upstream_output" | sed 's/^/   /'
        errors=$((errors + 1))
    fi
    
    # Clean up temp file
    rm -f "$temp_config"
fi

# Check docker-compose syntax  
echo ""
echo "3️⃣ Validating docker-compose..."
if docker-compose config >/dev/null 2>&1; then
    echo "✅ docker-compose.yml valid"
else
    echo "❌ docker-compose.yml invalid"
    errors=$((errors + 1))
fi

# Check port conflicts
echo ""
echo "4️⃣ Checking for port conflicts..."
ports_to_check=(80 8443 9443)
for port in "${ports_to_check[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo "⚠️  Port $port is already in use"
    else
        echo "✅ Port $port available"
    fi
done

# Validate script permissions
echo ""
echo "5️⃣ Checking script permissions..."
scripts=("scripts/mkcert.sh" "upstream/init.sh")
for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo "✅ $script is executable"
    else
        echo "⚠️  $script not executable (will be fixed during setup)"
    fi
done

echo ""
if [ $errors -eq 0 ]; then
    echo "🎉 VALIDATION PASSED - Ready for deployment!"
    echo ""
    echo "Run: ./demo.sh"
else
    echo "💥 VALIDATION FAILED - $errors errors found"
    echo "Fix the issues above before deployment"
    exit 1
fi