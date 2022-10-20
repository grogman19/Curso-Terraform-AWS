#!/usr/bin/env bash
set -x
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
export PATH="$PATH:/usr/bin"
# Instalar servidor Web
sudo dnf install nginx -y
# habilita nginx
sudo systemctl enable nginx
# inicia el servidor
sudo systemctl start nginx