apt install gnupg curl wget
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o https://www.mongodb.org/static/pgp/server-7.0.asc --dearmor ]
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt update
wget https://dl.ui.com/unifi/8.3.32/unifi_sysvinit_all.deb
apt install ./unifi_sysvinit_all.deb
