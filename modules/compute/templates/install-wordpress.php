<?php
define('WP_INSTALLING', true);
require '/var/www/html/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';
add_filter('pre_wp_mail', '__return_false');
if (!is_blog_installed()) {
    $credentials = json_decode(file_get_contents('/etc/wordpress/credentials.json'), true, 512, JSON_THROW_ON_ERROR);
    $configuration = json_decode(file_get_contents('/opt/xtremax/config.json'), true, 512, JSON_THROW_ON_ERROR);
    $result = wp_install('School website', $credentials['admin_username'], $configuration['admin_email'], true, '', $credentials['admin_password'], 'en_US');
    unset($credentials);
    if (is_wp_error($result) || !is_blog_installed()) {
        fwrite(STDERR, "WordPress initialization failed\n");
        exit(1);
    }
}
