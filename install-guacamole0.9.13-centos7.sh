#!/bin/bash
# Status: Testing
# Last Update: 17-12-18
#
# Adapted from MysticRyuujin's script for Ubuntu, https://github.com/MysticRyuujin/
# additional configuration found from Deviant Engineer's post, https://deviantengineer.com/2015/02/guacamole-centos7/

VERSION="0.9.13"
MCJVERSION="5.1.45"
TOMCAT="tomcat"

# Get MySQL root password and guac user password
echo
while true
do
    read -s -p "Enter a MySQL ROOT Password: " mysqlrootpassword
    echo
    read -s -p "Confirm MySQL ROOT Password: " password2
    echo
    [ "$mysqlrootpassword"="$password2" ] && break
    echo "Passwords do not match, please try again..."
    echo
done
echo
while true
do
    read -s -p "Enter a Guacamole User Database Password: " guacdbuserpassword
    echo
    read -s -p "Confirm Guacamole User Database Password: " password2
    echo
    [ "$guacdbuserpassword" = "$password2" ] && break
    echo "Passwords don't match. Please try again."
    echo
done
echo

# Update system and configure weekly updates
yum -y update
yum -y install yum-cron
systemctl enable yum-cron
systemctl start yum-cron
sed -i -e 's/# default/default  /g' /etc/yum/yum-cron.conf
sed -i -e 's/apply_updates = no/apply_updates = yes/g' /etc/yum/yum-cron.conf

# Install repositories and prerequisites: EPEL, Felfert, nux-dextop
yum -y install epel-release wget
wget -O /etc/yum.repos.d/home:felfert.repo http://download.opensuse.org/repositories/home:/felfert/CentOS_7/home:felfert.repo
yum -y groupinstall "Development Tools"
yum -y install cairo-devel freerdp-devel git java-1.8.0-openjdk libguac libguac-client-rdp libguac-client-ssh libguac-client-vnc libjpeg-turbo-devel libpng-devel libssh2-devel libtelnet-devel libvncserver-devel libwebp-devel libvorbis-devel mariadb-server maven openssl-devel pango-devel pulseaudio-libs-devel terminus-fonts tomcat tomcat-admin-webapps tomcat-webapps uuid-devel
rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm
yum -y install ffmpeg-devel

# If yum fails to run completely the rest of this isn't going to work...
if [ $? != 0 ]; then
    echo "yum failed to install all required dependencies"
    exit
fi

# Add GUACAMOLE_HOME to $TOMCAT ENV
echo "" >> /usr/share/${TOMCAT}
echo "# GUACAMOLE ENV VARIABLE" >> /usr/share/${TOMCAT}
echo "GUACAMOLE_HOME=/etc/guacamole" >> /usr/share/${TOMCAT}

# Set SERVER to be the preferred download server from the Apache CDN
SERVER="http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/${VERSION}-incubating"


# Download Guacamole Server
wget -O guacamole-server-${VERSION}-incubating.tar.gz ${SERVER}/source/guacamole-server-${VERSION}-incubating.tar.gz
if [ ! -f ./guacamole-server-${VERSION}-incubating.tar.gz ]; then
    echo "Failed to download guacamole-server-${VERSION}-incubating.tar.gz"
    echo "${SERVER}/source/guacamole-server-${VERSION}-incubating.tar.gz"
    exit
fi

# Download Guacamole Client
wget -O guacamole-${VERSION}-incubating.war ${SERVER}/binary/guacamole-${VERSION}-incubating.war
if [ ! -f ./guacamole-${VERSION}-incubating.war ]; then
    echo "Failed to download guacamole-${VERSION}-incubating.war"
    echo "${SERVER}/binary/guacamole-${VERSION}-incubating.war"
    e$ser
fi

# Download Guacamole authentication extensions
wget -O guacamole-auth-jdbc-${VERSION}-incubating.tar.gz ${SERVER}/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
if [ ! -f ./guacamole-auth-jdbc-${VERSION}-incubating.tar.gz ]; then
    echo "Failed to download guacamole-auth-jdbc-${VERSION}-incubating.tar.gz"
    echo "${SERVER}/binary/guacamole-auth-jdbc-${VERSION}-incubating.tar.gz"
    exit
fi

# Download MySQL Connector-J
wget -O mysql-connector-java-${MCJVERSION}.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz
if [ ! -f ./mysql-connector-java-${MCJVERSION}.tar.gz ]; then
    echo "Failed to download guacamole-server-${VERSION}-incubating.tar.gz"
    echo "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MCJVERSION}.tar.gz"
    exit
fi

# Extract Guacamole files
tar -xzf guacamole-server-${VERSION}-incubating.tar.gz
tar -xzf guacamole-auth-jdbc-${VERSION}-incubating.tar.gz
tar -xzf mysql-connector-java-${MCJVERSION}.tar.gz

# Make directories
mkdir -p /etc/guacamole/lib
mkdir -p /etc/guacamole/extensions

# Install guacd
cd guacamole-server-${VERSION}-incubating
./configure --with-init-dir=/etc/init.d
make
make install
ldconfig
systemctl enable guacd
cd ..

# Move files to correct locations
mv guacamole-${VERSION}-incubating.war /etc/guacamole/guacamole.war
ln -s /etc/guacamole/guacamole.war /var/lib/${TOMCAT}/webapps/
cp mysql-connector-java-${MCJVERSION}/mysql-connector-java-${MCJVERSION}-bin.jar /etc/guacamole/lib/
cp guacamole-auth-jdbc-${VERSION}-incubating/mysql/guacamole-auth-jdbc-mysql-${VERSION}-incubating.jar /etc/guacamole/extensions/

# Configure guacamole.properties
echo "mysql-hostname: localhost" >> /etc/guacamole/guacamole.properties
echo "mysql-port: 3306" >> /etc/guacamole/guacamole.properties
echo "mysql-database: guacamole_db" >> /etc/guacamole/guacamole.properties
echo "mysql-username: guacamole_user" >> /etc/guacamole/guacamole.properties
echo "mysql-password: $guacdbuserpassword" >> /etc/guacamole/guacamole.properties
echo "mysql-default-max-connections-per-user: 0" >> /etc/guacamole/guacamole.properties
echo "mysql-default-max-group-connections-per-user: 0" >> /etc/guacamole/guacamole.properties
rm -rf /usr/share/${TOMCAT}/.guacamole
ln -s /etc/guacamole /usr/share/${TOMCAT}/.guacamole

systemctl restart tomcat.service

# SQL code
systemctl restart mariadb.service
mysqladmin -u root password $mysqlrootpassword
SQLCODE="
create database guacamole_db;
create user 'guacamole_user'@'localhost' identified by \"$guacdbuserpassword\";
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';
flush privileges;"
# Execute SQL code
echo $SQLCODE | mysql -u root -p$mysqlrootpassword
# Add Guacamole schema to newly created database
cat guacamole-auth-jdbc-${VERSION}-incubating/mysql/schema/*.sql | mysql -u root -p$mysqlrootpassword guacamole_db

# Cleanup
systemctl enable tomcat.service && systemctl enable mariadb.service && chkconfig guacd on
rm -rf guacamole-*
rm -rf mysql-connector-java-${MCJVERSION}*

echo -e "Installation Complete\nhttp://localhost:8080/guacamole/\nDefault login guacadmin:guacadmin\nBe sure to change the password."