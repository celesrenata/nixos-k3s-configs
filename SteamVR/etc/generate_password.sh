#!/usr/bin/env bash
read -p "Enter desired Username: " USERNAME
read -s -p "Enter Password: " CLEAR_PASS
PASSWORD=$(openssl passwd -1 ${CLEAR_PASS})
sed -i 's/USERNAME/'"${USERNAME}"'/g' users.list
sed -i 's/PASSWORD_HASH/'"${PASSWORD}"'/g' users.list
echo "User/Password added to users.list"
