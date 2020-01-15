FROM php:7.4-apache

RUN apt-get update && apt-get install -y \
        unzip \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libaio1 \
        libldap2-dev \
    && docker-php-ext-install -j$(nproc) iconv gettext \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo pdo_mysql mysqli bcmath \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install ldap

# Install XDebug - Required for code coverage in PHPUnit
RUN yes | pecl install xdebug \
    && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_enable=on" >> /usr/local/etc/php/conf.d/xdebug.ini \
    && echo "xdebug.remote_autostart=off" >> /usr/local/etc/php/conf.d/xdebug.ini

# Copy over the php conf
COPY docker-php.conf /etc/apache2/conf-enabled/docker-php.conf

# Copy over the php ini
COPY docker-php.ini $PHP_INI_DIR/conf.d/

# Set the timezone
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN printf "log_errors = On \nerror_log = /dev/stderr\n" > /usr/local/etc/php/conf.d/php-logs.ini

# Enable mod_rewrite
RUN a2enmod rewrite

# Install Oracle instantclient
ADD instantclient-basiclite-linux.x64-19.5.0.0.0dbru.zip /tmp/
ADD instantclient-sdk-linux.x64-19.5.0.0.0dbru.zip /tmp/
ADD instantclient-sqlplus-linux.x64-19.5.0.0.0dbru.zip /tmp/

RUN unzip /tmp/instantclient-basiclite-linux.x64-19.5.0.0.0dbru.zip -d /usr/local/
RUN unzip /tmp/instantclient-sdk-linux.x64-19.5.0.0.0dbru.zip -d /usr/local/
RUN unzip /tmp/instantclient-sqlplus-linux.x64-19.5.0.0.0dbru.zip -d /usr/local/

ENV LD_LIBRARY_PATH /usr/local/instantclient_19_5/

RUN ln -s /usr/local/instantclient_19_5 /usr/local/instantclient
RUN ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus

RUN echo 'export LD_LIBRARY_PATH="/usr/local/instantclient"' >> /root/.bashrc
RUN echo 'umask 002' >> /root/.bashrc

RUN echo 'instantclient,/usr/local/instantclient' | pecl install oci8
RUN echo "extension=oci8.so" > /usr/local/etc/php/conf.d/php-oci8.ini

# Install Composer
ENV COMPOSER_HOME /composer
ENV PATH ./vendor/bin:/composer/vendor/bin:$PATH
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer --version

# Add the files and set permissions
WORKDIR /var/www/html
ADD . /var/www/html
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80