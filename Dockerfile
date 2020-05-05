FROM gmitirol/alpine310-php73

ENV KIMAI="1.6.2" \
    TZ="Europe/Berlin" \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    APP_ENV=prod \
    DATABASE_URL=sqlite:///%kernel.project_dir%/var/data/kimai.sqlite

LABEL maintainer="mplx <mplx+docker@donotreply.at>"

EXPOSE 8080/tcp

RUN set -xe && \
    mkdir -p /home/project/kimai2/ && \
    echo $TZ > /etc/TZ &&\
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && \
    apk add --no-cache --update git mysql-client sqlite && \
    rm -rf /var/cache/apk/* && \
    curl -L -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/2.4.1/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq && \
    setup-nginx.sh symfony4 /home/project/kimai2/public && \
    sed -i 's|listen 80;|listen 8080;|' /etc/nginx/conf.d/default.conf && \
    sed -i -e 's/^memory_limit =.*/memory_limit = 3072M/' /etc/php7/php.ini && \
    sed -i -e 's/^session.gc_maxlifetime =.*/session.gc_maxlifetime = 3600/' /etc/php7/php.ini && \
    php-ext.sh enable 'session pdo mysqlnd pdo_mysql sqlite3 pdo_sqlite apcu intl opcache curl gd fileinfo xmlreader' && \
    sed -i '/docker_realip/s/#//' /etc/nginx/conf.d/default.conf && \
    sed -i 's|;opcache.memory_consumption=128|opcache.memory_consumption=64|' /etc/php7/php.ini && \
    sed -i 's|;opcache.max_accelerated_files=10000|opcache.max_accelerated_files=1000|' /etc/php7/php.ini && \
    sed -i 's|;opcache.validate_timestamps=1|opcache.validate_timestamps=0|' /etc/php7/php.ini && \
    sed -i 's|;opcache.interned_strings_buffer=8|opcache.interned_strings_buffer=16|' /etc/php7/php.ini && \
    echo "env[DATABASE_URL]=\$DATABASE_URL" >>/etc/php7/php-fpm.d/www.conf && \
    echo "env[APP_SECRET]=\$APP_SECRET" >>/etc/php7/php-fpm.d/www.conf && \
    echo "env[TRUSTED_PROXIES]=\$TRUSTED_PROXIES" >>/etc/php7/php-fpm.d/www.conf && \
    echo "env[TRUSTED_HOSTS]=\$TRUSTED_HOSTS" >>/etc/php7/php-fpm.d/www.conf && \
    echo "env[MAILER_FROM]=\$MAILER_FROM" >>/etc/php7/php-fpm.d/www.conf && \
    echo "env[MAILER_URL]=\$MAILER_URL" >>/etc/php7/php-fpm.d/www.conf && \
    echo "env[TZ]=\$TZ" >>/etc/php7/php-fpm.d/www.conf

RUN set -xe && \
    git clone --depth 1 https://github.com/mxgross/EasyBackupBundle.git /opt/kimai2/plugins/EasyBackupBundle/ && \
    cd /opt/kimai2/plugins/EasyBackupBundle/ && \
    git checkout 491fbe746807a4f2c52a3bcc8e0bf7dfc6883028 && \
    git clone --depth 1 https://github.com/Keleo/CustomCSSBundle.git /opt/kimai2/plugins/CustomCSSBundle/ && \
    cd /opt/kimai2/plugins/CustomCSSBundle/ && \
    git checkout 61120d1f9dbbfd847e036dc6e335ceeb18d23ff2 && \
    git clone --depth 1 https://github.com/fungus75/ReadOnlyAccessBundle.git /opt/kimai2/plugins/ReadOnlyAccessBundle/ && \
    cd /opt/kimai2/plugins/ReadOnlyAccessBundle/ && \
    git checkout bfc5110dbfc3cc42be26874748cbc7f7592e3c1e && \
    git clone --depth 1 https://github.com/Keleo/RecalculateRatesBundle.git /opt/kimai2/plugins/RecalculateRatesBundle/ && \
    cd /opt/kimai2/plugins/RecalculateRatesBundle/ && \
    git checkout 12112a94965c613f65f6d1bd069dcf6f72f93a43 && \
    git clone https://gitlab.com/hmr-it/kimai2plugins/EmptyDescriptionCheckerBundle.git  /opt/kimai2/plugins/EmptyDescriptionCheckerBundle/ && \
    cd /opt/kimai2/plugins/EmptyDescriptionCheckerBundle/ && \
    git checkout eb10f4ea247d05f4a97e40cf4929258f324f2c92 && \
    find /opt/kimai2/plugins/ -type d -name Tests -exec rm -rf "{}" \; || true && \
    chown -R project:project /opt/kimai2/

WORKDIR /home/project/kimai2/

RUN set -xe && \
    git clone --branch ${KIMAI} --depth 1 https://github.com/kevinpapst/kimai2.git /home/project/kimai2/ && \
    rm -Rf /home/project/kimai2/tests/ && \
    mkdir -p /opt/kimai2/ && \
    echo $KIMAI >/opt/kimai2/kimai_version

RUN set -xe && \
    sed -i '/polyfill-iconv/d' composer.json && \
    composer config platform.php "7.3" && \
    composer config platform.ext-iconv "7.3" && \
    composer require --update-no-dev symfony/polyfill-iconv && \
    COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev --no-progress --optimize-autoloader --no-interaction && \
    echo "kimai:" >./config/packages/local.yaml && \
    find /home/project/kimai2/vendor/ -name 'CHANGELOG.md' -delete || true && \
    find /home/project/kimai2/vendor/ -name 'README.md' -delete || true && \
    find /home/project/kimai2/vendor/ -type d -name Tests -exec rm -rf "{}" \; || true && \
    chown -R project:project /home/project/kimai2/

COPY BUILD /
COPY entrypoint.sh /usr/sbin/
ENTRYPOINT ["/usr/sbin/entrypoint.sh"]
CMD ["web"]

VOLUME ["/home/project/kimai2/var/"]

