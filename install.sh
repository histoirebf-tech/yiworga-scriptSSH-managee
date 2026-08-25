#!/bin/bash
set -e

SSH_PORT=22
DROPBEAR_PORT=443
STUNNEL_PORT=444
BADVPN_PORT=7300
SQUID_PORT=8080

apt update -y
apt install -y dropbear stunnel4 squid openssl build-essential cmake git screen cron ufw

sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i "s/DROPBEAR_PORT=.*/DROPBEAR_PORT=$DROPBEAR_PORT/" /etc/default/dropbear
sed -i 's/DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS=""/' /etc/default/dropbear
systemctl enable dropbear
systemctl restart dropbear

mkdir -p /etc/stunnel
openssl req -new -x509 -days 3650 -nodes \
  -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem \
  -subj "/C=BF/ST=BF/L=Ouagadougou/O=YiworgaBF/CN=yiworgabf.net"
chmod 600 /etc/stunnel/stunnel.pem

cat > /etc/stunnel/stunnel.conf <<EOF
pid = /var/run/stunnel4.pid
cert = /etc/stunnel/stunnel.pem
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept = $STUNNEL_PORT
connect = 127.0.0.1:$DROPBEAR_PORT

[openssh]
accept = 445
connect = 127.0.0.1:$SSH_PORT
EOF

sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
systemctl enable stunnel4
systemctl restart stunnel4

cat > /etc/squid/squid.conf <<EOF
acl SSH_ports port $SSH_PORT $DROPBEAR_PORT
acl CONNECT method CONNECT
http_access allow CONNECT SSH_ports
http_access allow all
http_port $SQUID_PORT
dns_v4_first on
via off
forwarded_for delete
EOF

systemctl enable squid
systemctl restart squid

cd /opt
rm -rf badvpn
git clone https://github.com/ambrop72/badvpn.git
mkdir -p badvpn/build
cd badvpn/build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make
cp udpgw/badvpn-udpgw /usr/local/bin/badvpn-udpgw
chmod +x /usr/local/bin/badvpn-udpgw

cat > /etc/systemd/system/badvpn.service <<EOF
[Unit]
Description=BadVPN UDPGW
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:$BADVPN_PORT --max-clients 1000 --max-connections-for-client 10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable badvpn
systemctl restart badvpn

ufw allow $SSH_PORT/tcp
ufw allow $DROPBEAR_PORT/tcp
ufw allow $STUNNEL_PORT/tcp
ufw allow 445/tcp
ufw allow $SQUID_PORT/tcp

mkdir -p /etc/yiworgabf
touch /etc/yiworgabf/users.db

cat > /usr/local/bin/menu <<'MENUEOF'
#!/bin/bash
DB=/etc/yiworgabf/users.db

criar_user() {
  read -p "Nom utilisateur: " user
  read -p "Mot de passe: " pass
  read -p "Jours de validite: " dias
  exp=$(date -d "+$dias days" +%Y-%m-%d)
  useradd -e "$exp" -M -s /bin/false "$user"
  echo -e "$pass\n$pass" | passwd "$user"
  echo "$user $exp" >> $DB
  echo "Utilisateur $user cree, expire le $exp"
}

del_user() {
  read -p "Nom utilisateur a supprimer: " user
  userdel "$user"
  sed -i "/^$user /d" $DB
  echo "Utilisateur $user supprime"
}

list_users() {
  column -t $DB
}

case "$1" in
  criar) criar_user ;;
  del) del_user ;;
  list) list_users ;;
  *) echo "Usage: menu {criar|del|list}" ;;
esac
MENUEOF

chmod +x /usr/local/bin/menu

echo "Installation terminee"
echo "SSH: $SSH_PORT | Dropbear: $DROPBEAR_PORT | Stunnel(dropbear): $STUNNEL_PORT | Stunnel(ssh): 445 | Squid: $SQUID_PORT | Badvpn: $BADVPN_PORT"
echo "Gestion utilisateurs: menu criar / menu del / menu list"
