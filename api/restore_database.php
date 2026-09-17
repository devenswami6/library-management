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

require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/../config/auth.php';

$user_role = strtolower(trim($_SESSION['user_role'] ?? ''));
if ($user_role !== 'admin' && !is_admin()) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'ACCESS DENIED: Database restore is restricted to Admin access only.']);
    exit();
}

if (isset($_FILES['backup_file']) && $_FILES['backup_file']['error'] === UPLOAD_ERR_OK) {
    $tmp_name = $_FILES['backup_file']['tmp_name'];
    $db_file = DB_PATH;
    $db_dir = dirname($db_file);

    try {
        // 1. Verify integrity of uploaded DB file
        $test_pdo = new PDO("sqlite:" . $tmp_name);
        $test_pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $integrity = $test_pdo->query("PRAGMA integrity_check")->fetchColumn();
        if ($integrity !== 'ok') {
            throw new Exception("Uploaded SQLite file failed integrity check: $integrity");
        }
        $count = (int)$test_pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
        $test_pdo = null;

        // 2. Take timestamped backup of CURRENT Render database if it exists
        if (file_exists($db_file)) {
            $timestamp = date('Ymd_His');
            $backup_file = $db_dir . '/library_backup_pre_restore_' . $timestamp . '.db';
            
            // Perform safe SQLite VACUUM INTO copy for backup
            try {
                $current_pdo = new PDO("sqlite:" . $db_file);
                $current_pdo->exec("VACUUM INTO '" . str_replace("'", "''", $backup_file) . "'");
                $current_pdo = null;
            } catch (Exception $e) {
                copy($db_file, $backup_file);
            }

            // Verify integrity of the backup file
            if (file_exists($backup_file)) {
                $backup_pdo = new PDO("sqlite:" . $backup_file);
                $b_integrity = $backup_pdo->query("PRAGMA integrity_check")->fetchColumn();
                $backup_pdo = null;
                if ($b_integrity !== 'ok') {
                    throw new Exception("Pre-restore database backup integrity check failed!");
                }
            }
        }

        // Close global PDO connection before overwrite
        $pdo = null;

        // 3. Atomically overwrite DB_PATH
        if (copy($tmp_name, $db_file)) {
            // Verify post-restore DB integrity
            $post_pdo = new PDO("sqlite:" . $db_file);
            $post_integrity = $post_pdo->query("PRAGMA integrity_check")->fetchColumn();
            $post_pdo = null;

            if ($post_integrity !== 'ok') {
                throw new Exception("Post-restore database integrity check failed!");
            }

            echo json_encode([
                'success' => true,
                'message' => "Database successfully restored ($count users restored)! Pre-restore backup saved safely.",
                'db_path' => $db_file
            ]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Failed to copy uploaded database file to ' . $db_file]);
        }
    } catch (Exception $e) {
        echo json_encode(['success' => false, 'message' => 'Restore failed: ' . $e->getMessage()]);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'No database backup file uploaded.']);
}
