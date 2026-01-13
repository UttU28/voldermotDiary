#!/bin/bash

# Voldermot Diary Backend Deployment Script
echo "🚀 Starting Voldermot Diary Backend deployment..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if PM2 is installed
if ! command -v pm2 &> /dev/null; then
    print_error "PM2 is not installed. Please install PM2 first:"
    echo "npm install -g pm2"
    exit 1
fi

# Navigate to backend directory
cd "$(dirname "$0")" || exit

# Stop and remove existing instance
print_header "🧹 Cleaning up existing service..."
print_status "Stopping and removing existing voldermot-diary-backend process..."
pm2 delete voldermot-diary-backend 2>/dev/null || print_status "voldermot-diary-backend not running"
print_status "Cleanup completed"

# Install Dependencies
print_header "📦 Installing Dependencies..."
if [ -f "package.json" ]; then
    print_status "Installing npm packages..."
    npm install
    if [ $? -ne 0 ]; then
        print_error "Failed to install dependencies"
        exit 1
    fi
    print_status "Dependencies installed successfully"
else
    print_error "package.json not found"
    exit 1
fi

# Setup environment
print_header "🔧 Setting up environment..."
if [ ! -f ".env" ]; then
    print_status "Creating .env file..."
    cat > .env << EOF
NODE_ENV=production
PORT=3012
DOMAIN=voldermotDiary.thatinsaneguy.com
EOF
    print_status ".env file created"
else
    print_status ".env file already exists"
    # Update PORT if it's not 3012
    if ! grep -q "PORT=3012" .env; then
        print_status "Updating PORT to 3012 in .env..."
        if grep -q "^PORT=" .env; then
            sed -i 's/^PORT=.*/PORT=3012/' .env
        else
            echo "PORT=3012" >> .env
        fi
    fi
    # Update DOMAIN if not set
    if ! grep -q "DOMAIN=" .env; then
        echo "DOMAIN=voldermotDiary.thatinsaneguy.com" >> .env
    fi
fi

# Start Backend
print_header "🚀 Starting Backend..."
if [ -f "server.js" ]; then
    pm2 start server.js --name voldermot-diary-backend
    if [ $? -eq 0 ]; then
        print_status "Backend started successfully on port 3012"
    else
        print_error "Failed to start backend"
        exit 1
    fi
else
    print_error "server.js not found"
    exit 1
fi

# Save PM2 configuration
print_status "Saving PM2 configuration..."
pm2 save

# Setup PM2 to start on boot (silently)
pm2 startup > /dev/null 2>&1 || true

# Show PM2 status
print_header "📊 Application Status:"
pm2 status

# Setup Nginx (if nginx is installed and running as root/sudo)
print_header "🌐 Setting up Nginx..."
if command -v nginx &> /dev/null; then
    if [ "$EUID" -eq 0 ] || [ -n "$SUDO_USER" ]; then
        NGINX_CONF="/etc/nginx/sites-available/voldermotDiary.thatinsaneguy.com"
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        ROOT_DIR="$(dirname "$SCRIPT_DIR")"
        
        if [ -f "$ROOT_DIR/nginx-voldermotdiary.conf" ]; then
            print_status "Copying nginx configuration..."
            cp "$ROOT_DIR/nginx-voldermotdiary.conf" "$NGINX_CONF"
            
            # Enable site
            ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/ 2>/dev/null || true
            
            # Test nginx config
            if nginx -t 2>/dev/null; then
                systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
                print_status "✅ Nginx configuration updated and reloaded"
            else
                print_error "Nginx configuration test failed. Please check manually."
            fi
        else
            print_warning "nginx-voldermotdiary.conf not found in $ROOT_DIR"
            print_status "You can manually copy the nginx config from the project root"
        fi
    else
        print_status "Not running as root. Skipping nginx setup."
        print_status "To set up nginx, run with sudo or manually:"
        echo "  sudo cp ../nginx-voldermotdiary.conf /etc/nginx/sites-available/voldermotDiary.thatinsaneguy.com"
        echo "  sudo ln -s /etc/nginx/sites-available/voldermotDiary.thatinsaneguy.com /etc/nginx/sites-enabled/"
        echo "  sudo nginx -t"
        echo "  sudo systemctl reload nginx"
    fi
else
    print_status "Nginx not found. Skipping nginx setup."
    print_status "Install nginx to serve on subdomain: sudo apt install nginx"
fi

print_header "✅ Deployment Complete!"
print_status "Backend: http://localhost:3012"
if command -v nginx &> /dev/null && [ -f "/etc/nginx/sites-enabled/voldermotDiary.thatinsaneguy.com" ]; then
    print_status "Subdomain: http://voldermotDiary.thatinsaneguy.com"
    print_status ""
    print_status "🔒 To enable HTTPS, run:"
    echo "   sudo certbot --nginx -d voldermotDiary.thatinsaneguy.com"
fi
print_status ""
print_status "Useful commands:"
echo "  pm2 status                        - View application status"
echo "  pm2 logs voldermot-diary-backend  - View application logs"
echo "  pm2 stop voldermot-diary-backend  - Stop the application"
echo "  pm2 restart voldermot-diary-backend - Restart the application"
