#!/bin/bash

install_apache() {
    sudo apt-get install apache2 -y

    enable_mod_apache

    echo "DONE! Cai xong APACHE"
}

install_mysql() {
    apt-get install mysql-server -y

    sudo mysql -u root -e "ALTER USER \"root\"@\"localhost\" IDENTIFIED WITH mysql_native_password BY \"${1}\";FLUSH PRIVILEGES;"

    echo "DONE! Cai xong MYSQL"
}

install_php_fpm() {
    echo "-------Install PHP-FPM----------"
    read -p "Ban co chac chan muon cai PHP-FPM (Y|N)? " yes_no

    if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
        then
            echo "PHP-FPM khong duoc cai dat"
            exit 1
    fi

    sudo apt update
    sudo apt install -y libapache2-mod-fcgid
    sudo apt install -y php7.1-fpm
    sudo a2enmod actions fcgid alias proxy_fcgi

    echo "DONE! PHP-FPM"
}

open_config_OPcache() {
    INI_CONFIG="/etc/php/7.1/fpm/php.ini"
    echo "------Open OPcache---------"

    read -p "Ban co chac chan muon config OPcache (Y|N)? " yes_no

    if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
        then
            echo "OPcache khong duoc config"
            exit 1
    fi

    if [ ! -f "/etc/php/7.1/fpm/php.ini" ]
        then
            INI_CONFIG="/etc/php/7.2/apache2/php.ini"
    fi
    
    if grep -q "^;opcache.enable=1" "${INI_CONFIG}"
        then
            sed -i "s/\;opcache\.enable\=1/opcache\.enable\=1/g" "${INI_CONFIG}"
            sed -i "s/\;opcache\.memory_consumption\=128/opcache\.memory_consumption\=256/g" "${INI_CONFIG}"
            sed -i "s/\;opcache\.max_accelerated_files\=10000/opcache\.max_accelerated_files\=10000/g" "${INI_CONFIG}"
            sed -i "s/\;opcache_revalidate_freq\=2/opcache_revalidate_freq\=100/g" "${INI_CONFIG}"
        else
            echo "OPcache da duoc cai dat"
            exit 1
    fi

    sudo service apache2 restart

    echo "DONE! Config xong OPcache"
}

show_question_mysql() {
    echo "------------------------------------------"
    read -s -p "Nhap mat khau ROOT: " password

    install_mysql "${password}"
}

install_php() {
    sudo apt-get install software-properties-common    
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update
    sudo apt install -y php7.1 libapache2-mod-php7.1 php7.1-common php7.1-mbstring php7.1-xmlrpc php7.1-soap php7.1-gd php7.1-xml php7.1-intl php7.1-mysql php7.1-cli php7.1-mcrypt php7.1-zip php7.1-curl
    echo "DONE! Cai xong PHP"
}

install_phpmyadmin() {
    sudo apt update

    if [[  "$(cat /etc/os-release)" == *"18.04"*  ]]
        then 
            sudo apt-get install -y phpmyadmin php-mbstring php-gettext
        else
            sudo apt-get install -y phpmyadmin php-mbstring
    fi

    sudo phpenmod mbstring
    sudo systemctl restart apache2
    echo "DONE! Cai xong PHPMYADMIN"
}

delete_domain() {
    echo "--------Xoa domain----------"
    read -p "Domain can xoa: " domain

    read -p "Ban co chac chan muon xoa domain (Y|N)? " yes_no

    if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
        then
            echo "Domain khong duoc xoa"
            exit 1
    fi

    if [ ! -f "/etc/apache2/sites-available/${domain}.conf" ]
        then
            echo "Domain khong ton tai"
            exit 1
    fi

    cd /etc/apache2/sites-available/
    sudo bash -c "sudo a2dissite ${domain}.conf"
    sudo bash -c "sudo rm -rf ${domain}.conf"
    sudo service apache2 restart
}

delete_account_ftp() {
    echo "------Xoa account FTP-------"
    read -p "Nhap tai khoan username: " username
    read -p "Ban co muon xoa user ubuntu (Y|N)? " yes_no_del_user
    read -p "Ban co chac chan muon xoa FTP (Y|N)? " yes_no

    if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
        then
            echo "Account khong duoc xoa"
            exit 1
    fi

    if [ "${username}" == "" ]
        then
            echo "Loi! Nhap username vao nhe"
            exit 1
    fi

    if [ ! -f "/account_ftp/${username}.conf" ]
        then
            echo "Account khong ton tai"
            exit 1
    fi

    sudo bash -c "sudo rm -rf /account_ftp/${username}.conf"

    sed -i ":a;N;\$!ba;s/\ ${username}\n/\ \n/g" /account_ftp/list_user_allow_login.conf
    sed -i "s/\ ${username}\ /\ /g" /account_ftp/list_user_allow_login.conf

    if [ "${yes_no_del_user}" == "Y" ] || [ "${yes_no_del_user}" == "y" ]
        then
            sudo bash -c "sudo deluser ${username}"
    fi

    echo "DONE! Xoa account FTP thanh cong"

    sudo /etc/init.d/proftpd restart
}

