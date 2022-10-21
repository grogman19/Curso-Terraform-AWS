#!/usr/bin/env bash
set -x
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
export PATH="$PATH:/usr/bin"

# Instalar servidor Web y xfsprogs
sudo dnf install nginx -y
sudo dnf install xfsprogs -y

# Formateamos el volumen atachado como /dev/xvdh
sudo mkfs -t xfs /dev/xvdh

# Montamos el volumen en el document root de nginx
sudo mount /dev/xvdh /usr/share/nginx/html/

# Hacemos el montaje persistente introduciendo el UUID obtenido con lsblk en el fichero /etc/fstab
sudo sh -c 'echo UUID=`lsblk -no UUID /dev/xvdh` /usr/share/nginx/html xfs defaults,nofail 0 2 >> /etc/fstab'

# habilita nginx para que se inicie con la máquina
sudo systemctl enable nginx

# inicia el servidor
sudo systemctl start nginx
