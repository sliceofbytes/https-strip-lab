#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚨 DNS Poisoning Attack Demo - Single Script Setup 🚨${NC}"
echo "================================================================"
echo "This script will create all files and deploy the complete demo"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Step 1: Create project structure
echo ""
echo "1️⃣ Creating project structure..."
mkdir -p proxy upstream scripts certs
print_status "Project directories created"

# Step 2: Create docker-compose.yml
echo ""
echo "2️⃣ Creating docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
services:
  # HTTP Proxy - Handles the downgrade attack
  proxy:
    image: nginx:alpine
    container_name: downgrade_proxy
    ports:
      - "80:80"
    volumes:
      - ./proxy/nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - attack_net

  # Attacker's HTTPS Site - Looks legitimate with valid cert
  attacker_https:
    image: nginx:alpine
    container_name: attacker_https_site
    ports:
      - "8443:8443"
    environment:
      HSTS: "on"
      HSTS_HEADER: "max-age=31536000; includeSubDomains; preload"
    volumes:
      - ./upstream/nginx.conf.template:/etc/nginx/templates/nginx.conf.template:ro
      - ./upstream/index.html:/usr/share/nginx/html/index.html:ro
      - ./certs:/etc/nginx/certs:ro
      - ./upstream/init.sh:/docker-entrypoint.d/10-init-hsts.sh:ro
    healthcheck:
      test: ["CMD", "sh", "-c", "apk add --no-cache curl >/dev/null 2>&1 || true; curl -kfs https://localhost:8443/victim-site"]
      interval: 5s
      timeout: 3s
      retries: 12
    networks:
      attack_net:
        aliases:
          - attacker_https
    restart: unless-stopped

networks:
  attack_net:
EOF
print_status "docker-compose.yml created"

# Step 3: Create proxy nginx configuration
echo ""
echo "3️⃣ Creating proxy nginx configuration..."
cat > proxy/nginx.conf << 'EOF'
worker_processes auto;
events { worker_connections 1024; }

