#!/usr/bin/env bash

# Use single quotes instead of double quotes to make it work with special-character passwords
HOSTNAME='ask.ascommultiservice.local'
IP_VM='10.0.2.15'
IP_HS='192.168.111.222'
DBHOST='localhost'
DBNAME='amsdev'
DBUSER='amsdev'
DBPASSWD='ams;dev01'

# create project folder
# sudo mkdir "/var/www"

# update / upgrade
sudo apt-get update
sudo apt-get -y upgrade
export DEBIAN_FRONTEND=noninteractive

# install LAMP common tool
sudo apt-get install -y vim curl python-software-properties zip git vfu htop 

# Set Host File
sudo sh -c "echo '$IP_VM $HOSTNAME' >> /etc/hosts"

# install apache 2.5 and php 5.6
sudo apt-get install -y apache2
sudo add-apt-repository ppa:ondrej/php
sudo apt-get -y update
sudo apt-get install -y php5.6
sudo a2enmod php5.6 
sudo service apache2 restart

# install mysql and give password to installer
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $DBPASSWD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DBPASSWD"
sudo apt-get -y install mysql-server
sudo apt-get install php5.6-mysql

#install common libraries
apt-get install -y php5.6-mcrypt php5.6-mbstring php5.6-curl php5.6-cli php5.6-mysql php5.6-gd php5.6-intl php5.6-xsl php5.6-zip php5.6-xdebug php-pear	build-essential		

# install phpmyadmin and give password(s) to installer
# for simplicity I'm using the same password for mysql and phpmyadmin
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get -y install 

# Mysql User's amsdev creation
echo -e "\n--- Setting up our MySQL user and db ---\n"
mysql -uroot -p$DBPASSWD -e "CREATE USER 'amsdev'@'localhost' IDENTIFIED BY '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON * . * TO '$DBUSER'@'localhost' identified by '$DBPASSWD'"

# setup hosts file
VHOST=$(cat <<EOF
<VirtualHost *:80>
    ServerName dev.ascommultiservice.local
    DocumentRoot "/var/www"
    <Directory "/var/www">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf

# Set PHP OPTIONS
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 32M/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 32M/" /etc/php/5.6/apache2/php.ini
sudo sed -i "s/disable_functions = .*/disable_functions = /" /etc/php/5.6/cli/php.ini

# Set Mysql OPTIONS
sudo sed -i "s/bind-address            = 127.0.0.1/bind-address            = 192.168.111.222/" /etc/mysql/my.cnf

# enable mod_rewrite
sudo a2enmod rewrite

# install and configure xdebug
mkdir /var/log/xdebug
chown www-data:www-data /var/log/xdebug
echo ';;;;;;;;;;;;;;;;;;;;;;;;;;' >> /etc/php/5.6/apache2/php.ini
echo '; Added to enable Xdebug ;' >> /etc/php/5.6/apache2/php.ini
echo ';;;;;;;;;;;;;;;;;;;;;;;;;;' >> /etc/php/5.6/apache2/php.ini
echo '' >> /etc/php/5.6/apache2/php.ini
echo 'zend_extension="'$(find / -name 'xdebug.so' 2> /dev/null)'"' >> /etc/php/5.6/apache2/php.ini
echo 'xdebug.default_enable = 1' >> /etc/php/5.6/apache2/php.ini
echo 'xdebug.idekey = "sublime.xdebug"' >> /etc/php/5.6/apache2/php.ini
echo 'xdebug.remote_enable = 1' >> /etc/php/5.6/apache2/php.ini
echo 'xdebug.remote_autostart = 0' >> /etc/php/5.6/apache2/php.ini
echo 'xdebug.remote_port = 9001' >> /etc/php/5.6/apache2/php.ini
echo 'xdebug.remote_handler=dbgp' >> /etc/php/5.6/apache2/php.ini
echo 'xdebug.remote_log="/var/log/xdebug/xdebug.log"' >> /etc/php/5.6/apache2/php.ini
echo 'xdebug.remote_host=10.0.2.2 ; IDE-Environments IP, from vagrant box.' >> /etc/php/5.6/apache2/php.ini

# install Composer
curl -s https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Enable Swap
sudo /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=2048
sudo /sbin/mkswap /var/swap.1
sudo /sbin/swapon /var/swap.1

# restart service
sudo service apache2 restart
sudo service mysql restart
