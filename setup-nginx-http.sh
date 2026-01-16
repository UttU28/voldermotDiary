#!/bin/bash

# Setup Nginx for HTTP only (voldermotDiary.thatinsaneguy.com)
# Run this to set up HTTP, then you can add HTTPS later with certbot

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run with sudo: sudo ./setup-nginx-http.sh"
    exit 1
fi

DOMAIN="voldermotDiary.thatinsaneguy.com"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"
PROJECT_DIR="/home/uttu28/Desktop/voldermotDiary"

echo "🌐 Setting up Nginx for HTTP (${DOMAIN})..."

# Copy nginx config
echo "📋 Copying nginx configuration..."
cp "${PROJECT_DIR}/nginx-voldermotdiary.conf" "${NGINX_CONF}"
echo "✅ Nginx config copied to ${NGINX_CONF}"

# Enable site
echo "📋 Enabling nginx site..."
ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/
echo "✅ Site enabled"

# Test nginx config
echo "📋 Testing nginx configuration..."
if nginx -t; then
    echo "✅ Nginx configuration is valid"
else
    echo "❌ Nginx configuration test failed"
    exit 1
fi

# Reload nginx
echo "📋 Reloading nginx..."
systemctl reload nginx
echo "✅ Nginx reloaded"

echo ""
echo "🎉 HTTP Setup Complete!"
echo "✅ Your site is now accessible at:"
echo "   - HTTP:  http://${DOMAIN}"
echo ""
echo "🔒 To enable HTTPS, run this command:"
echo "   sudo certbot --nginx -d ${DOMAIN} --keep-until-expiring"
echo ""
echo "   Note: This will reuse existing certificates if they exist and are valid."
echo "         Only requests a new certificate if none exists or current one is expired."
