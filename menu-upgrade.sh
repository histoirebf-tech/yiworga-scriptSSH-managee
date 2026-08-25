#!/bin/bash
set -e
apt update -y
apt install -y vnstat speedtest-cli bc curl
systemctl enable --now vnstat
wget -O /usr/local/bin/menu https://raw.githubusercontent.com/histoirebf-tech/yiworga-scriptSSH-managee/main/menu
chmod +x /usr/local/bin/menu
echo "Menu mis a jour, tape: menu"
