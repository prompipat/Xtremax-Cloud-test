<?php
$runtime = json_decode(file_get_contents('/etc/wordpress/credentials.json'), true, 512, JSON_THROW_ON_ERROR);
$settings = json_decode(file_get_contents('/opt/xtremax/config.json'), true, 512, JSON_THROW_ON_ERROR);
define('DB_NAME', 'wordpress');
define('DB_USER', $runtime['username']);
define('DB_PASSWORD', $runtime['password']);
define('DB_HOST', $settings['db_address'] . ':3306');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL | MYSQLI_CLIENT_SSL_VERIFY_SERVER_CERT);
foreach ($runtime['salts'] as $key => $value) {
    define($key, $value);
}
define('WP_HOME', $settings['site_url']);
define('WP_SITEURL', $settings['site_url']);
define('FORCE_SSL_ADMIN', true);
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true);
define('AUTOMATIC_UPDATER_DISABLED', true);
define('WP_DEBUG', false);
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
$table_prefix = 'wp_';
unset($runtime);
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
