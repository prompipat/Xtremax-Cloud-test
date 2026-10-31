<?php
// Check the PHP 8.3 client flags used by the actual WordPress configuration.
if (!defined('MYSQLI_CLIENT_SSL') || !defined('MYSQLI_CLIENT_SSL_VERIFY_SERVER_CERT')) {
    throw new RuntimeException('Required MySQL TLS flags are unavailable');
}
$flags = MYSQLI_CLIENT_SSL | MYSQLI_CLIENT_SSL_VERIFY_SERVER_CERT;
if (($flags & MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT) !== 0) {
    throw new RuntimeException('Client flags unexpectedly disable certificate verification');
}
echo "PHP mysqli TLS verification flags: PASS\n";
