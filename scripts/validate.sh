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
if docker run --rm -v "$(pwd)/proxy/nginx.conf:/tmp/nginx.conf:ro" nginx:alpine nginx -t -c /tmp/nginx.conf 2>/dev/null; then
    echo "✅ proxy/nginx.conf syntax valid"
else
    echo "❌ proxy/nginx.conf syntax invalid"
    errors=$((errors + 1))
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