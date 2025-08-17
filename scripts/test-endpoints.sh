#!/bin/bash

echo "🧪 Testing All Demo Endpoints"
echo "============================="

base_url="localhost"
failed=0

test_endpoint() {
    local url="$1"
    local expected="$2"
    local description="$3"
    
    echo -n "Testing $description... "
    
    if curl -k -s --max-time 10 "$url" | grep -q "$expected"; then
        echo "✅"
    else
        echo "❌"
        failed=$((failed + 1))
    fi
}

echo ""
echo "🔗 HTTP Endpoints (Port 80):"
test_endpoint "http://$base_url/" "DNS Poisoning" "DNS poisoning landing page"
test_endpoint "http://$base_url/phish" "Login to victim.local" "HTTP phishing page"
test_endpoint "http://$base_url/steal-creds?username=test&password=test" "Attack Successful" "Credential theft simulation"

echo ""
echo "🔒 Fake HTTPS Endpoints (Port 8443):"
test_endpoint "https://$base_url:8443/fake-victim" "Secure.*victim.local" "Fake HTTPS victim site"
test_endpoint "https://$base_url:8443/steal-https-creds?username=test&password=test" "HTTPS Attack Successful" "HTTPS credential theft"

echo ""
echo "🛡️ Legitimate HTTPS Endpoints (Port 9443):"
test_endpoint "https://$base_url:9443/secure" "REAL victim.local" "Legitimate secure content"
test_endpoint "https://$base_url:9443/login" "Secure Login" "Legitimate login page"

echo ""
if [ $failed -eq 0 ]; then
    echo "🎉 All endpoints working correctly!"
    echo ""
    echo "📱 Play with Docker URLs ready:"
    echo "   HTTP:  http://ip...-80.direct.labs.play-with-docker.com/"
    echo "   Fake:  https://ip...-8443.direct.labs.play-with-docker.com/"
    echo "   Real:  https://ip...-9443.direct.labs.play-with-docker.com/"
else
    echo "💥 $failed endpoints failed!"
    echo "Check the docker-compose logs for details"
    exit 1
fi