add_domain_ssl() {
    DOMAIN_ALIAS=""

    if [ ! -d "/etc/letsencrypt" ]
        then
            sudo apt update

            sudo add-apt-repository -y ppa:certbot/certbot

            if [[  "$(cat /etc/os-release)" == *"18.04"*  ]]
                then
                    sudo apt install -y python-certbot-apache
                else
                    sudo apt install -y certbot python3-certbot-apache
            fi
            crontab -l > crontab_new
            echo "0 0 1 * * certbot renew && service apache2 restart" >> crontab_new
            crontab crontab_new
            sudo rm -rf crontab_new
            sudo service cron restart
    fi

    if [ "${2}" != '' ]
        then
            DOMAIN_ALIAS=" -d ${2}"
    fi

     sudo bash -c "sudo certbot --apache -d ${1} ${DOMAIN_ALIAS}"
}

show_question_add_ssl_domain() {
    echo "-------------------------------------------------------------"

    read -p "Nhap domain: " domain
    read -p "Nhap domain alias (neu co): " domain_alias

    add_domain_ssl "${domain}" "${domain_alias}"
}

show_question_root_password() {
    echo "------------------------------------------------------------"
    read -s -p "Nhap password ROOT MYSQL: " password
    install_phpmyadmin "${password}"
}

enable_mod_apache() {
    sudo a2enmod rewrite
    sudo a2enmod ssl
    sudo service apache2 restart
}

show_question_add_domain() {
    echo "------------------------------------------------------------"
    read -p "Nhap domain: " domain
    read -p "Nhap domain alias (neu co): " domain_alias
    read -p "Nhap duong dan website: " path_web
    read -p "Nhap email quan tri server: " email_report

    add_domain "${domain}" "${domain_alias}" "${email_report}" "${path_web}"
}

add_domain() {
    ALIAS_DOMAIN="";
    SERVER_ADMIN="webmaster@localhost"

    sudo mkdir -p /var/log/apache2

    if [ "${1}" == "" ]
        then
            echo "Loi! Nhap du thong tin nha ban!"
            exit 1
    fi

    if [ "${4}" == "" ]
        then
            echo "Loi! Nhap du thong tin nha ban!"
            exit 1
    fi

    if [ "${2}" != '' ]
        then
            ALIAS_DOMAIN="ServerAlias ${2}"
    fi

    if [ "${3}" != '' ]
        then
            SERVER_ADMIN="${3}"
    fi

    CONTENT_FILE="<VirtualHost *:80>
        ServerName ${1}
        ${ALIAS_DOMAIN}
        
        ServerAdmin ${SERVER_ADMIN}
        DocumentRoot ${4}

        <Directory ${4}>
            Options Indexes FollowSymLinks MultiViews
            AllowOverride All
            Order allow,deny
            allow from all
            Require all granted
        </Directory>

        ErrorLog /var/log/apache2/error.log
        CustomLog /var/log/apache2/access.log combined
    </VirtualHost>"

    sudo bash -c "echo \"${CONTENT_FILE}\" >> /etc/apache2/sites-available/${1}.conf"
    cd /etc/apache2/sites-available/
    sudo bash -c "sudo a2ensite -q ${1}.conf"
    sudo service apache2 restart
    echo "DONE!"
}

show_question_add_account_ftp() {
    echo "------------------------------------------"
    read -p "Nhap username: " username
    read -s -p "Nhap password: " password
    echo
    read -p "Nhap duong dan folder: " path_folder

    if [ username == "list_user_allow_login" ] || [ "${username}" == "AllowUser" ]
        then
            echo "Loi! Khong duoc tao user nay"
            exit 1
    fi

    install_proftpd

    add_user "${username}" "${password}" "${path_folder}"

    sudo bash -c "sudo mkdir -p \"${path_folder}\""
    sudo bash -c "sudo chown ${username}:${username} \"${path_folder}\""

    add_account_ftp "${username}" "${path_folder}"
}

