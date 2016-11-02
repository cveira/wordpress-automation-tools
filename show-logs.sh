#!/bin/bash

multitail -s 2 \
          -cS apache -i /var/log/apache2/error.log \
          -cS apache -i /var/log/apache2/error_stg.ascent.atos.net.log \
          -cS apache -i /var/log/php5/www-pro.access.log \
          -cS apache -i /var/log/php5/www-stg.access.log \
          -e " 40[0-9] " -e " 50[0-9] " -e failure -i /var/log/haproxy.log \
          -cS mysql -e ERROR -e Warning -i /var/log/mysql/mysql-error.log \
          -cS syslog -e suhosin -e CRON -i /var/log/syslog \
          -cS netstat -R 5 -ts -l "netstat -an | grep ':22' | grep ESTABLISHED" \
          -cS audit -e Accepted -e fail -e session -i /var/log/auth.log
