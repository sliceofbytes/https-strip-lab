#!/bin/bash

echo "=== HTTPS Strip Demo Lab Setup ==="

# Make scripts executable
chmod +x scripts/mkcert.sh
chmod +x upstream/init.sh

# Generate certificates
echo "1. Generating SSL certificates..."
bash scripts/mkcert.sh

# Start containers
echo "2. Starting containers..."
docker-compose down 2>/dev/null
docker-compose up -d

# Wait for health check
echo "3. Waiting for containers to be healthy..."
sleep 5

# Test the setup
echo "4. Testing the setup..."
echo ""
echo "Testing HTTPS upstream directly:"
curl -k -s https://localhost:8443/secure 2>/dev/null && echo "✓ HTTPS upstream working" || echo "✗ HTTPS upstream failed"

echo ""
echo "Testing HTTP proxy:"
curl -s http://localhost/secure 2>/dev/null && echo "✓ HTTP proxy working" || echo "✗ HTTP proxy failed"

echo ""
echo "=== Demo Ready ==="
echo "• Open http://localhost in your browser"
echo "• The proxy strips HTTPS and removes HSTS headers"
echo "• Toggle HSTS with: docker-compose exec upstream sh -c 'export HSTS=on && /docker-entrypoint.d/10-init-hsts.sh'"
echo ""
echo "View logs with: docker-compose logs -f"