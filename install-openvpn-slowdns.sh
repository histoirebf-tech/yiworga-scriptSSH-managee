#!/bin/bash
set -e

NS_DOMAIN="ns.tondomaine.com"
OVPN_PORT=1194

apt update -y
apt install -y openvpn easy-rsa golang-go iptables-persistent

mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa --batch build-ca nopass
./easyrsa --batch build-server-full server nopass
./easyrsa --batch build-client-full client nopass
./easyrsa gen-dh
openvpn --genkey secret /etc/openvpn/ta.key

cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem /etc/openvpn/

cat > /etc/openvpn/server.conf <<EOF
port $OVPN_PORT
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
cipher AES-256-GCM
auth SHA256
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
persist-key
persist-tun
status /var/log/openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "$IFACE" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$IFACE" -j MASQUERADE
netfilter-persistent save

systemctl enable openvpn@server
systemctl restart openvpn@server

git clone https://www.bamsoftware.com/git/dnstt.git /opt/dnstt
cd /opt/dnstt/dnstt-server
go build
cp dnstt-server /usr/local/bin/dnstt-server

mkdir -p /etc/yiworgabf
/usr/local/bin/dnstt-server -gen-key -privkey-file /etc/yiworgabf/dnstt.key -pubkey-file /etc/yiworgabf/dnstt.pub

cat > /etc/systemd/system/dnstt.service <<EOF
[Unit]
Description=DNSTT SlowDNS
After=network.target openvpn@server.service

[Service]
ExecStart=/usr/local/bin/dnstt-server -udp :53 -privkey-file /etc/yiworgabf/dnstt.key $NS_DOMAIN 127.0.0.1:$OVPN_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dnstt
systemctl restart dnstt

echo "OpenVPN installe sur port $OVPN_PORT udp"
echo "SlowDNS installe, domaine configure: $NS_DOMAIN"
echo "Cle publique SlowDNS:"
cat /etc/yiworgabf/dnstt.pub
echo "Cree un enregistrement NS pour $NS_DOMAIN pointant vers ce VPS (via un A record + delegation NS chez ton registrar)"
