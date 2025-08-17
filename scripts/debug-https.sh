#!/bin/bash

echo "🔍 Debugging HTTPS Fallback Issue"
echo "================================="

# Check what's actually listening on ports
echo "1️⃣ Checking what's listening on ports:"
netstat -tlnp 2>/dev/null | grep -E ":(80|443|8443)" || ss -tlnp | grep -E ":(80|443|8443)"

echo ""
echo "2️⃣ Testing HTTP access directly:"
curl -v http://localhost/ 2>&1 | head -20

echo ""
echo "3️⃣ Testing HTTPS access (should fail):"
curl -v https://localhost/ 2>&1 | head -20

echo ""
echo "4️⃣ Docker container port mappings:"
docker-compose ps

echo ""
echo "5️⃣ Testing the actual Play with Docker URLs:"
echo "Try these in your browser:"
echo "HTTP:  http://ip172-18-0-26-d2gve78l2o90009m0lo0-80.direct.labs.play-with-docker.com/"
echo "HTTPS: https://ip172-18-0-26-d2gve78l2o90009m0lo0-80.direct.labs.play-with-docker.com/"

echo ""
echo "6️⃣ Check if Play with Docker has automatic HTTPS redirect:"
curl -I -v http://ip172-18-0-26-d2gve78l2o90009m0lo0-80.direct.labs.play-with-docker.com/ 2>&1 | grep -E "(Location|Redirect|HTTP)"