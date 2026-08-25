#!/bin/bash
systemctl stop dropbear stunnel4 squid badvpn dnstt openvpn@server 2>/dev/null
systemctl disable dropbear stunnel4 squid badvpn dnstt openvpn@server 2>/dev/null

apt remove --purge -y dropbear stunnel4 squid openvpn easy-rsa iptables-persistent 2>/dev/null
apt autoremove -y

rm -rf /etc/yiworgabf
rm -rf /etc/openvpn
rm -rf /etc/stunnel
rm -rf /etc/squid
rm -rf /opt/dnstt
rm -rf /opt/badvpn
rm -f /usr/local/bin/badvpn-udpgw
rm -f /usr/local/bin/dnstt-server
rm -f /usr/local/bin/menu
rm -f /etc/systemd/system/badvpn.service
rm -f /etc/systemd/system/dnstt.service
rm -rf ~/yiworga-scriptSSH-managee

sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf
iptables -t nat -F 2>/dev/null

systemctl daemon-reload

echo "Tout a ete supprime, le VPS est propre"
