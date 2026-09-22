<?php
// api/debug_env.php - Read-only Forensic Audit Tool
require_once __DIR__ . '/../config/db.php';
header('Content-Type: application/json');

function inspect_sqlite_db($path) {
    if (!file_exists($path) || !is_file($path)) {
        return ['exists' => false];
    }

    $size = filesize($path);
    $mtime = date('Y-m-d H:i:s', filemtime($path));
    $realpath = realpath($path);

    $info = [
        'path' => $path,
        'realpath' => $realpath,
        'exists' => true,
        'size_bytes' => $size,
        'size_formatted' => round($size / 1024, 2) . ' KB',
        'modified_time' => $mtime
    ];

    try {
        $temp_pdo = new PDO("sqlite:" . $path);
        $temp_pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

        $info['integrity_check'] = $temp_pdo->query("PRAGMA integrity_check")->fetchColumn();
        $info['journal_mode'] = $temp_pdo->query("PRAGMA journal_mode")->fetchColumn();

        $tables = $temp_pdo->query("SELECT name FROM sqlite_master WHERE type='table'")->fetchAll(PDO::FETCH_COLUMN);
        $info['tables'] = $tables;

        $table_counts = [];
        foreach ($tables as $tbl) {
            try {
                $table_counts[$tbl] = (int)$temp_pdo->query("SELECT COUNT(*) FROM `$tbl`")->fetchColumn();
            } catch (Exception $ex) {
                $table_counts[$tbl] = 'ERROR: ' . $ex->getMessage();
            }
        }
        $info['table_counts'] = $table_counts;

        if (in_array('schema_migrations', $tables)) {
            try {
                $info['schema_version'] = (int)$temp_pdo->query("SELECT MAX(version) FROM schema_migrations")->fetchColumn();
                $info['migrations_list'] = $temp_pdo->query("SELECT version, executed_at FROM schema_migrations ORDER BY version ASC")->fetchAll(PDO::FETCH_ASSOC);
            } catch (Exception $ex) {
                $info['schema_version'] = 0;
            }
        }

        if (in_array('users', $tables)) {
            try {
                $info['deven_swami'] = $temp_pdo->query("SELECT id, name, email, phone, role, status FROM users WHERE id = 6 OR name LIKE '%Deven%'")->fetchAll(PDO::FETCH_ASSOC);
                $info['all_users'] = $temp_pdo->query("SELECT id, name, email, phone, role, status, is_deleted FROM users ORDER BY id ASC")->fetchAll(PDO::FETCH_ASSOC);
            } catch (Exception $ex) {}
        }

        if (in_array('allocations', $tables) && in_array('seats', $tables)) {
            try {
                $info['deven_a04_check'] = $temp_pdo->query("
                    SELECT a.id as alloc_id, u.id as user_id, u.name as user_name, s.seat_number, a.status as alloc_status
                    FROM allocations a
                    JOIN users u ON a.user_id = u.id
                    JOIN seats s ON a.seat_id = s.id
                    WHERE u.id = 6 OR s.seat_number IN ('A-03', 'A-04')
                ")->fetchAll(PDO::FETCH_ASSOC);
            } catch (Exception $ex) {}
        }
    } catch (Exception $e) {
        $info['error'] = $e->getMessage();
    }

    return $info;
}

// 1. Storage Directories Inspection
$data_dir = '/var/www/html/data';
$html_dir = '/var/www/html';

$data_files = [];
if (file_exists($data_dir) && is_dir($data_dir)) {
    $files = scandir($data_dir);
    foreach ($files as $f) {
        if ($f === '.' || $f === '..') continue;
        $full = "$data_dir/$f";
        $data_files[] = [
            'name' => $f,
            'path' => $full,
            'is_dir' => is_dir($full),
            'size_bytes' => is_file($full) ? filesize($full) : 0,
            'modified_time' => date('Y-m-d H:i:s', filemtime($full))
        ];
    }
}

$html_db_files = [];
if (file_exists($html_dir) && is_dir($html_dir)) {
    $files = scandir($html_dir);
    foreach ($files as $f) {
        if ($f === '.' || $f === '..') continue;
        if (str_contains($f, '.db') || str_contains($f, '.sqlite')) {
            $full = "$html_dir/$f";
            $html_db_files[] = [
                'name' => $f,
                'path' => $full,
                'size_bytes' => filesize($full),
                'modified_time' => date('Y-m-d H:i:s', filemtime($full))
            ];
        }
    }
}

// 2. Inspect Live Database File
$live_db_info = inspect_sqlite_db(DB_PATH);

// 3. Inspect All Other DB Files Found in Storage
$other_db_inspections = [];
foreach ($data_files as $df) {
    if (!$df['is_dir'] && (str_contains($df['name'], '.db') || str_contains($df['name'], '.sqlite'))) {
        $other_db_inspections[$df['name']] = inspect_sqlite_db($df['path']);
    }
}
foreach ($html_db_files as $hf) {
    $other_db_inspections['html_' . $hf['name']] = inspect_sqlite_db($hf['path']);
}

echo json_encode([
    'audit_timestamp' => date('Y-m-d H:i:s'),
    'DB_PATH_constant' => DB_PATH,
    'data_dir_exists' => file_exists($data_dir),
    'data_dir_contents' => $data_files,
    'html_db_files' => $html_db_files,
    'live_db_inspection' => $live_db_info,
    'all_db_files_inspected' => $other_db_inspections
], JSON_PRETTY_PRINT);
