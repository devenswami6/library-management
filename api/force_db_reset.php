<?php
// api/force_db_reset.php - Force clean database reset and master re-seed
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

$db_file = __DIR__ . '/../library.db';
if (file_exists($db_file)) {
    @unlink($db_file);
}

require_once __DIR__ . '/../config/db.php';

$user_count = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
$student_count = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student'")->fetchColumn();
$approved_students = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student' AND is_deleted = 0 AND (status = 'approved' OR status = 'active')")->fetchColumn();

echo json_encode([
    'success' => true,
    'message' => "Database reset and master re-seeded successfully!",
    'total_users' => $user_count,
    'student_count' => $student_count,
    'approved_students' => $approved_students
]);
