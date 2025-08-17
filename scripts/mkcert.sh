#!/usr/bin/env bash
set -euo pipefail
mkdir -p certs
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -subj "/CN=victim.local" \
  -keyout certs/victim.local.key \
  -out    certs/victim.local.crt
