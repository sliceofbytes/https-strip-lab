#!/bin/sh

# Set HSTS_HEADER based on HSTS environment variable
if [ "$HSTS" = "on" ]; then
    export HSTS_HEADER="max-age=31536000; includeSubDomains; preload"
else
    export HSTS_HEADER=""
fi

echo "HSTS setting: $HSTS"
echo "HSTS_HEADER: '$HSTS_HEADER'"