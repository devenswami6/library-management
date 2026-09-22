<?php
// api/recovery_diagnostic.php
// Temporary diagnostic endpoint for inspecting production filesystem state without modifying data.

require_once __DIR__ . '/../config/env.php';

header('Content-Type: application/json');

// Authorization Check:
// Valid Render environment token supplied ONLY in X-Recovery-Token HTTP header
$is_authorized = false;

$env_token = getenv('RECOVERY_ADMIN_TOKEN');
$header_token = $_SERVER['HTTP_X_RECOVERY_TOKEN'] ?? '';

if (!empty($env_token) && !empty($header_token)) {
    if (hash_equals($env_token, $header_token)) {
        $is_authorized = true;
    }
}

// Fallback session check if session already active without loading database connection
if (!$is_authorized && session_status() === PHP_SESSION_ACTIVE && isset($_SESSION['user']['role']) && $_SESSION['user']['role'] === 'admin') {
    $is_authorized = true;
}

if (!$is_authorized) {
    http_response_code(403);
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized access. Valid recovery token required.'
    ]);
    exit();
}

$db_path = DB_PATH;
$db_dir = dirname($db_path);

$db_exists = file_exists($db_path);
$db_size = $db_exists ? @filesize($db_path) : null;

$marker_file = $db_dir . '/.production_recovery_completed';
$marker_exists = file_exists($marker_file);
$marker_size = $marker_exists ? @filesize($marker_file) : null;
$marker_contents = $marker_exists ? @file_get_contents($marker_file) : null;

$lock_file = $db_dir . '/.production_recovery.lock';
$lock_exists = file_exists($lock_file);

echo json_encode([
    'success' => true,
    'db_path' => $db_path,
    'db_exists' => $db_exists,
    'db_size' => $db_size,
    'marker_exists' => $marker_exists,
    'marker_size' => $marker_size,
    'marker_contents' => $marker_contents,
    'lock_exists' => $lock_exists
], JSON_PRETTY_PRINT);
