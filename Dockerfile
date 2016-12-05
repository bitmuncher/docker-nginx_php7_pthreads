FROM debian:jessie
MAINTAINER Frank Fuhrmann <frank.fuhrmann@mailbox.org>

ENV PHP_VERSION           7.0.13

ENV DEBIAN_FRONTEND       noninteractive
ENV TERM                  xterm

# system update
RUN apt-get update
RUN apt-get -y upgrade

# install dependencies and nginx
RUN echo 'deb http://nginx.org/packages/debian/ jessie nginx' >> /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ABF5BD827BD9BF62
RUN apt-get update
RUN apt-get -y install --no-install-recommends \
    nano \
    less \
    supervisor \
    nginx \
    pwgen \
    wget \
    autoconf \
    build-essential \
    libfcgi-dev \
    libfcgi0ldbl \
    libjpeg62-turbo \
    libmcrypt-dev \
    libssl-dev \
    libc-client2007e \
    libc-client2007e-dev \
    libxml2-dev \
    libbz2-dev \
    libcurl4-openssl-dev \
    libjpeg-dev \
    libpng12-dev \
    libfreetype6-dev \
    libxslt1-dev 
RUN ln -s /usr/lib/libc-client.a /usr/lib/x86_64-linux-gnu/libc-client.a

# install php
RUN mkdir -p /opt/php-$PHP_VERSION
RUN mkdir /usr/local/src/php7-build
RUN cd /usr/local/src/php7-build && \
    wget http://de.php.net/get/php-$PHP_VERSION.tar.bz2/from/this/mirror -O php-$PHP_VERSION.tar.bz2 && \
    tar -xjvf php-$PHP_VERSION.tar.bz2 && \
    cd php-$PHP_VERSION && \
    ./configure \
        --prefix=/opt/php-$PHP_VERSION \
        --with-config-file-path=/opt/php-7.0.13/lib/php.ini \
        --enable-maintainer-zts \
        --with-zlib-dir \
        --with-freetype-dir \
        --enable-mbstring \
        --with-libxml-dir=/usr \
        --enable-soap \
        --with-mcrypt \
        --with-zlib \
        --with-gd \
        --disable-rpath \
        --enable-inline-optimization \
        --with-bz2 \
        --with-zlib \
        --enable-sockets \
        --enable-sysvsem \
        --enable-sysvshm \
        --enable-pcntl \
        --enable-mbregex \
        --enable-exif \
        --enable-bcmath \
        --with-mhash \
        --enable-zip \
        --with-pcre-regex \
        --with-pdo-mysql \
        --with-mysqli \
        --with-mysql-sock=/var/run/mysqld/mysqld.sock \
        --with-jpeg-dir=/usr \
        --with-png-dir=/usr \
        --enable-gd-native-ttf \
        --with-fpm-user=www-data \
        --with-fpm-group=www-data \
        --with-libdir=/lib/x86_64-linux-gnu \
        --enable-ftp \
        --with-gettext \
        --with-xmlrpc \
        --with-xsl \
        --enable-opcache \
		--enable-pthreads \
        --enable-fpm && \
    make && \
    make install

# cleanup
RUN apt-get -y clean
RUN echo -n > /var/lib/apt/extended_states
RUN rm -rf /var/lib/apt/lists/*
RUN rm -rf /usr/share/man/??
RUN rm -rf /usr/share/man/??_*
RUN rm -rf /usr/local/src/php7-build

# php production configuration
# RUN cp /usr/local/src/php7-build/php-$PHP_VERSION/php.ini-production /opt/php-$PHP_VERSION/lib/php.ini

# install pthreadas
RUN /opt/php-$PHP_VERSION/bin/pecl install pthreads

# FPM configuration
ADD conf/php-fpm.conf /opt/php-$PHP_VERSION/etc/php-fpm.conf
RUN sed -i "s/PHP_VERSION/$PHP_VERSION/g" /opt/php-$PHP_VERSION/etc/php-fpm.conf

COPY conf/www.conf /opt/php-$PHP_VERSION/etc/php-fpm.d/www.conf
RUN sed -i "s/PHP_VERSION/$PHP_VERSION/g" /opt/php-$PHP_VERSION/etc/php-fpm.d/www.conf

# PHP configuration
COPY conf/php.ini /opt/php-$PHP_VERSION/lib/php.ini
#RUN echo "extension=pthreads.so" >> /opt/php-$PHP_VERSION/lib/php.ini

# nginx configuration
COPY conf/nginx.conf /etc/nginx/nginx.conf
RUN chown -R www-data:www-data /var/log/nginx
RUN chown -R www-data:www-data /usr/share/nginx/html
RUN rm -Rf /etc/nginx/conf.d/*
RUN rm -Rf /etc/nginx/sites-available/default
RUN mkdir -p /etc/nginx/ssl/
COPY conf/nginx-site.conf /etc/nginx/conf.d/default.conf
RUN chown -R www-data:www-data /usr/share/nginx/html/
VOLUME /usr/share/nginx/html
#RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# supervisord configuration
COPY conf/supervisord.conf /etc/supervisord.conf
RUN sed -i "s/PHP_VERSION/$PHP_VERSION/g" /etc/supervisord.conf

# startup command
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

EXPOSE 443
EXPOSE 80

CMD ["/bin/bash", "/start.sh"]
