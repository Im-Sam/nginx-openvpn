#!/bin/bash

# Variables
DOMAIN="example.com"
EMAIL="your_email@example.com"
WEB_ROOT="/var/www/html"

# Update package index
sudo apt update

# Install Nginx
sudo apt install nginx -y

# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Allow Nginx through the firewall
sudo ufw allow 'Nginx Full'

# Obtain SSL certificate
sudo certbot --nginx -d $DOMAIN -m $EMAIL --agree-tos --no-eff-email

# Create basic HTML page
sudo mkdir -p $WEB_ROOT
sudo chown -R $USER:$USER $WEB_ROOT
echo "<html><head><title>Welcome to $DOMAIN</title></head><body><h1>Success! $DOMAIN is now running with a Let's Encrypt SSL certificate.</h1></body></html>" | sudo tee $WEB_ROOT/index.html

# Configure Nginx to serve the webpage
sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
sudo bash -c 'cat > /etc/nginx/sites-available/default' << EOF
server {
    listen 80;
    listen [::]:80;

    server_name $DOMAIN www.$DOMAIN;

    location / {
        root $WEB_ROOT;
        index index.html index.htm;
    }

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

EOF

# Restart Nginx to apply changes
sudo systemctl restart nginx
