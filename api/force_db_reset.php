<?php
// api/force_db_reset.php - Secure Database Reset Endpoint
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

require_once __DIR__ . '/../config/env.php';

// Fail-safe protection: Reject reset unless ALLOW_DB_RESET is explicitly set to true
if (!defined('ALLOW_DB_RESET') || ALLOW_DB_RESET !== true) {
    http_response_code(403);
    echo json_encode([
        'success' => false,
        'message' => 'DATABASE RESET DENIED: Destructive operations are strictly disabled in production.'
    ]);
    exit();
}

$db_file = DB_PATH;
if (file_exists($db_file)) {
    @unlink($db_file);
}

require_once __DIR__ . '/../config/db.php';

$user_count = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
$student_count = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student'")->fetchColumn();
$approved_students = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student' AND (is_deleted IS NULL OR is_deleted = 0) AND (status = 'approved' OR status = 'active')")->fetchColumn();

echo json_encode([
    'success' => true,
    'message' => "Database reset completed safely.",
    'total_users' => $user_count,
    'student_count' => $student_count,
    'approved_students' => $approved_students
]);
?>
