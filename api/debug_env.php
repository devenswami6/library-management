<?php
require_once __DIR__ . '/../config/db.php';
header('Content-Type: application/json');

$path1 = '/var/www/html/data/library.db';
$path2 = '/var/www/html/library.db';

echo json_encode([
    'DB_PATH_constant' => DB_PATH,
    'file_exists_DB_PATH' => file_exists(DB_PATH),
    'filesize_DB_PATH' => file_exists(DB_PATH) ? filesize(DB_PATH) : 0,
    'file_exists_path1' => file_exists($path1),
    'filesize_path1' => file_exists($path1) ? filesize($path1) : 0,
    'file_exists_path2' => file_exists($path2),
    'filesize_path2' => file_exists($path2) ? filesize($path2) : 0,
    'users_count' => (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn(),
], JSON_PRETTY_PRINT);
