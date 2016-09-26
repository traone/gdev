FROM jwilder/nginx-proxy
MAINTAINER Onni Hakala - Geniem Oy

# Add bigger timeouts and filesizes for nginx-proxy
COPY custom-proxy.conf /etc/nginx/conf.d/custom-proxy.conf

# Add custom jwilder/nginx modifications
COPY app /app/

# Copy custom index.html to guide user in case of errors
COPY error_pages /var/www/error_pages/
