#!/bin/bash

set -e

echo "Generating SSL certificate for HTTPS downgrade attack demo"
echo "============================================================="

mkdir -p certs

# Generate attacker's certificate that could match Play with Docker domain
# In a real attack, this would be a valid certificate for the attacker's domain
if [ ! -f "certs/attacker.crt" ]; then
    echo "Generating attacker's certificate..."
    echo "This simulates an attacker who has a valid certificate for their domain"
    
    # Create certificate that looks legitimate
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -subj "/CN=*.direct.labs.play-with-docker.com/O=Attacker Corp/C=US/ST=California/L=San Francisco" \
      -keyout certs/attacker.key \
      -out certs/attacker.crt
    
    echo "Success: Attacker certificate generated"
else
    echo "Success: Attacker certificate already exists"
fi

echo ""
echo "  Certificate Details:"
openssl x509 -in certs/attacker.crt -text -noout | grep -E "(Subject:|Issuer:|Not After)"

echo ""
echo "Files created:"
ls -la certs/

echo ""
echo "Success: Certificate setup complete!"
echo ""
echo "Attack Flow:"
echo "1. User types: https://example...direct.labs.play-with-docker.com/secure"
echo "2. DNS poisoning points to your server"
echo "3. No HTTPS service on port 443 → Browser falls back to HTTP (port 80)"
echo "4. HTTP site redirects to fake HTTPS site (port 8443)"
echo "5. Fake HTTPS site has 'valid' certificate and steals credentials"