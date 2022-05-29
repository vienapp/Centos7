#!/bin/bash

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

# Make sure only root can run our script
rootness(){
    if [[ $EUID -ne 0 ]]; then
        echo "Maaf, Anda harus menjalankan ini sebagai root !!!" 1>&2
        exit 1
    fi
}

Set_Centos_Repo() {
    clear
    echo "###################################################################"
    echo "#                      Install Repository                         #"
    echo "###################################################################"
    yum -y install yum-plugin-fastestmirror
    yum -y install yum-plugin-priorities
    yum -y install https://raw.githubusercontent.com/vienapp/Centos7/master/epel-release-latest-7.noarch.rpm
    yum -y install https://raw.githubusercontent.com/vienapp/Centos7/master/remi-release-7.rpm
}

set_install() {
    clear
    echo "###################################################################"
    echo "#                     MULAI INSTALASI !!                          #"
    echo "#                    Script By HARVIEN !!                         #"
    echo "###################################################################"
    sleep 3
    yum -y update
    yum -y install sudo nano curl firewalld gcc git openssh-server openssh-clients httpd yum-utils
    wget -O /etc/environment "https://raw.githubusercontent.com/vienapp/Centos7/master/environment"
    
    clear
    echo "###################################################################"
    echo "#                      Install NTP LOKAL                          #"
    echo "###################################################################"
    cd
    yum -y install ntp
    wget -O /etc/ntp.conf "https://raw.githubusercontent.com/vienapp/Centos7/master/ntp.conf"
    systemctl enable ntpd
    systemctl start ntpd
    ntpq -p
    timedatectl set-timezone Asia/Jakarta
    timedatectl
}

# Pre-installation settings
pre_installation_settings(){
    Set_Centos_Repo
    set_install
}

# Install Apache
install_apache(){
    echo "###################################################################"
    echo "#                    Install Apache & PHP                         #"
    echo "###################################################################"
    sleep 2
    
    cd
    yum -y install httpd
    echo "Pilih Versi PHP [1-4]:"
    PS3='Silahkan Pilih Nomor PHP Mana Yang Anda Install [1-4]: '
    php=("PHP_5.6" "PHP_7" "PHP_7.4" "PHP_8")
    select pilih in "${php[@]}"; do
        case $pilih in
            "PHP_5.6")
                yum -y remove php*
                yum-config-manager --disable 'remi-php*'
                yum-config-manager --enable remi-php56
                yum -y install php php-{cli,fpm,mysqlnd,zip,devel,gd,mbstring,curl,xml,pear,bcmath,json}
                break
            ;;
            "PHP_7")
                yum -y remove php*
                yum-config-manager --disable 'remi-php*'
                yum-config-manager --enable remi-php70
                yum -y install php php-{cli,fpm,mysqlnd,zip,devel,gd,mbstring,curl,xml,pear,bcmath,json}
                break
            ;;
            "PHP_7.4")
                yum -y remove php*
                yum-config-manager --disable 'remi-php*'
                yum-config-manager --enable remi-php74
                yum -y install php php-{cli,fpm,mysqlnd,zip,devel,gd,mbstring,curl,xml,pear,bcmath,json}
                break
            ;;
            "PHP_8")
                yum -y remove php*
                yum-config-manager --disable 'remi-php*'
                yum-config-manager --enable remi-php80
                yum -y install php php-{cli,fpm,mysqlnd,zip,devel,gd,mbstring,curl,xml,pear,bcmath,json}
                break
            ;;
            *) echo "Pilih Dengan Benar Antara 1 s/d 4 !!!";;
        esac
    done
    
    cp /etc/php.ini /etc/php.ini.backup
    MYPHPINI=`find /etc -name php.ini -print`
    sed -i "s/;date.timezone =/date.timezone = Asia\/Jakarta/" "$MYPHPINI"
    sed -i "s/max_execution_time\s*=.*/max_execution_time = 600/g" "$MYPHPINI"
    sed -i "s/max_input_time\s*=.*/max_input_time = 600/g" "$MYPHPINI"
    sed -i "s/; max_input_vars\s*=.*/max_input_vars = 4000/g" "$MYPHPINI"
    sed -i "s/memory_limit\s*=.*/memory_limit = -1/g" "$MYPHPINI"
    sed -i "s/post_max_size\s*=.*/post_max_size = 1536M/g" "$MYPHPINI"
    sed -i "s/upload_max_filesize\s*=.*/upload_max_filesize = 1024M/g" "$MYPHPINI"
}

