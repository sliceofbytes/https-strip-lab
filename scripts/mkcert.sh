#!/usr/bin/env bash
ls -l certs/victim.local.crt certs/victim.local.key
# if missing, (re)create:
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
  -subj "/CN=victim.local" \
  -keyout certs/victim.local.key -out certs/victim.local.crt
