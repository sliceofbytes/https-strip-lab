#!/bin/bash

set -e

echo "🚨 Complete DNS Poisoning Attack Demo 🚨"
echo "=========================================="

# Setup
chmod +x scripts/mkcert.sh upstream/init.sh

# Generate certificates
echo "1️⃣ Generating SSL certificates..."
bash scripts/mkcert.sh

# Start containers
echo ""
echo "2️⃣ Starting attack infrastructure..."
docker-compose down 2>/dev/null || true
docker-compose up -d

# Wait for startup
echo ""
echo "3️⃣ Waiting for containers to initialize..."
sleep 5

# Test all endpoints
echo ""
echo "4️⃣ Testing all attack vectors..."

echo "Testing HTTP DNS poisoning..."
if curl -s http://localhost/ | grep -q "DNS Poisoning"; then
    echo "✅ HTTP attack site working"
else
    echo "❌ HTTP attack site failed"
fi

echo "Testing attacker HTTPS site..."
if curl -k -s https://localhost:8443/fake-victim | grep -q "Secure"; then
    echo "✅ Fake HTTPS site working"
else
    echo "❌ Fake HTTPS site failed"
fi

echo "Testing legitimate site..."
if curl -k -s https://localhost:9443/secure | grep -q "REAL victim.local"; then
    echo "✅ Legitimate site working"
else
    echo "❌ Legitimate site failed"
fi

echo ""
echo "🎯 COMPLETE ATTACK DEMO READY!"
echo "==============================="
echo ""
echo "📱 For Play with Docker, use these URLs:"
echo ""
echo "🔗 Attack Flow:"
echo "   1️⃣ DNS Poisoning (HTTP):     http://ip...-80.direct.labs.play-with-docker.com/"
echo "   2️⃣ Fake HTTPS Site:          https://ip...-8443.direct.labs.play-with-docker.com/"
echo "   3️⃣ Legitimate Site:          https://ip...-9443.direct.labs.play-with-docker.com/"
echo ""
echo "🎭 Attack Scenarios:"
echo "   • HTTP Credential Harvesting:  /phish"
echo "   • HTTPS Certificate Spoofing:  /fake-victim"
echo "   • Legitimate Site Comparison:  /secure"
echo ""
echo "💡 Demo Flow:"
echo "   1. Start at HTTP site (DNS poisoning)"
echo "   2. Try HTTP phishing attack"
echo "   3. Move to fake HTTPS site (certificate spoofing)"
echo "   4. Compare with real legitimate site"
echo "   5. Notice the certificate differences!"
echo ""
echo "🔍 Key Learning Points:"
echo "   • DNS poisoning can downgrade HTTPS to HTTP"
echo "   • Attackers can serve fake HTTPS sites with wrong certificates"
echo "   • Users often ignore certificate warnings"
echo "   • HSTS helps prevent protocol downgrade attacks"
echo "   • Always verify certificate domain matches URL"

echo ""
echo "📊 Container Status:"
docker-compose ps

echo ""
echo "🚀 Demo is ready! Open the URLs above to start the attack simulation."