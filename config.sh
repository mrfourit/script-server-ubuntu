#!/bin/bash

install_apache() {
    sudo apt update
    sudo apt-get install apache2 -y

    enable_mod_apache

    echo "DONE! Cai xong APACHE"
}

install_mysql() {
    sudo apt update
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

install_pagespeed() {
    echo "-----------Cai dat PAGESPEED------"
    read -p "Ban co muon cai dat PAGESPEED (Y|N)?" yes_no
    
    if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
        then
            echo "PAGESPEED khong duoc cai dat"
            exit 1
    fi

    if [ -f /etc/apache2/mods-available/pagespeed.conf ]
        then
            echo "PAGESPEED da duoc cai dat"
            exit 1
    fi

    sudo wget https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_amd64.deb
    sudo bash -c "sudo dpkg -i mod-pagespeed-stable*.deb"
    sudo bash -c "sudo rm -rf mod-pagespeed-stable*.deb"
    sudo sed -i "s/<\/IfModule>/ModPagespeedEnableFilters\ convert_jpeg_to_webp\,rewrite_css\n<\/IfModule>/g" /etc/apache2/mods-available/pagespeed.conf
    sudo service apache2 restart
}

open_config_OPcache() {
    INI_CONFIG="/etc/php/7.1/fpm/php.ini"
    echo "------Open OPcache---------"

    read -p "Ban co chac chan muon config OPcache (Y|N)? " yes_no

    if [ ! -d "/etc/php" ]
        then
            echo "Ban chua cai dat PHP"
    fi

    if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
        then
            echo "OPcache khong duoc config"
            exit 1
    fi

    if [ ! -f "/etc/php/7.1/fpm/php.ini" ]
        then
            INI_CONFIG="/etc/php/7.1/apache2/php.ini"
    fi
    
    if grep -q "^;opcache.enable=1" "${INI_CONFIG}"
        then
            sed -i "s/\;opcache\.enable\=1/opcache\.enable\=1/g" "${INI_CONFIG}"
            sed -i "s/\;opcache\.memory_consumption\=128/opcache\.memory_consumption\=256/g" "${INI_CONFIG}"
            sed -i "s/\;opcache\.max_accelerated_files\=10000/opcache\.max_accelerated_files\=10000/g" "${INI_CONFIG}"
            sed -i "s/\;opcache\.revalidate_freq\=2/opcache\.revalidate_freq\=100/g" "${INI_CONFIG}"
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
    STR_ALIAS="Alias /phpmyadmin \"/usr/share/phpmyadmin/\"
<Directory \"/usr/share/phpmyadmin/\">
    Order allow,deny
    Allow from all
    Require all granted
</Directory>"
    CONFIG_PHPMYADMIN="\$cfg['blowfish_secret'] = 'L.cWeE{beVu9}yHQuHz3ki5ysndddddl';

\$cfg['TempDir'] = \"/usr/share/phpmyadmin/tmp/\";"
    sudo apt update

    cd /usr/share
    wget https://files.phpmyadmin.net/phpMyAdmin/5.1.1/phpMyAdmin-5.1.1-all-languages.zip
    unzip phpMyAdmin-5.1.1-all-languages.zip
    mv phpMyAdmin-5.1.1-all-languages.zip phpmyadmin
    sudo chmod -R 755 phpmyadmin
    sudo sed -i "s/<\/VirtualHost>/$STR_ALIAS\n<\/VirtualHost>/" "/etc/apache2/sites-available/000-default.conf"
    cd phpmyadmin
    mv config.sample.inc.php config.inc.php
    echo "${CONFIG_PHPMYADMIN}" >> config.inc.php
    mkdir tmp
    chmod 777 tmp
    echo "DONE! Cai xong PHPMYADMIN"
}

auto_restart_service_die() {
    TIME_CRON="* * * * *"

    echo "-------------Auto restart service die"

    read -p "Ban co chac chan config (Y|N)? " yes_no
    read -p "Ban co muon custom thoi gian chay script. Mac dinh la moi phut: " time_cron_input

    crontab -l > crontab_new

    if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
        then
            echo "Script khong duoc config"
            exit 1
    fi

    if [ "${time_cron_input}" != "" ]
        then
            TIME_CRON="${time_cron_input}"
    fi

    CONTENT="#!/bin/bash

        log_file() {
        status=\"INFO\"

        if [ \"\${3}\" != \"\" ]
            then
                status=\"\${3}\"
        fi

        folder_log=\"\${1}\"

        sudo mkdir -p \"\${folder_log}\"

        date_log=\"\$(date +'%d-%m-%Y %T')\"

        content_log=\"\${2}\"

        echo \"[\${date_log}]  [\${status}]  \${content_log}\" >> \"\${folder_log}/log.txt\"
        }

        script_run() {
            LOG_FOLDER=\"/var/log/script_restart_auto\"

            if [[ \"\$(/usr/sbin/service mysql status)\" == *\"inactive (dead)\"* ]]
                then
                    /usr/sbin/service mysql start
                    log_file \"\${LOG_FOLDER}\" \"Mysql die\" \"ERROR\"
            fi
            if [[ \"\$(/usr/sbin/service apache2 status)\" == *\"inactive (dead)\"* ]]
                then
                    /usr/sbin/service apache2 start
                    log_file \"\${LOG_FOLDER}\" \"Apache2 die\" \"ERROR\"
            fi
        }

        script_run"

    if  grep -q "/home/script_auto_restart.sh" "crontab_new"
        then
            sudo rm -rf crontab_new
            echo "Scrip da duoc cai dat"
            exit 1
    fi

    sudo echo "${CONTENT}" >> /home/script_auto_restart.sh
    sudo chmod +x /home/script_auto_restart.sh

    echo "${TIME_CRON} /home/script_auto_restart.sh" >> crontab_new
    crontab crontab_new
    sudo rm -rf crontab_new
    sudo service cron restart
    echo "DONE! Script da duoc cai dat"
}

delete_swap() {
    if [ ! -f "/swapfile" ]
        then
            echo "Khong ton tai /swapfile"
            exit 1
    fi

    sudo swapoff -v /swapfile

    CHECK_FSTAB_EXIST="$(grep  "\/aswapfile\ none\ swap\ sw\ 0\ 0" /etc/fstab)"

    if [ "${CHECK_FSTAB_EXIST}" == "" ]
        then
            echo "Khong ton tai config /etc/fstab. Vui long check"
        else
            sudo sed -i 's/\/swapfile\ none\ swap\ sw\ 0\ 0/\ /g' /etc/fstab
            sudo rm -rf /swapfile
            echo "Done! Xoa swap thanh cong"
    fi
}

add_swap() {
    SIZE_SWAP_DEFAULT=5

    echo "--------Them SWAP-------"
    read -p "Ban co chac chan config SWAP (Y|N)? " yes_no

    if [ "${yes_no}" == "" ] || [ "${yes_no}" == "N" ] || [ "${yes_no}" == "n" ]
        then
            echo "Swap khong duoc them"
            exit 1
    fi

    if [ -f "/swapfile" ]
        then
            echo "Swap da duoc cai dat"
            exit 1
    fi

    read -p "Dung luong SWAP. Mac dinh la 5GB: " size_swap

    if [ "${size_swap}" != "" ] 
        then
            SIZE_SWAP_DEFAULT="${size_swap}"
    fi

    sudo bash -c "sudo fallocate -l ${SIZE_SWAP_DEFAULT}G /swapfile"

    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

    sudo sysctl vm.swappiness=10
    sudo sysctl vm.vfs_cache_pressure=50
    
    echo "vm.swappiness=10
    vm.vfs_cache_pressure=50" >> /etc/sysctl.conf

    echo "DONE! Them SWAP thanh cong"
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
    if [ -f "/etc/apache2/sites-available/${domain}-le-ssl.conf" ]
        then
            sudo bash -c "sudo rm -rf ${domain}-le-ssl.conf"
    fi
if [ -f "/etc/apache2/sites-available/${domain}-ssl.conf" ]
        then
            sudo bash -c "sudo rm -rf ${domain}-ssl.conf"
    fi
            
            
    sudo service apache2 restart
    echo "DONE! Da xoa domain"
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
    DOMAIN_ALIAS="$2"
    DOMAIN="$1"
    EMAIL="$3"
    DOMAIN_ALIAS_REDIRECT=""
    CURRENT_PATH="$(pwd)"

    if (( EUID != 0 ))
        then
            echo "Vui long run root"
        exit 1
    fi

    if [ "$EMAIL" == "" ]
        then
            echo "Nhap email"
            exit 1
    fi

    sudo mkdir -p /root
    cd /root

    if [ "$DOMAIN_ALIAS" != '' ]
        then
            DOMAIN_ALIAS=" -d $DOMAIN_ALIAS"
            DOMAIN_ALIAS_REDIRECT="[OR]\n\tRewriteCond %{SERVER_NAME} =$DOMAIN_ALIAS \n</VirtualHost>"
    fi

    if [[ ! -f "/etc/apache2/sites-available/$DOMAIN.conf" ]]
        then
            echo "Khong tin tai conf vhost"
            exit 1
    fi

    if [[ ! -f "/root/.acme.sh/acme.sh" ]]
        then
            sudo curl https://get.acme.sh | sudo sh -s email="$EMAIL"
            cd "/root/.acme.sh"
            bash ./acme.sh --register-account -m "$email"
            cd "$CURRENT_PATH"
    fi

    cd "/root/.acme.sh"

    bash -c "bash ./acme.sh --issue --force --apache -d $DOMAIN $DOMAIN_ALIAS"
    
    sudo cp "/etc/apache2/sites-available/$DOMAIN.conf" "/etc/apache2/sites-available/$DOMAIN-ssl.conf"         
    
    SSL_STRING="\tSSLCertificateFile \/root\/\.acme\.sh\/$DOMAIN\/fullchain\.cer\n\tSSLCertificateKeyFile \/root\/.acme.sh\/$DOMAIN\/$DOMAIN\.key\n\tSSLEngine on\n<\/VirtualHost\>"
    FORCE_REDIRECT="\tRewriteEngine on\n\tRewriteCond %{SERVER_NAME} =$DOMAIN $DOMAIN_ALIAS_REDIRECT\n\tRewriteRule ^ https:\/\/%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]"
    sudo sed -i "s/<\/VirtualHost>/$SSL_STRING/" "/etc/apache2/sites-available/$DOMAIN-ssl.conf"
    sudo sed -i "s/\:80>/\:443>/" "/etc/apache2/sites-available/$DOMAIN-ssl.conf"
    sudo sed -i "s/<\/VirtualHost>/$FORCE_REDIRECT\n<\/VirtualHost>/" "/etc/apache2/sites-available/$DOMAIN.conf"

    cd /etc/apache2/sites-available
    sudo a2ensite "$DOMAIN-ssl.conf"
    sudo service apache2 restart
}

show_question_add_ssl_domain() {
    echo "-------------------------------------------------------------"
    
    read -p "Nhap domain: " domain
    read -p "Nhap domain alias (neu co): " domain_alias
    if [[ ! -f "~/.acme.sh/acme.sh" ]]
        then
            read -p "Nhap email: " email
    fi
    add_domain_ssl "${domain}" "${domain_alias}" "${email}"
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

    if [ ! -d "/etc/apache2" ]
        then
            echo "Ban chua cai dat apache2"
    fi

    add_domain "${domain}" "${domain_alias}" "${email_report}" "${path_web}"
}
                        
show_question_limit_project() {
    echo "---------------Limit project----------------"

    read -p "Nhap duong dan project: " path_project
    read -p "Nhap duong dan image (filesystem): " path_image
    read -p "Nhap kich thuoc folder (size: MB): " size

    if [ path_project == "" ] || [ path_image == "" ] || [ size == "" ]
        then
            echo "Nhap thieu thong tin"
            exit 1
    fi

    show_yes_no_question "${path_project}" "${path_image}" "${size}"

    limit_project "${path_project}" "${path_image}" "${size}"
}

limit_project() {
    path_project="${1}"
    path_image="${2}"
    size="${3}"
    date_now="$(date +'%d_%m_%y_%H_%M_%S')"
    path_backup="${path_project}_backup_${date_now}"
    if [ -f "${path_image}" ]
       then
            echo "Filesystem da ton tai"
           exit 1
    fi

    if grep -q "${path_image} " /etc/fstab
       then
            echo "Filesystem da ton tai /etc/fstab"
            exit 1
    fi

    if grep -q "${path_project} " /etc/fstab
       then
            echo "Folder da ton tai /etc/fstab"
           exit 1
    fi
    
    mkdir -p "${path_project}"
    mkdir -p "${path_backup}"
    if [ "$(cd ${path_project} && ls -A)" != "" ]
        then
            cd "${path_project}" && sudo mv $(ls -A) "${path_backup}"
    fi
    sudo dd if=/dev/zero of="${path_image}" count="$((size*2048))"
    sudo /sbin/mkfs -t ext3 -q "${path_image}" -F
    echo "${path_image} ${path_project} ext3 rw,loop,usrquota,grpquota 0 0" >> /etc/fstab
    sudo mount "${path_project}"
    if [ "$(cd ${path_backup} && ls -A)" != "" ]
        then
            cd "${path_backup}" && sudo mv $(ls -A) "${path_project}"
    fi
    sudo rm -rf "${path_backup}"
    df -h
    echo "Done! Limit project done"
}
                    
increase_limit_project() {
                path_project="${1}"
    path_image="${2}"
    size="${3}"
    date_now="$(date +'%d_%m_%y_%H_%M_%S')"
    path_backup="${path_project}_backup_${date_now}"
  
    mkdir -p "${path_project}"
    mkdir -p "${path_backup}"
    if [ "$(cd ${path_project} && ls -A)" != "" ]
        then
            cd "${path_project}" && sudo mv $(ls -A) "${path_backup}"
    fi
    cd ..
    sudo umount "${path_project}"
    sudo dd if=/dev/zero of="${path_image}" count="$((size*2048))"
    sudo /sbin/mkfs -t ext3 -q "${path_image}" -F
                sudo mount "${path_project}"
    if [ "$(cd ${path_backup} && ls -A)" != "" ]
        then
            cd "${path_backup}" && sudo mv $(ls -A) "${path_project}"
    fi
    sudo rm -rf "${path_backup}"
    df -h
    echo "Done! Increase limit project done"
}
                        
show_yes_no_question() {
                read -p "Ban co chac chan muon tiep tuc (Y|y|N|n): " yes_no
    
    if [ "${yes_no}" != "Y" ] && [ "${yes_no}" != "y" ]
        then
            exit 1
    fi
}

show_question_increase_size_project() {
    echo "--------------Tang limit project----------------"

    read -p "Nhap duong dan project: " path_project
    read -p "Nhap duong dan image (filesystem): " path_image
    read -p "Nhap kich thuoc folder (size: MB): " size
                
    if [ path_project == "" ] || [ path_image == "" ] || [ size == "" ]
        then
            echo "Nhap thieu thong tin"
            exit 1
    fi

    show_yes_no_question
    
    increase_limit_project "${path_project}" "${path_image}" "${size}"
}

add_domain() {
    ALIAS_DOMAIN="";
    SERVER_ADMIN="webmaster@localhost"
    LOG_FOLDER="/var/log/apache2"

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

    sudo mkdir -p "${LOG_FOLDER}"

    sudo bash -c "mkdir -p ${4}"

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

    ErrorLog ${LOG_FOLDER}/error.log
    CustomLog ${LOG_FOLDER}/access.log combined
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

    if [ -f "/etc/apache2/sites-available/${domain}-le-ssl.conf" ]
        then
            if [[ "$(cat /etc/apache2/sites-available/${domain}-le-ssl.conf)" == *"proxy:unix"* || "$(cat /etc/apache2/sites-available/${domain}-le-ssl.conf)" == *"fcgi:"* ]]
                then
                    echo "Da config PHP-FPM for SSL"
                else
                    sed -i "s/DocumentRoot/${STR_INSERT}/g" "/etc/apache2/sites-available/${domain}-le-ssl.conf"
            fi
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
    echo "13. Auto restart service die"
    echo "14. Them SWAP"
    echo "15. Delete SWAP"
    echo "16. Install PAGESPEED"
    echo "17. Limit size project"
    echo "18. Tang dung luong project"
    echo "19. Tang dung luong project"
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

        13)
            auto_restart_service_die
            ;;

        14)
            add_swap
            ;;

        15)
            delete_swap
            ;;

        16)
            install_pagespeed
            ;;

        17)
            show_question_limit_project
            ;;

        18)
            show_question_increase_size_project
            ;;

    esac
}

show_switch_case
