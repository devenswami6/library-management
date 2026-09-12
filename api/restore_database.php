<?php
// api/restore_database.php - Standalone Database Restore Endpoint
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if (isset($_FILES['backup_file']) && $_FILES['backup_file']['error'] === UPLOAD_ERR_OK) {
    $tmp_name = $_FILES['backup_file']['tmp_name'];
    $db_file = __DIR__ . '/../library.db';
    try {
        $test_pdo = new PDO("sqlite:" . $tmp_name);
        $count = (int)$test_pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
        $test_pdo = null;

        if (copy($tmp_name, $db_file)) {
            echo json_encode(['success' => true, 'message' => "Database successfully restored ($count users restored)!"]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to copy uploaded database file.']);
        }
    } catch (Exception $e) {
        echo json_encode(['success' => false, 'message' => 'Invalid SQLite database backup file: ' . $e->getMessage()]);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'No database backup file uploaded.']);
}
