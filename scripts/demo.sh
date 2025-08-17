#!/bin/bash

set -e

echo "  HTTPS Downgrade Attack Demo  "
echo "================================="
echo "Simulates DNS poisoning + HTTPS downgrade + Fake HTTPS redirect"

# Setup
mkdir -p proxy upstream scripts certs
chmod +x scripts/mkcert.sh upstream/init.sh 2>/dev/null || true

# Generate certificates
echo ""
echo "1. Generating attacker's SSL certificate..."
bash scripts/mkcert.sh

# Start containers
echo ""
echo "2.Starting attack infrastructure..."
docker-compose down 2>/dev/null || true
docker-compose up -d

# Wait for startup
echo ""
echo "3. Waiting for containers to initialize..."
sleep 5

# Test endpoints
echo ""
echo "4. Testing attack chain..."

echo -n "Testing HTTP downgrade page... "
if curl -s --max-time 5 "http://localhost/" | grep -q "HTTPS Downgrade"; then
    echo "Success"
else
    echo "Fail"
fi

echo -n "Testing fake HTTPS site... "
if curl -k -s --max-time 5 "https://localhost:8443/victim-site" | grep -q "victim.com"; then
    echo "Success"
else
    echo "Fail"
fi

echo ""
echo "  REALISTIC ATTACK DEMO READY!"
echo "==============================="
echo ""
echo "  For Play with Docker:"
echo ""
echo "  Attack Flow URLs:"
echo "   Step 1: https://ip...-80.direct.labs.play-with-docker.com/secure"
echo "           ↳ User types HTTPS but gets HTTP (no 443 service)"
echo ""
echo "   Step 2: http://ip...-80.direct.labs.play-with-docker.com/"
echo "           ↳ Shows downgrade attack page"
echo ""
echo "   Step 3: https://ip...-8443.direct.labs.play-with-docker.com/victim-site"
echo "           ↳ Fake HTTPS site with 'valid' certificate"
echo ""
echo "  Attack Demonstration:"
echo "   1. User expects secure HTTPS connection"
echo "   2. DNS poisoning + no HTTPS service = HTTP fallback"
echo "   3. HTTP page redirects to attacker's legitimate HTTPS site"
echo "   4. Users trust the lock icon and enter credentials"
echo "   5. Attacker has valid HTTPS cert but wrong domain"
echo ""
echo "  Key Learning:"
echo "   • Always check the actual domain name, not just the lock icon"
echo "   • HSTS prevents protocol downgrades"
echo "   • Certificate pinning helps prevent domain spoofing"
echo ""
echo "  Test the attack:"
echo "   1. Try to visit: https://ip...-80.direct.labs.play-with-docker.com/secure"
echo "   2. Notice browser falls back to HTTP"
echo "   3. Follow redirect to fake HTTPS site"
echo "   4. Check certificate details vs domain name"

echo ""
echo "  Container Status:"
docker-compose ps

echo ""
echo "  Ready for demonstration!"