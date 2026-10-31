#!/bin/bash
set -euo pipefail
# No shell tracing: runtime secrets must never enter cloud-init/journal logs.
umask 027
dnf install -y httpd php8.3 php8.3-cli php8.3-fpm php8.3-mysqlnd php8.3-gd php8.3-mbstring php8.3-xml php8.3-opcache php8.3-intl amazon-efs-utils python3
test "$(id -u apache)" = 48
systemctl enable --now amazon-ssm-agent

setting() { python3 -c 'import json,sys; print(json.load(open("/opt/xtremax/config.json"))[sys.argv[1]])' "$1"; }
fetch_verified() {
    local url="$1" expected="$2" destination="$3"
    curl --fail --silent --show-error --location --retry 5 --connect-timeout 10 --max-time 180 "$url" --output "$destination"
    printf '%s  %s\n' "$expected" "$destination" | sha256sum -c -
}

install -d -m 0755 /var/www/html /opt/xtremax/release
fetch_verified "$(setting wordpress_url)" "$(setting wordpress_sha256)" /opt/xtremax/wordpress.tar.gz
fetch_verified "$(setting rds_ca_url)" "$(setting rds_ca_sha256)" /etc/pki/ca-trust/source/anchors/xtremax-rds.pem
update-ca-trust
tar --no-same-owner -xzf /opt/xtremax/wordpress.tar.gz -C /opt/xtremax/release
# Core is local and immutable to the web user; shared content is seeded under a lock.
tar --no-same-owner --exclude='wordpress/wp-content' -xzf /opt/xtremax/wordpress.tar.gz --strip-components=1 -C /var/www/html
install -d -m 0755 /var/www/html/wp-content
efs_line="$(setting efs_id):/ /var/www/html/wp-content efs _netdev,tls,iam,accesspoint=$(setting efs_access_point_id) 0 0"
grep -Fqx "$efs_line" /etc/fstab || printf '%s\n' "$efs_line" >> /etc/fstab
mountpoint -q /var/www/html/wp-content || mount /var/www/html/wp-content
python3 /opt/xtremax/credentials.py
install -m 0640 -o root -g apache /opt/xtremax/wp-config.php /var/www/html/wp-config.php
install -m 0644 -o root -g root /opt/xtremax/health.php /var/www/html/health.php

cat > /etc/httpd/conf.d/wordpress.conf <<'APACHE'
ServerTokens Prod
ServerSignature Off
DirectoryIndex index.php
<Directory /var/www/html>
    AllowOverride None
    Require all granted
    Options -Indexes
    RewriteEngine On
    RewriteBase /
    RewriteRule ^index\.php$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /index.php [L]
    <FilesMatch "^(wp-config\.php|\..*)$">
        Require all denied
    </FilesMatch>
</Directory>
<Directory /var/www/html/wp-content/uploads>
    <FilesMatch "\.(php[0-9]?|phtml|phar)$">
        Require all denied
    </FilesMatch>
</Directory>
APACHE
cat > /etc/php.d/99-xtremax.ini <<'PHPINI'
expose_php = Off
display_errors = Off
log_errors = On
openssl.cafile = /etc/pki/tls/certs/ca-bundle.crt
PHPINI
if command -v setsebool >/dev/null 2>&1 && selinuxenabled 2>/dev/null; then
    setsebool -P httpd_can_network_connect_db on
    setsebool -P httpd_use_nfs on
fi
runuser -u apache -- flock -w 600 /var/www/html/wp-content/.xtremax-initialize.lock /opt/xtremax/initialize-content.sh
httpd -t
systemctl enable --now php-fpm httpd
curl --fail --silent --show-error http://127.0.0.1/health.php > /dev/null
