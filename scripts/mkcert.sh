#!/bin/bash

set -e

echo "=== Generating SSL certificates for DNS poisoning demo ==="

mkdir -p certs

# Generate legitimate victim.local certificate
if [ ! -f "certs/victim.local.crt" ]; then
    echo "1️⃣ Generating legitimate victim.local certificate..."
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -subj "/CN=victim.local/O=Victim Company Inc/C=US/ST=California/L=San Francisco" \
      -keyout certs/victim.local.key \
      -out certs/victim.local.crt
    echo "✅ victim.local certificate created"
else
    echo "✅ victim.local certificate already exists"
fi

# Generate attacker's certificate (different domain)
if [ ! -f "certs/attacker.local.crt" ]; then
    echo "2️⃣ Generating attacker.local certificate..."
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -subj "/CN=attacker.local/O=Malicious Corp/C=US/ST=Nevada/L=Las Vegas" \
      -keyout certs/attacker.local.key \
      -out certs/attacker.local.crt
    echo "✅ attacker.local certificate created"
else
    echo "✅ attacker.local certificate already exists"
fi

echo ""
echo "📋 Certificate Summary:"
echo "========================"
echo "Legitimate site certificate:"
openssl x509 -in certs/victim.local.crt -subject -noout
echo ""
echo "Attacker site certificate:"
openssl x509 -in certs/attacker.local.crt -subject -noout

echo ""
echo "📁 Files created:"
ls -la certs/

echo ""
echo "✅ Certificate generation complete!"