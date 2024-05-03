#!/bin/bash

# Variables
DOMAIN="example.com"
EMAIL="your_email@example.com"
CLIENT_NAME="client"

# Update package index
sudo apt update

# Install OpenVPN
sudo apt install openvpn easy-rsa -y

# Create the CA directory
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

# Initialize the PKI
source vars
./clean-all
./build-ca

# Generate the server key and certificate
./build-key-server server

# Generate Diffie-Hellman parameters
./build-dh
openvpn --genkey --secret keys/ta.key

# Generate a client key and certificate
cd ~/openvpn-ca
source vars
./build-key $CLIENT_NAME

# Move keys and certs to OpenVPN directory
sudo cp ~/openvpn-ca/keys/{ca.crt,ca.key,server.crt,server.key,ta.key,dh.pem} /etc/openvpn

# Create OpenVPN server configuration
sudo bash -c 'cat > /etc/openvpn/server.conf' << EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

# Enable IP forwarding
sudo sed -i 's/#net.ipv4.ip_forward/net.ipv4.ip_forward/' /etc/sysctl.conf
sudo sysctl -p

# Enable NAT
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE

# Save the iptables rules
sudo iptables-save > /etc/iptables/rules.v4

# Install Certbot for Let's Encrypt
sudo apt install certbot python3-certbot-nginx -y

# Obtain SSL certificate for OpenVPN
sudo certbot certonly --standalone --preferred-challenges http -d $DOMAIN -m $EMAIL --agree-tos --no-eff-email

# Configure Nginx to serve Let's Encrypt certificate
sudo bash -c 'cat > /etc/nginx/sites-available/openvpn' << EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:1194;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Enable the OpenVPN server
sudo systemctl enable openvpn@server
sudo systemctl start openvpn@server

# Restart Nginx to apply changes
sudo systemctl restart nginx
