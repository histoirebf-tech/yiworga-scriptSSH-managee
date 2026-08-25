#!/bin/bash
systemctl stop dropbear stunnel4 squid badvpn openvpn@server dnstt 2>/dev/null
systemctl disable dropbear stunnel4 squid badvpn openvpn@server dnstt 2>/dev/null
apt remove --purge -y dropbear stunnel4 squid openvpn easy-rsa golang-go iptables-persistent 2>/dev/null
apt autoremove -y

rm -rf /etc/yiworgabf
rm -rf /etc/openvpn
rm -rf /opt/dnstt
rm -rf /opt/badvpn
rm -f /usr/local/bin/menu
rm -f /usr/local/bin/badvpn-udpgw
rm -f /usr/local/bin/dnstt-server
rm -f /etc/systemd/system/badvpn.service
rm -f /etc/systemd/system/dnstt.service
rm -rf ~/yiworga-scriptSSH-managee

crontab -l 2>/dev/null | grep -v limiter | crontab -

systemctl daemon-reload
echo "Nettoyage termine, VPS repart de zero"
