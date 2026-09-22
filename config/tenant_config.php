<?php
// config/tenant_config.php - Centralized Tenant Environment Configuration

if (!defined('LIBRARY_NAME')) {
    define('LIBRARY_NAME', getenv('LIBRARY_NAME') ?: 'Keshav Library & Study Center');
}

if (!defined('LIBRARY_SHORT_NAME')) {
    define('LIBRARY_SHORT_NAME', getenv('LIBRARY_SHORT_NAME') ?: 'StudySpace');
}

if (!defined('LIBRARY_TAGLINE')) {
    define('LIBRARY_TAGLINE', getenv('LIBRARY_TAGLINE') ?: 'SELF STUDY HALL');
}

if (!defined('LIBRARY_PHONE')) {
    define('LIBRARY_PHONE', getenv('LIBRARY_PHONE') ?: '+91 98765 43210');
}

if (!defined('LIBRARY_EMAIL')) {
    define('LIBRARY_EMAIL', getenv('LIBRARY_EMAIL') ?: 'support@studyspace.com');
}

if (!defined('LIBRARY_ADDRESS')) {
    define('LIBRARY_ADDRESS', getenv('LIBRARY_ADDRESS') ?: 'Near City Park, Main Road');
}

if (!defined('LIBRARY_LAT')) {
    define('LIBRARY_LAT', (float)(getenv('LIBRARY_LAT') ?: 28.0087395));
}

if (!defined('LIBRARY_LNG')) {
    define('LIBRARY_LNG', (float)(getenv('LIBRARY_LNG') ?: 73.2924508));
}

if (!defined('GEOFENCE_RADIUS_METERS')) {
    define('GEOFENCE_RADIUS_METERS', (float)(getenv('GEOFENCE_RADIUS_METERS') ?: 50.0));
}

if (!defined('PRIMARY_COLOR')) {
    define('PRIMARY_COLOR', getenv('PRIMARY_COLOR') ?: '#1D4ED8');
}

if (!defined('FOOTER_CREDIT')) {
    define('FOOTER_CREDIT', getenv('FOOTER_CREDIT') ?: 'Ramxonwebwork');
}

if (!defined('LIBRARY_ICON_CLASS')) {
    define('LIBRARY_ICON_CLASS', getenv('LIBRARY_ICON_CLASS') ?: 'fas fa-book-reader');
}
