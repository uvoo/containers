rm /etc/resolv.conf
cat > /etc/resolv.conf << EOL
nameserver 127.0.0.53
options edns0 trust-ad
search extendhealth.com ehdmz.com" > /etc/resolv.conf
EOL
