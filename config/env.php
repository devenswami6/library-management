<?php
// config/env.php - Centralized Environment Configuration
require_once __DIR__ . '/tenant_config.php';

if (!defined('APP_ENV')) {
    define('APP_ENV', getenv('APP_ENV') ?: 'production');
}

if (!defined('DB_PATH')) {
    if (getenv('DB_PATH')) {
        define('DB_PATH', getenv('DB_PATH'));
    } elseif (defined('APP_ENV') && APP_ENV === 'development') {
        define('DB_PATH', __DIR__ . '/../library.db');
    } else {
        // Authoritative Production Database Path on Render Persistent Disk
        define('DB_PATH', '/var/www/html/data/library.db');
    }
}

if (!defined('ALLOW_DB_RESET')) {
    define('ALLOW_DB_RESET', getenv('ALLOW_DB_RESET') === 'true');
}

if (!class_exists('ApiConfig')) {
    class ApiConfig {
        public static $baseUrl = 'https://library-management-hmwx.onrender.com';
    }
}
?>