http {
  resolver 127.0.0.11 ipv6=off valid=10s;

  # HTTP Server - Main attack landing page
  server {
    listen 80;
    server_name _;

    # Log the attack for demonstration
    access_log /var/log/nginx/attack.log;

    # Main landing page with auto-redirect
    location / {
      add_header Content-Type "text/html; charset=utf-8" always;
      add_header X-Attack-Vector "DNS-Poisoning-HTTP" always;
      
      return 200 '<!DOCTYPE html>
<html>
<head>
<title>DNS Poisoning Attack Demo</title>
<style>
body { font-family: sans-serif; padding: 20px; background: #fff3cd; }
.warning { background: #f8d7da; padding: 15px; border: 1px solid #f5c6cb; margin: 15px 0; }
.attack { background: #ffe6e6; padding: 15px; border: 1px solid #ff0000; margin: 15px 0; }
.demo { background: #d4edda; padding: 15px; border: 1px solid #28a745; margin: 15px 0; }
.info { background: #d1ecf1; padding: 15px; border: 1px solid #bee5eb; margin: 15px 0; }
.countdown { background: #fff3cd; padding: 15px; border: 2px solid #ffc107; margin: 15px 0; text-align: center; font-size: 18px; }
</style>
</head>
<body>
<h1>DNS Poisoning Attack Demo</h1>

<div class="info">
<h3>Current Status:</h3>
<p>You are currently on: <strong>$scheme://$host$request_uri</strong></p>
<p>This demonstrates what happens when DNS poisoning redirects users to an attacker-controlled server.</p>
</div>

<div class="warning">
<h3>Attack in Progress:</h3>
<p>In a real DNS poisoning attack:</p>
<ul>
<li>User types victim.com (no protocol specified)</li>
<li>DNS poisoning points to attacker IP (this server)</li>
<li>User lands on attacker HTTP site instead of real site</li>
<li>All data is now vulnerable to interception</li>
</ul>
</div>

<div class="attack">
<h3>What Attackers Can Do:</h3>
<ul>
<li>Intercept all your data in plaintext</li>
<li>Steal credentials directly on this HTTP page</li>
<li>Redirect to a fake secure site with their own certificate</li>
<li>Inject malicious content into pages</li>
</ul>
</div>

<div class="countdown">
<h3>Automatic Redirect in Progress</h3>
<p>The attacker is now redirecting you to their secure HTTPS site...</p>
<p><strong>Redirecting in <span id="countdown">5</span> seconds</strong></p>
<p><a href="/redirect-to-fake-https">Click here to go immediately</a></p>
</div>

<div class="demo">
<h3>Manual Demo Options:</h3>
<p><a href="/http-phish" style="padding: 10px 15px; background: #dc3545; color: white; text-decoration: none; margin: 5px;">HTTP Credential Theft</a></p>
<p><a href="/redirect-to-fake-https" style="padding: 10px 15px; background: #007cba; color: white; text-decoration: none; margin: 5px;">Go to Fake HTTPS Site</a></p>
</div>

<script>
var seconds = 5;
var countdownElement = document.getElementById("countdown");

var timer = setInterval(function() {
  seconds--;
  countdownElement.textContent = seconds;
  
  if (seconds <= 0) {
    clearInterval(timer);
    
    // Smart redirect: replace -80 with -8443 in the URL
    var currentHost = window.location.hostname;
    var httpsHost = currentHost.replace("-80.", "-8443.");
    var httpsUrl = "https://" + httpsHost + "/victim-site";
    
    window.location.href = httpsUrl;
  }
}, 1000);
</script>

</body>
</html>';
    }

    # HTTP credential harvesting
    location = /http-phish {
      add_header Content-Type "text/html; charset=utf-8" always;
      return 200 '<!DOCTYPE html>
<html>
<head>
<title>victim.com - Login</title>
<style>
body { font-family: sans-serif; padding: 20px; background: #f8f9fa; }
.form-container { background: white; padding: 20px; border: 1px solid #ddd; max-width: 400px; margin: 20px auto; }
input { padding: 10px; width: 100%; margin: 10px 0; border: 1px solid #ddd; }
button { padding: 12px 20px; background: #007cba; color: white; border: none; width: 100%; }
.warning { background: #fff3cd; padding: 10px; margin: 10px 0; border: 1px solid #ffeaa7; }
</style>
</head>
<body>
<h1>victim.com - User Login</h1>

<div class="warning">
<h3>Security Notice:</h3>
<p>This connection is <strong>NOT SECURE</strong> (HTTP). Your data will be transmitted in plaintext!</p>
</div>

<div class="form-container">
<h3>Login to Your Account</h3>
<form method="get" action="/steal-http-creds">
<input type="text" name="username" placeholder="Username" required>
<input type="password" name="password" placeholder="Password" required>
<button type="submit">Login</button>
</form>
</div>

<p style="text-align: center;"><small>Many users ignore security warnings and login anyway!</small></p>
</body>
</html>';
    }

    # Show stolen HTTP credentials
    location = /steal-http-creds {
      add_header Content-Type "text/html; charset=utf-8" always;
      return 200 '<!DOCTYPE html>
<html>
<head>
<title>HTTP Attack Successful!</title>
<style>body{font-family:sans-serif;padding:20px;background:#ffcccc;}</style>
</head>
<body>
<h2>HTTP Attack Successful!</h2>
<p><strong>Captured via unencrypted HTTP:</strong></p>
<ul>
<li>Username: <code>$arg_username</code></li>
<li>Password: <code>$arg_password</code></li>
<li>Method: Plaintext interception</li>
<li>Source: $remote_addr</li>
</ul>
<p>This happened because you were on HTTP instead of HTTPS!</p>
<p><a href="/redirect-to-fake-https">Now see the HTTPS version</a></p>
</body>
</html>';
    }

    # Smart redirect that constructs the correct Play with Docker HTTPS URL
    location = /redirect-to-fake-https {
      add_header Content-Type "text/html; charset=utf-8" always;
      return 200 '<!DOCTYPE html>
<html>
<head>
<title>Redirecting to Secure Site</title>
<script>
// Smart redirect for Play with Docker URLs
var currentHost = window.location.hostname;
var httpsHost = currentHost.replace("-80.", "-8443.");
var httpsUrl = "https://" + httpsHost + "/victim-site";

// Immediate redirect
window.location.href = httpsUrl;
</script>
</head>
<body>
<p>Redirecting to secure site...</p>
</body>
</html>';
    }
  }
}
EOF
print_status "proxy/nginx.conf created"

# Step 4: Create upstream nginx template
echo ""
echo "4️⃣ Creating upstream nginx template..."
cat > upstream/nginx.conf.template << 'EOF'
server {
  listen 8443 ssl;
  server_name _;

  ssl_certificate /etc/nginx/certs/attacker.crt;
  ssl_certificate_key /etc/nginx/certs/attacker.key;
  ssl_protocols TLSv1.2 TLSv1.3;

  # Attacker site looks legitimate with proper security headers
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
  add_header X-Frame-Options "DENY" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-Attacker-Site "true" always;

  root /usr/share/nginx/html;
  index index.html;

  # Fake victim site that looks legitimate
  location /victim-site {
    add_header Content-Type "text/html; charset=utf-8" always;
    return 200 '<!DOCTYPE html>
<html><head><title>Secure Login - victim.com</title>
<style>
  body { font-family: sans-serif; padding: 20px; background: #f8f9fa; }
  .secure { background: #d4edda; padding: 15px; border: 1px solid #28a745; margin: 15px 0; }
  .form-container { background: white; padding: 20px; border: 1px solid #ddd; max-width: 400px; }
  input { padding: 10px; width: 100%; margin: 10px 0; border: 1px solid #ddd; }
  button { padding: 12px 20px; background: #28a745; color: white; border: none; width: 100%; }
</style>
</head>
<body>
<h1>victim.com - Secure Portal</h1>

<div class="secure">
<h3>Secure Connection Established</h3>
<p><strong>This site appears secure because:</strong></p>
<ul>
<li>Valid HTTPS certificate</li>
<li>Legitimate-looking domain</li>
<li>Security headers present</li>
<li>Green lock icon in browser</li>
</ul>
</div>

<div class="form-container">
<h3>Login to Your Account</h3>
<form method="get" action="/steal-secure-creds">
<input type="text" name="username" placeholder="Username" required>
<input type="password" name="password" placeholder="Password" required>
<button type="submit">Secure Login</button>
</form>
</div>

<div style="background: #fff3cd; padding: 10px; margin: 15px 0; border: 1px solid #ffeaa7;">
<h4>Attack Analysis:</h4>
<p><strong>Why this attack works:</strong></p>
<ul>
<li>User typed https://victim.com but DNS was poisoned</li>
<li>Browser fell back to HTTP, then got redirected here</li>
<li>This HTTPS site has a valid certificate (for attacker domain)</li>
<li>Users see the lock icon and trust it</li>
<li>Domain confusion: users dont always check the URL carefully</li>
</ul>
</div>

<p><small>Notice: Check the certificate details and domain name!</small></p>
</body></html>';
  }

  # Handle credential theft on the secure site
  location = /steal-secure-creds {
    add_header Content-Type "text/html; charset=utf-8" always;
    return 200 '<!DOCTYPE html>
<html><head><title>Advanced Attack Successful!</title>
<style>body{font-family:sans-serif;padding:20px;background:#ffe6e6;}</style>
</head>
<body>
<h2>Advanced HTTPS Attack Successful!</h2>

<div style="background: #f8d7da; padding: 15px; border: 1px solid #f5c6cb; margin: 15px 0;">
<h3>Credentials Captured via Secure HTTPS:</h3>
<ul>
<li><strong>Username:</strong> <code>$arg_username</code></li>
<li><strong>Password:</strong> <code>$arg_password</code></li>
<li><strong>Attack Method:</strong> HTTPS with valid certificate</li>
<li><strong>Domain:</strong> $host (not victim.com!)</li>
<li><strong>User IP:</strong> $remote_addr</li>
</ul>
</div>

<div style="background: #fff3cd; padding: 15px; border: 1px solid #ffeaa7; margin: 15px 0;">
<h3>Why This Attack Succeeded:</h3>
<ol>
<li><strong>DNS Poisoning:</strong> victim.com pointed to attacker IP</li>
<li><strong>Protocol Downgrade:</strong> HTTPS to HTTP to HTTPS redirect</li>
<li><strong>Valid Certificate:</strong> HTTPS site has legitimate SSL cert</li>
<li><strong>User Trust:</strong> Lock icon made it look secure</li>
<li><strong>Domain Confusion:</strong> Users did not verify the actual domain</li>
</ol>
</div>

<h3>How to Protect Against This:</h3>
<ul>
<li>Always verify the domain name in the address bar</li>
<li>Check certificate details (click the lock icon)</li>
<li>Use HSTS to prevent protocol downgrades</li>
<li>Use DNS over HTTPS (DoH) to prevent DNS poisoning</li>
<li>Be suspicious of unexpected redirects</li>
</ul>

<p><a href="/victim-site">Back to fake login</a></p>
</body></html>';
  }

  # Default page
  location / {
    return 302 /victim-site;
  }
}
EOF
print_status "upstream/nginx.conf.template created"

# Step 5: Create upstream init script
echo ""
echo "5️⃣ Creating upstream init script..."
cat > upstream/init.sh << 'EOF'
#!/bin/sh

if [ "$HSTS" = "on" ]; then
    export HSTS_HEADER="max-age=31536000; includeSubDomains; preload"
else
    export HSTS_HEADER=""
fi

echo "HSTS setting: $HSTS"
echo "HSTS_HEADER: '$HSTS_HEADER'"
EOF
chmod +x upstream/init.sh
print_status "upstream/init.sh created and made executable"

# Step 6: Create upstream index.html
echo ""
echo "6️⃣ Creating upstream index.html..."
cat > upstream/index.html << 'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>DNS Poisoning Attack Demo</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; line-height: 1.6; }
    .attack { background: #ffe6e6; padding: 1rem; border: 2px solid #ff0000; }
    .legitimate { background: #e6ffe6; padding: 1rem; border: 2px solid #00aa00; }
    .warning { background: #fff3cd; padding: 1rem; border: 2px solid #ffcc00; }
  </style>
</head>
<body>
  <h1>DNS Poisoning Attack Demo</h1>

  <div class="warning">
    <h2>Demo Purpose</h2>
    <p>This demonstrates how DNS poisoning can downgrade HTTPS to HTTP, enabling man-in-the-middle attacks.</p>
  </div>

  <div class="attack">
    <h2>Attack Scenario</h2>
    <p><strong>Current page:</strong> <span id="currentUrl"></span></p>
    <p><strong>Protocol:</strong> <span id="protocol"></span></p>
    <p><strong>Security:</strong> <span id="security"></span></p>
  </div>

  <h2>Demo Links</h2>
  <ul>
    <li><a href="/phish">Fake Login Page (HTTP)</a></li>
    <li><a href="/legitimate">Compare with Legitimate Site (HTTPS)</a></li>
  </ul>

  <script>
    // Show current page details
    document.getElementById('currentUrl').textContent = window.location.href;
    document.getElementById('protocol').textContent = window.location.protocol;

    const isSecure = window.location.protocol === 'https:';
    document.getElementById('security').textContent = isSecure ?
      'Encrypted (Safe)' :
      'Unencrypted (Vulnerable to attacks!)';

    // Change styling based on security
    if (!isSecure) {
      document.body.style.backgroundColor = '#ffe6e6';
    }
  </script>
</body>
</html>
EOF
print_status "upstream/index.html created"

# Step 7: Create certificate generation script
echo ""
echo "7️⃣ Creating certificate generation script..."
cat > scripts/mkcert.sh << 'EOF'
#!/bin/bash

set -e

echo "Generating SSL certificate for HTTPS downgrade attack demo"
echo "============================================================="

mkdir -p certs

if [ ! -f "certs/attacker.crt" ]; then
    echo "Generating attacker's certificate..."
    echo "This simulates an attacker who has a valid certificate for their domain"

    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -subj "/CN=*.direct.labs.play-with-docker.com/O=Attacker Corp/C=US/ST=California/L=San Francisco" \
      -keyout certs/attacker.key \
      -out certs/attacker.crt

    echo "Success: Attacker certificate generated"
else
    echo "Success: Attacker certificate already exists"
fi

echo ""
echo "Certificate Details:"
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
EOF
chmod +x scripts/mkcert.sh
print_status "scripts/mkcert.sh created and made executable"

# Step 8: Generate SSL certificates
echo ""
echo "8️⃣ Generating SSL certificates..."
bash scripts/mkcert.sh
print_status "SSL certificates generated"

# Step 9: Validate configurations
echo ""
echo "9️⃣ Validating nginx configurations..."

# Test proxy config
print_info "Testing proxy/nginx.conf..."
nginx_output=$(docker run --rm -v "$(pwd)/proxy/nginx.conf:/tmp/nginx.conf:ro" nginx:alpine nginx -t -c /tmp/nginx.conf 2>&1)
nginx_exit_code=$?

if [ $nginx_exit_code -eq 0 ]; then
    print_status "proxy/nginx.conf syntax valid"
else
    print_error "proxy/nginx.conf syntax invalid"
    echo "$nginx_output"
    exit 1
fi

# Test upstream template
print_info "Testing upstream/nginx.conf.template..."
temp_config=$(mktemp)
cat > "$temp_config" << 'EOF'
worker_processes auto;
events { worker_connections 1024; }
http {
EOF
cat "upstream/nginx.conf.template" >> "$temp_config"
echo "}" >> "$temp_config"

upstream_output=$(docker run --rm \
  -v "$temp_config:/tmp/nginx.conf:ro" \
  -v "$(pwd)/certs:/etc/nginx/certs:ro" \
  nginx:alpine nginx -t -c /tmp/nginx.conf 2>&1)
upstream_exit_code=$?

if [ $upstream_exit_code -eq 0 ]; then
    print_status "upstream/nginx.conf.template syntax valid"
else
    print_error "upstream/nginx.conf.template syntax invalid"
    echo "$upstream_output"
    rm -f "$temp_config"
    exit 1
fi

rm -f "$temp_config"

# Step 10: Validate docker-compose
echo ""
echo "🔟 Validating docker-compose configuration..."
if docker-compose config >/dev/null 2>&1; then
    print_status "docker-compose.yml valid"
else
    print_error "docker-compose.yml invalid"
    docker-compose config
    exit 1
fi

# Step 11: Deploy the demo
echo ""
echo "1️⃣1️⃣ Deploying attack infrastructure..."
print_info "Stopping any existing containers..."
docker-compose down 2>/dev/null || true

print_info "Starting new containers..."
docker-compose up -d

# Step 12: Wait for containers to be ready
echo ""
echo "1️⃣2️⃣ Waiting for containers to initialize..."
sleep 8

# Step 13: Test all endpoints
echo ""
echo "1️⃣3️⃣ Testing all demo endpoints..."

test_endpoint() {
    local url="$1"
    local expected="$2"
    local description="$3"
    
    if curl -k -s --max-time 10 "$url" | grep -q "$expected"; then
        print_status "$description"
        return 0
    else
        print_error "$description"
        return 1
    fi
}

failed_tests=0

print_info "Testing HTTP endpoints (Port 80):"
test_endpoint "http://localhost/" "DNS Poisoning" "HTTP attack landing page" || failed_tests=$((failed_tests + 1))
test_endpoint "http://localhost/http-phish" "victim.com.*Login" "HTTP phishing page" || failed_tests=$((failed_tests + 1))

print_info "Testing HTTPS endpoints (Port 8443):"
test_endpoint "https://localhost:8443/victim-site" "victim.com.*Secure" "Fake HTTPS victim site" || failed_tests=$((failed_tests + 1))

# Final status and instructions
echo ""
echo "1️⃣4️⃣ Deployment Summary"
echo "======================"

if [ $failed_tests -eq 0 ]; then
    print_status "All tests passed! Demo is ready."
else
    print_warning "$failed_tests tests failed, but demo may still work."
fi

echo ""
echo "📊 Container Status:"
docker-compose ps

echo ""
echo -e "${GREEN}🎉 DNS POISONING ATTACK DEMO READY! 🎉${NC}"
echo "============================================"
echo ""
echo -e "${BLUE}📱 For Play with Docker, use these URLs:${NC}"
echo ""
echo -e "${YELLOW}🔗 Demo Flow:${NC}"
echo "   1️⃣ Start here: http://ip...-80.direct.labs.play-with-docker.com/"
echo "   2️⃣ Auto-redirect: https://ip...-8443.direct.labs.play-with-docker.com/victim-site"
echo ""
echo -e "${YELLOW}🎭 Attack Demonstration:${NC}"
echo "   • User visits what they think is a legitimate site"
echo "   • DNS poisoning redirects to attacker-controlled server" 
echo "   • HTTP page explains the attack and redirects to fake HTTPS"
echo "   • Fake HTTPS site has valid certificate but wrong domain"
echo "   • Demonstrates how users can be tricked by lock icons"
echo ""
echo -e "${YELLOW}🎓 Educational Points:${NC}"
echo "   • Always check the actual domain name, not just the lock icon"
echo "   • HSTS prevents protocol downgrades"
echo "   • Certificate pinning helps prevent domain spoofing"
echo "   • DNS over HTTPS (DoH) helps prevent DNS poisoning"
echo ""
echo -e "${YELLOW}🔧 Management Commands:${NC}"
echo "   • View logs: docker-compose logs -f"
echo "   • Stop demo: docker-compose down"
echo "   • Restart: docker-compose restart"
echo ""
echo -e "${GREEN}✨ Demo successfully deployed and ready for demonstration! ✨${NC}"
echo ""

# Optional: Open browser automatically if on a desktop system
if command -v xdg-open > /dev/null 2>&1; then
    print_info "Opening demo in browser..."
    xdg-open "http://localhost/" 2>/dev/null || true
elif command -v open > /dev/null 2>&1; then
    print_info "Opening demo in browser..."
    open "http://localhost/" 2>/dev/null || true
fi

print_status "Setup complete! All files created and demo deployed."