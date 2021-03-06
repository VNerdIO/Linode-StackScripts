#!/bin/bash 
##  
# <UDF name="ssuser" Label="New user" example="username" />
# <UDF name="sspassword" Label="New user password" example="Password" />
# <UDF name="hostname" Label="Hostname" example="examplehost" />
# <UDF name="website" Label="Website" example="example.com" />
# <UDF name="db_password" Label="MySQL root Password" />
# <UDF name="dbuser" Label="MySQL Username" />
# <UDF name="dbuser_password" Label="MySQL User Password" />

# add sudo user
adduser $SSUSER --disabled-password --gecos "" && \
echo "$SSUSER:$SSPASSWORD" | chpasswd
adduser $SSUSER sudo

# Firewall
ufw allow ssh
ufw allow http
ufw allow https
ufw enable

# updates
apt update -y
apt upgrade -y
apt autoremove -y

#SET HOSTNAME
hostnamectl set-hostname $HOSTNAME
echo "127.0.0.1   $HOSTNAME" >> /etc/hosts

#INSTALL
apt install nginx mysql-server php php-pear php-mysql php-gd php-fpm -y

# Make public_html & logs
mkdir -p /var/www/html/$WEBSITE/{public_html,logs,src}

# Remove default apache page
rm /var/www/html/*.html

# Install wordpress
cd /var/www/html/$WEBSITE/src/
sudo chown -R www-data:www-data /var/www/html/$WEBSITE/
sudo wget http://wordpress.org/latest.tar.gz
sudo -u www-data tar -xvf latest.tar.gz
sudo mv latest.tar.gz wordpress-`date "+%Y-%m-%d"`.tar.gz
sudo mv wordpress/* ../public_html/
sudo chown -R www-data:www-data /var/www/html/$WEBSITE/public_html

# Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
echo "mysql-server mysql-server/root_password password $DB_PASSWORD" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $DB_PASSWORD" | sudo debconf-set-selections

mysql -uroot -p$DB_PASSWORD -e "create database wordpress"
mysql -uroot -p$DB_PASSWORD -e "CREATE USER '$DBUSER' IDENTIFIED BY '$DBUSER_PASSWORD';
"
mysql -uroot -p$DB_PASSWORD -e "GRANT ALL PRIVILEGES ON wordpress.* TO '$DBUSER';"

service mysql restart

# Add nginx site
cat <<END >/etc/nginx/sites-available/$WEBSITE.conf
server {
    listen 80;
    server_name $WEBSITE;

    include snippets/letsencrypt.conf;
    return 301 https://$WEBSITE$request_uri;
}

# Redirect WWW -> NON WWW
server {
    listen 443 ssl http2;
    server_name $WEBSITE;

    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
    include snippets/ssl.conf;

    return 301 https://example.com$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $WEBSITE;

    root /var/www/html/$WEBSITE/public_html;
    index index.php;

    # SSL parameters
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/example.com/chain.pem;
    include snippets/ssl.conf;
    include snippets/letsencrypt.conf;

    # log files
    access_log /var/log/nginx/$WEBSITE.access.log;
    error_log /var/log/nginx/$WEBSITE.error.log;

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.2-fpm.sock;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }

}
END

# making directory for php? giving apache permissions to that log? restarting php
apt purge apache2 -y
mkdir /var/log/php
chown www-data /var/log/php
systemctl restart nginx
