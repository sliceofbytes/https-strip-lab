#!/bin/bash

echo "=== Testing HTTPS Strip Demo Setup ==="

# Test upstream directly
echo "1. Testing upstream HTTPS directly..."
echo "Testing /secure endpoint:"
curl -k -v https://localhost:8443/secure 2>&1 | grep -E "(HTTP|SSL|TLS|> GET|< HTTP)"

echo ""
echo "2. Testing upstream container internally..."
docker-compose exec upstream curl -k -s https://localhost/secure && echo "✓ Internal HTTPS working"

echo ""
echo "3. Testing proxy HTTP..."
echo "Testing /secure via proxy:"
curl -v http://localhost/secure 2>&1 | grep -E "(HTTP|> GET|< HTTP|Connection)"

echo ""
echo "4. Testing proxy with insecure endpoint..."
curl -v http://localhost/insecure 2>&1 | grep -E "(HTTP|> GET|< HTTP)"

echo ""
echo "5. Checking container logs..."
echo "=== Upstream logs ==="
docker-compose logs upstream | tail -5

echo "=== Proxy logs ==="
docker-compose logs proxy | tail -5

echo ""
echo "6. Testing direct container networking..."
docker-compose exec proxy curl -k -s https://upstream:443/secure && echo "✓ Proxy->Upstream connection working"