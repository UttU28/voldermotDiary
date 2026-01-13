#!/bin/bash

# Voldermot Diary Backend Deployment Script
# Deploys to voldermotDiary.thatinsaneguy.com

echo "🚀 Starting deployment to voldermotDiary.thatinsaneguy.com..."

# Set domain
DOMAIN="voldermotDiary.thatinsaneguy.com"
APP_DIR="/var/www/voldermot-diary-backend"
SERVICE_NAME="voldermot-diary-backend"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Please run with sudo for systemd service management"
    exit 1
fi

# Navigate to backend directory
cd "$(dirname "$0")" || exit

echo "📦 Installing dependencies..."
npm install --production

echo "🔧 Setting up environment..."
# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    cat > .env << EOF
NODE_ENV=production
PORT=3000
DOMAIN=$DOMAIN
SSL_CERT_PATH=/etc/letsencrypt/live/$DOMAIN/fullchain.pem
SSL_KEY_PATH=/etc/letsencrypt/live/$DOMAIN/privkey.pem
EOF
    echo "✅ Created .env file"
fi

# Copy files to deployment directory
echo "📁 Copying files to $APP_DIR..."
mkdir -p "$APP_DIR"
cp -r . "$APP_DIR/" 2>/dev/null || {
    echo "⚠️  Could not copy to $APP_DIR, continuing with local directory..."
    APP_DIR="$(pwd)"
}

# Create systemd service file
echo "⚙️  Creating systemd service..."
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=Voldermot Diary Backend Server
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=DOMAIN=$DOMAIN
ExecStart=/usr/bin/node $APP_DIR/server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable and start service
echo "🔄 Starting service..."
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

# Check service status
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "✅ Service is running!"
    echo "📊 Service status:"
    systemctl status $SERVICE_NAME --no-pager -l
else
    echo "❌ Service failed to start. Check logs with: journalctl -u $SERVICE_NAME -f"
    exit 1
fi

# Setup Nginx reverse proxy (if nginx is installed)
if command -v nginx &> /dev/null; then
    echo "🌐 Setting up Nginx reverse proxy..."
    cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # WebSocket support
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    
    # Test nginx config
    if nginx -t; then
        systemctl reload nginx
        echo "✅ Nginx configuration updated"
    else
        echo "⚠️  Nginx configuration test failed. Please check manually."
    fi
else
    echo "ℹ️  Nginx not found. Skipping reverse proxy setup."
    echo "💡 Install Nginx and SSL certificates (Let's Encrypt) for HTTPS support"
fi

echo ""
echo "🎉 Deployment complete!"
echo "🌐 Backend should be accessible at: https://$DOMAIN"
echo "📝 To view logs: journalctl -u $SERVICE_NAME -f"
echo "🔄 To restart: sudo systemctl restart $SERVICE_NAME"
