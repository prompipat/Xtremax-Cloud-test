<?php
define('WP_USE_THEMES', false);
require '/var/www/html/wp-load.php';
global $wpdb;
$wpdb->suppress_errors(true);
$healthy = is_blog_installed() && file_exists(__DIR__ . '/wp-content/.xtremax-content-ready') && $wpdb->get_var('SELECT 1') === '1';
header('Content-Type: text/plain');
header('Cache-Control: no-store');
http_response_code($healthy ? 200 : 503);
echo $healthy ? "ready\n" : "not ready\n";
