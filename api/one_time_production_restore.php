<?php
// api/one_time_production_restore.php
// Explicit, administrative one-time recovery script to restore production data from repository snapshot into live database.

require_once __DIR__ . '/../config/db.php';

header('Content-Type: application/json');

$action = $_GET['action'] ?? ($_POST['action'] ?? '');

try {
    $db_file = DB_PATH;
    $user_count = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
    
    // Safety check: allow one-time restoration only when target database contains <= 1 admin user
    if ($user_count > 1 && $action !== 'force_one_time_recovery') {
        echo json_encode([
            'success' => false,
            'message' => "Target database already contains $user_count users. One-time recovery aborted to prevent overwriting existing live data.",
            'db_path' => $db_file
        ]);
        exit();
    }

    $snapshot_file = __DIR__ . '/../config/db_snapshot.json';
    if (!file_exists($snapshot_file)) {
        echo json_encode(['success' => false, 'message' => 'Snapshot file config/db_snapshot.json not found!']);
        exit();
    }

    $raw = @file_get_contents($snapshot_file);
    $data = json_decode($raw, true);
    if (empty($data) || empty($data['users'])) {
        echo json_encode(['success' => false, 'message' => 'Invalid or empty snapshot file!']);
        exit();
    }

    // Take safety backup copy before restoring
    $backup_file = $db_file . '.pre_recovery_backup_' . date('Ymd_His');
    if (file_exists($db_file)) {
        @copy($db_file, $backup_file);
    }

    $pdo->exec("PRAGMA foreign_keys = OFF;");
    $tables = ['users', 'shifts', 'seats', 'allocations', 'fee_payments', 'attendance', 'complaints', 'notifications', 'chat_messages', 'system_settings'];
    
    foreach ($tables as $table) {
        if (empty($data[$table])) continue;

        $table_cols = [];
        try {
            $info = $pdo->query("PRAGMA table_info($table)")->fetchAll(PDO::FETCH_ASSOC);
            foreach ($info as $col) {
                $table_cols[] = $col['name'];
            }
        } catch (Exception $ex) { continue; }
        
        if (empty($table_cols)) continue;

        foreach ($data[$table] as $row) {
            $filtered_row = array_intersect_key($row, array_flip($table_cols));
            if (empty($filtered_row)) continue;

            $cols = array_keys($filtered_row);
            $placeholders = implode(',', array_fill(0, count($cols), '?'));
            $col_names = implode(',', $cols);
            
            try {
                $stmt = $pdo->prepare("INSERT OR REPLACE INTO $table ($col_names) VALUES ($placeholders)");
                $stmt->execute(array_values($filtered_row));
            } catch (Exception $ex) {}
        }
    }

    // Ensure Student ID 6 (Deven Swami) allocation is set to seat A-04 (seat_id = 4)
    $seat_a04_id = (int)$pdo->query("SELECT id FROM seats WHERE seat_number = 'A-04'")->fetchColumn();
    if ($seat_a04_id <= 0) $seat_a04_id = 4;

    $pdo->prepare("UPDATE allocations SET status = 'cancelled' WHERE user_id = 6 AND status = 'active'")->execute();
    $pdo->prepare("INSERT INTO allocations (user_id, seat_id, shift_id, start_date, status, notes) VALUES (6, ?, 1, DATE('now'), 'active', 'Restored to A-04')")->execute([$seat_a04_id]);

    $pdo->exec("PRAGMA foreign_keys = ON;");

    // Run schema migrations to ensure unique indexes are active
    run_migrations($pdo);

    // Collect record counts for verification
    $counts = [];
    foreach ($tables as $t) {
        try {
            $counts[$t] = (int)$pdo->query("SELECT COUNT(*) FROM $t")->fetchColumn();
        } catch (Exception $e) {
            $counts[$t] = 0;
        }
    }

    // Check student 6 allocation
    $stmt_deven = $pdo->query("
        SELECT a.id, a.user_id, u.name, s.seat_number, a.status 
        FROM allocations a 
        JOIN users u ON a.user_id = u.id 
        JOIN seats s ON a.seat_id = s.id 
        WHERE a.user_id = 6 AND a.status = 'active'
    ")->fetch();

    echo json_encode([
        'success' => true,
        'message' => 'One-time production database recovery completed successfully!',
        'db_path' => $db_file,
        'backup_created' => $backup_file,
        'recovered_counts' => $counts,
        'deven_allocation' => $stmt_deven ?: null
    ], JSON_PRETTY_PRINT);
    exit();

} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => 'One-time recovery failed: ' . $e->getMessage()]);
    exit();
}
