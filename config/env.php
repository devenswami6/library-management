<?php
// config/env.php - Centralized Environment Configuration

if (!defined('APP_ENV')) {
    define('APP_ENV', getenv('APP_ENV') ?: 'production');
}

if (!defined('DB_PATH')) {
    define('DB_PATH', getenv('DB_PATH') ?: (__DIR__ . '/../library.db'));
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
