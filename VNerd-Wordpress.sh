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
apt-get install nginx mysql-server php php-pear libapache2-mod-php7.0 php-mysql php-gd -y

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

# making directory for php? giving apache permissions to that log? restarting php
mkdir /var/log/php
chown www-data /var/log/php
systemctl restart nginx
