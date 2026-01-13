# Deployment Guide for Voldermot Diary Backend

This guide explains how to deploy the backend to `doldermotDiary.thatinsaneguy.com` with HTTPS support.

## Prerequisites

1. **Server Access**: SSH access to the server hosting `doldermotDiary.thatinsaneguy.com`
2. **Node.js**: Node.js 16+ installed on the server
3. **Nginx**: Installed and configured (for reverse proxy)
4. **SSL Certificates**: Let's Encrypt certificates for the domain
5. **Sudo Access**: Required for systemd service management

## Step 1: Setup SSL Certificates

If you don't have SSL certificates yet, install Certbot and obtain certificates:

```bash
sudo apt-get update
sudo apt-get install certbot python3-certbot-nginx

# Get certificates for your domain
sudo certbot certonly --nginx -d doldermotDiary.thatinsaneguy.com
```

Certificates will be stored at:
- Certificate: `/etc/letsencrypt/live/doldermotDiary.thatinsaneguy.com/fullchain.pem`
- Private Key: `/etc/letsencrypt/live/doldermotDiary.thatinsaneguy.com/privkey.pem`

## Step 2: Deploy the Backend

1. **Upload the backend files** to your server (via SCP, Git, or FTP):
   ```bash
   scp -r backend/ user@doldermotDiary.thatinsaneguy.com:/var/www/voldermot-diary-backend/
   ```

2. **SSH into your server**:
   ```bash
   ssh user@doldermotDiary.thatinsaneguy.com
   ```

3. **Navigate to the backend directory**:
   ```bash
   cd /var/www/voldermot-diary-backend
   ```

4. **Run the deployment script**:
   ```bash
   sudo bash deploy.sh
   ```

The script will:
- Install dependencies
- Create a systemd service
- Setup Nginx reverse proxy
- Start the backend service

## Step 3: Verify Deployment

1. **Check service status**:
   ```bash
   sudo systemctl status voldermot-diary-backend
   ```

2. **View logs**:
   ```bash
   sudo journalctl -u voldermot-diary-backend -f
   ```

3. **Test the health endpoint**:
   ```bash
   curl https://doldermotDiary.thatinsaneguy.com/health
   ```

## Step 4: Update Flutter App

The Flutter app is already configured to use the production URL:
- Production: `https://doldermotDiary.thatinsaneguy.com`
- Local Development: `http://10.0.0.65:3000` (when `USE_LOCAL_SERVER=true`)

To use local server for development, run:
```bash
flutter run --dart-define=USE_LOCAL_SERVER=true
```

## Manual Deployment (Alternative)

If you prefer to deploy manually:

1. **Install dependencies**:
   ```bash
   npm install --production
   ```

2. **Create .env file**:
   ```bash
   cat > .env << EOF
   NODE_ENV=production
   PORT=3000
   DOMAIN=doldermotDiary.thatinsaneguy.com
   SSL_CERT_PATH=/etc/letsencrypt/live/doldermotDiary.thatinsaneguy.com/fullchain.pem
   SSL_KEY_PATH=/etc/letsencrypt/live/doldermotDiary.thatinsaneguy.com/privkey.pem
   EOF
   ```

3. **Create systemd service** (see deploy.sh for the service file content)

4. **Setup Nginx** (see deploy.sh for the Nginx configuration)

5. **Start the service**:
   ```bash
   sudo systemctl enable voldermot-diary-backend
   sudo systemctl start voldermot-diary-backend
   ```

## Troubleshooting

### Service won't start
- Check logs: `sudo journalctl -u voldermot-diary-backend -n 50`
- Verify Node.js is installed: `node --version`
- Check file permissions: `ls -la /var/www/voldermot-diary-backend`

### SSL Certificate Issues
- Verify certificates exist: `ls -la /etc/letsencrypt/live/doldermotDiary.thatinsaneguy.com/`
- Check certificate expiry: `sudo certbot certificates`
- Renew if needed: `sudo certbot renew`

### Nginx Issues
- Test configuration: `sudo nginx -t`
- Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
- Reload Nginx: `sudo systemctl reload nginx`

### Port Already in Use
- Check what's using port 3000: `sudo lsof -i :3000`
- Kill the process or change PORT in .env

## Maintenance

### Restart Service
```bash
sudo systemctl restart voldermot-diary-backend
```

### View Real-time Logs
```bash
sudo journalctl -u voldermot-diary-backend -f
```

### Update Backend
1. Pull latest changes
2. Run `npm install --production`
3. Restart service: `sudo systemctl restart voldermot-diary-backend`

### Renew SSL Certificates
Certbot automatically renews certificates, but you can manually renew:
```bash
sudo certbot renew
sudo systemctl reload nginx
```

## Security Notes

- The backend runs on port 3000 (internal) and is proxied through Nginx on port 443 (HTTPS)
- Ensure firewall only allows ports 80 and 443 from outside
- Keep Node.js and dependencies updated
- Regularly check logs for suspicious activity