add_account_ftp() {
    sudo mkdir -p /account_ftp

    if test -f "/account_ftp/list_user_allow_login.conf"
        then
            sed -i "s/AllowUser/AllowUser\ ${1}/g" /account_ftp/list_user_allow_login.conf
        else
            CONTENT_FILE_USER_LOGIN="<Limit LOGIN>
                AllowUser ${1}
                DenyALL
            </Limit>"
            sudo bash -c "echo \"${CONTENT_FILE_USER_LOGIN}\" >> /account_ftp/list_user_allow_login.conf"
    fi

    if ! grep -q "/account_ftp" "/etc/proftpd/proftpd.conf"
        then
            sudo bash -c "echo \"Include /account_ftp/\" >> /etc/proftpd/proftpd.conf"
    fi

    if ! grep -q "/account_ftp/list_user_allow_login.conf" "/etc/proftpd/proftpd.conf"
        then
            sudo bash -c "echo \"Include /account_ftp/list_user_allow_login.conf\" >> /etc/proftpd/proftpd.conf"
    fi

    CONTENT_FILE="DefaultRoot ${2} ${1}

        <Directory ${2}/>
            Umask 022 022
            AllowOverwrite on
            <Limit MKD STOR  XMKD RNRF RNTO RMD XRMD CWD>
                DenyAll
            </Limit>

            <Limit STOR CWD MKD>
                AllowAll
            </Limit>
        </Directory>"

    sudo bash -c "echo \"${CONTENT_FILE}\" >> /account_ftp/${1}.conf"

    sudo /etc/init.d/proftpd restart
    echo "Them account FTP thanh cong"
}

install_proftpd() {
    if [ ! -f "/etc/proftpd/proftpd.conf" ]
        then
            sudo apt-get install proftpd -y

            add_bin_false
    fi
}

add_bin_false() {
    if ! grep -q "/bin/false" "/etc/shells"
        then
            sudo bash -c "echo \"/bin/false\" >> /etc/shells"
    fi
}

add_user() {
    sudo bash -c "useradd ${1} -d ${3} -s /bin/false"
    sudo bash -c "echo -e \"${2}\n${2}\" | sudo -S passwd ${1}"
}

add_config_php_fpm() {
    STR_INSERT="\<FilesMatch\ \\\.php\$\>\n\ SetHandler\ \"proxy\:unix\:\/var\/run\/php\/php7\.1\-fpm\.sock\|fcgi\:\/\/localhost\"\n\ \<\/FilesMatch\>\n\ DocumentRoot\ "

    echo "--------Them config PHP-FPM vao website-------------"
    
    read -p "Nhap domain muon config (vhost): " domain
    
    if [ "${domain}" == "" ]
        then
            echo "Phai nhap domain ban nhe"
            exit 1
    fi

    if [ ! -f "/etc/apache2/sites-available/${domain}.conf" ]
        then
            echo "Khong ton tai config domain"
            exit 1
    fi

    if [[ "$(cat /etc/apache2/sites-available/${domain}.conf)" == *"proxy:unix"* || "$(cat /etc/apache2/sites-available/${domain}.conf)" == *"fcgi:"* ]]
        then
            echo "Da config PHP-FPM"
        else
            sed -i "s/DocumentRoot/${STR_INSERT}/g" "/etc/apache2/sites-available/${domain}.conf"
    fi

    sudo service apache2 restart

    echo "DONE! Them config PHP-FPM vao domain ${domain}"
}

show_switch_case() {
    echo "1. Install APACHE"
    echo "2. Install MYSQL"
    echo "3. Install PHP 7.1"
    echo "4. Install PHPMYADMIN"
    echo "5. Them domain"
    echo "6. Xoa domain"
    echo "7. Them account FTP"
    echo "8. Xoa account FTP"
    echo "9. Them SSL"
    echo "10. Install PHP-FPM"
    echo "11. Them config PHP-FPM vao website"
    echo "12. Config OPcache"
    echo "-------------------------------"
    read -p "Chon: " step

    case $step in

        1)
            install_apache
            ;;

        2)
            show_question_mysql
            ;;

        3)
            install_php
            ;;

        4)
            install_phpmyadmin
            ;;

        5)
            show_question_add_domain
            ;;

        6)
            delete_domain
            ;;

        7)
            show_question_add_account_ftp
            ;;
        
        8)
            delete_account_ftp
            ;;

        9)
            show_question_add_ssl_domain
            ;;

        10)
            install_php_fpm
            ;;

        11)
            add_config_php_fpm
            ;;

        12)
            open_config_OPcache
            ;;

    esac
}

show_switch_case