# Install MySQL
install_mysql() {
    echo "###################################################################"
    echo "#                        Install MySQL                            #"
    echo "###################################################################"
    sleep 2
    
    cd
    systemctl stop mariadb
    yum -y remove mariadb*
    yum -y install mariadb mariadb-server
    echo "Masukkan Password MySql Anda !"
    read -p "(Password MySql Dengan User root):" dbrootpwd
    if [ -z $dbrootpwd ]; then
        dbrootpwd="root"
    fi
    echo
    echo "---------------------------"
    echo "Password = $dbrootpwd"
    echo "---------------------------"
    echo
    
    yum -y install expect
    echo "Silahkan Tunggu Sebentar, Sedang Konfigurasi MySQL..."
    MARIADB_ROOT_PASS=$dbrootpwd
    SECURE_MYSQL=$(expect -c "
	set timeout 3
	spawn mysql_secure_installation
	expect \"Enter current password for root (enter for none):\"
	send \"\r\"
	expect \"Set root password? \[Y/n\]\"
	send \"y\r\"
	expect \"New password:\"
	send \"${MARIADB_ROOT_PASS}\r\"
	expect \"Re-enter new password:\"
	send \"${MARIADB_ROOT_PASS}\r\"
	expect \"Remove anonymous users? \[Y/n\]\"
	send \"y\r\"
	expect \"Disallow root login remotely? \[Y/n\]\"
	send \"n\r\"
	expect \"Remove test database and access to it? \[Y/n\]\"
	send \"y\r\"
	expect \"Reload privilege tables now? \[Y/n\]\"
	send \"y\r\"
	expect eof
    ")
    echo "${SECURE_MYSQL}"
    yum -y remove expect
    
/usr/bin/mysql -uroot -p${MARIADB_ROOT_PASS} <<EOF
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MARIADB_ROOT_PASS}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
exit
EOF
    
    cp /etc/my.cnf /etc/my.cnf.backup
    MYCNF=`sudo find /etc -name my.cnf -print`
    INSERT1="default_time_zone='+07:00'"
    INSERT2='big-tables'
    INSERT3='max_allowed_packet = 1G'
    INSERT4='innodb_file_per_table = 1'
    INSERT5='bind-address=127.0.0.1'
    sed -i "/\[mysqld\]/a$INSERT1\n$INSERT2\n$INSERT3\n$INSERT4\n$INSERT5" "$MYCNF"
}

# services
services() {
    echo "###################################################################"
    echo "#                          Services                               #"
    echo "###################################################################"
    sleep 2
    
    cd
    systemctl start httpd.service
    systemctl start firewalld
    systemctl start sshd.service
    systemctl start mariadb
    systemctl enable httpd.service
    systemctl enable firewalld
    systemctl enable sshd.service
    systemctl enable mariadb
    firewall-cmd --permanent --zone=public --add-port=80/tcp
    firewall-cmd --permanent --zone=public --add-port=433/tcp
    firewall-cmd --permanent --zone=public --add-port=3306/tcp
    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --permanent --zone=public --add-service=mysql
    firewall-cmd --permanent --zone=public --add-service=ssh
    firewall-cmd --reload
    systemctl restart httpd.service
    systemctl restart firewalld
    systemctl restart sshd.service
    systemctl restart mariadb
}

# Finish
Finish() {
    PHP='php'
    echo "####################################################################"
    echo "# Instalasi Telah Selesai !                                        #"
    echo "#==================================================================#"
    echo "# MySQL root password: $dbrootpwd                                  #"
    echo "#==================================================================#"
    echo "# Port SSH: 22                                                     #"
    echo "# Port Apache: 80                                                  #"
    echo "# Port Mysql: 3306                                                 #"
    echo "#==================================================================#"
    echo "# Terima Kasih Telah Menggunakan Tools Ini !                       #"
    echo "# Jika Ada Masalah Silahkan Hubungi :                              #"
    echo "# WhatsApp : +62-8222-1000-725                                     #"
    echo "# Telegram : https://t.me/NotBad404                                #"
    echo "# Instagram : https://www.instagram.com/harvien_saputro/           #"
    echo "# Facebook : https://www.facebook.com/harvieno/                    #"
    echo "# Github : https://github.com/vienapp                              #"
    echo "####################################################################"
    sleep 2
}

# Uninstall lamp
uninstall_lamp(){
    echo "Warning! All of your data will be deleted..."
    echo "Are you sure uninstall LAMP? (y/n)"
    read -p "(Default: n):" uninstall
    if [ -z $uninstall ]; then
        uninstall="n"
    fi
    if [[ "$uninstall" = "y" || "$uninstall" = "Y" ]]; then
        clear
        echo "==========================="
        echo "Yes, I agreed to uninstall!"
        echo "==========================="
        echo
    else
        echo
        echo "============================"
        echo "You cancelled the uninstall!"
        echo "============================"
        exit
    fi
    
    echo "Press any key to start uninstall...or Press Ctrl+c to cancel"
    char=`get_char`
    echo
    if [[ "$uninstall" = "y" || "$uninstall" = "Y" ]]; then
        cd ~
        CHECK_MARIADB=$(mysql -V | grep -i 'MariaDB')
        service httpd stop
        service mysqld stop
        yum -y remove httpd*
        if [ -z $CHECK_MARIADB ]; then
            yum -y remove mysql*
        else
            yum -y remove mariadb*
        fi
        if [ -s /usr/bin/atomic-php55-php ]; then
            yum -y remove atomic-php55-php*
            elif [ -s /usr/bin/atomic-php56-php ]; then
            yum -y remove atomic-php56-php*
            elif [ -s /usr/bin/atomic_php70 ]; then
            yum -y remove atomic-php70-php*
        else
            yum -y remove php*
        fi
        rm -rf /data/www/default/phpmyadmin
        rm -rf /etc/httpd
        rm -f /usr/bin/lamp
        rm -f /etc/my.cnf.rpmsave
        rm -f /etc/php.ini.rpmsave
        echo "Successfully uninstall LAMP!!"
    else
        echo
        echo "Uninstall cancelled, nothing to do..."
        echo
    fi
}

# Install LAMP Script
install_lamp(){
    rootness
    pre_installation_settings
    install_apache
    install_mysql
    services
    cd
    rm -rf /root/vienapp.sh
    clear
    echo
    echo 'Congratulations !!!'
    echo
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install)
        install_lamp
    ;;
    uninstall)
        uninstall_lamp
    ;;
    *)
        echo "Usage: `basename $0` [install|uninstall|add|del|list]"
    ;;
esac
