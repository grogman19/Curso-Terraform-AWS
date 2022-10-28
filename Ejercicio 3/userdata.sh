#!/usr/bin/env bash
set -x
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
export PATH="$PATH:/usr/bin"

# Configurar SFTP (usuario con acceso exclusivo a una única carpeta)
sudo adduser sftp-user
echo test-12345 | sudo passwd sftp-user --stdin
sudo mkdir -p /var/sftp/uploads
sudo chown root:root /var/sftp
sudo chmod 755 /var/sftp
sudo chown sftp-user:sftp-user /var/sftp/uploads
sudo sh -c 'cat <<EOT >> /etc/ssh/sshd_config
Match User sftp-user
ForceCommand internal-sftp
PasswordAuthentication yes
ChrootDirectory /var/sftp
PermitTunnel no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
EOT
'

# Reiniciamos el servicio sshd para aplicar los cambios
sudo systemctl restart sshd

# Formateamos el volumen atachado como /dev/xvdh
sudo mkfs -t xfs /dev/xvdh

# Montamos el volumen en la carpeta de SFTP
sudo mount /dev/xvdh /var/sftp/uploads/

# Hacemos el montaje persistente introduciendo el UUID obtenido con lsblk en el fichero /etc/fstab
sudo sh -c 'echo UUID=`lsblk -no UUID /dev/xvdh` /var/sftp/uploads xfs defaults,nofail 0 2 >> /etc/fstab'
