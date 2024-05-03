#!/bin/bash

# Enable SSH (port 22)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Enable HTTP (port 80)
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Enable HTTPS (port 443)
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Save the iptables rules
sudo iptables-save > /etc/iptables/rules.v4
