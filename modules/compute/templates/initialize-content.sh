#!/bin/bash
set -euo pipefail
if [ ! -f /var/www/html/wp-content/.xtremax-content-ready ]; then
    cp -r /opt/xtremax/release/wordpress/wp-content/. /var/www/html/wp-content/
    touch /var/www/html/wp-content/.xtremax-content-ready
fi
php /opt/xtremax/install-wordpress.php
