#!/bin/bash
# Instala Docker, Docker-Compose e o cliente NFS
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose nfs-common

# Adiciona o usuário 'ubuntu' ao grupo do Docker
sudo usermod -aG docker ubuntu

# Monta o EFS
sudo mkdir -p /mnt/efs
echo '${efs_id}.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0' | sudo tee -a /etc/fstab
sudo mount -a

# Prepara a pasta de conteúdo e dá permissão ao servidor web
sudo mkdir -p /mnt/efs/wp-content
sudo chown -R www-data:www-data /mnt/efs/wp-content

# Cria o arquivo de configuração do Docker
cat <<EOF > /home/ubuntu/docker-compose.yaml
version: '3.7'
services:
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: ${db_host}
      WORDPRESS_DB_USER: ${db_user}
      WORDPRESS_DB_PASSWORD: ${db_password}
      WORDPRESS_DB_NAME: ${db_name}
    volumes:
      - /mnt/efs/wp-content:/var/www/html/wp-content
EOF

# Navega para a pasta e inicia o WordPress
cd /home/ubuntu
sudo docker-compose up -d