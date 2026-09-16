<?php
// api/restore_snapshot.php - Secure Snapshot Restore Endpoint
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

require_once __DIR__ . '/../config/env.php';

if (defined('APP_ENV') && APP_ENV === 'production') {
    http_response_code(403);
    echo json_encode([
        'success' => false,
        'message' => 'SNAPSHOT RESTORE DENIED: Overwriting production data with snapshot files is prohibited.'
    ]);
    exit();
}

require_once __DIR__ . '/../config/db.php';

try {
    $restored = restore_db_snapshot($pdo);
    $total_users = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
    $student_count = (int)$pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student'")->fetchColumn();
    
    echo json_encode([
        'success' => $restored,
        'message' => $restored ? "Database snapshot restored successfully!" : "Failed to restore snapshot.",
        'total_users' => $total_users,
        'student_count' => $student_count
    ]);
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => "Error: " . $e->getMessage()
    ]);
}
?>
