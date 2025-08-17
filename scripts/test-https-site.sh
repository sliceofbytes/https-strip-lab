#!/bin/bash

echo "🔍 Testing HTTPS Site on Port 8443"
echo "=================================="

echo "1️⃣ Testing HTTPS site directly:"
curl -k -s https://localhost:8443/victim-site | head -20

echo ""
echo "2️⃣ Testing certificate:"
openssl s_client -connect localhost:8443 -servername localhost < /dev/null 2>/dev/null | openssl x509 -text -noout | grep -E "(Subject:|Issuer:|Not After)"

echo ""
echo "3️⃣ Testing redirect from HTTP site:"
curl -I http://localhost/redirect-to-fake-https 2>/dev/null | grep -E "(HTTP|Location)"

echo ""
echo "4️⃣ Full URL test:"
echo "The correct HTTPS URL should be:"
echo "https://ip172-18-0-26-d2gve78l2o90009m0lo0-8443.direct.labs.play-with-docker.com/victim-site"

echo ""
echo "5️⃣ Container status:"
docker-compose ps attacker_https