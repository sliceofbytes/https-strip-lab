#!/bin/bash

# Create certs directory if it doesn't exist
mkdir -p certs

# Check if certificates already exist
if [ -f "certs/victim.local.crt" ] && [ -f "certs/victim.local.key" ]; then
    echo "Certificates already exist:"
    ls -l certs/victim.local.crt certs/victim.local.key
    exit 0
fi

echo "Generating SSL certificates..."

# Generate self-signed certificate
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -subj "/CN=victim.local" \
  -keyout certs/victim.local.key -out certs/victim.local.crt

echo "Certificates generated:"
ls -l certs/victim.local.crt certs/victim.local.key