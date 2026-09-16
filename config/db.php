<?php
// config/db.php - Database connection, non-destructive migrations, and production data safety
require_once __DIR__ . '/env.php';

$db_file = DB_PATH;
$db_dir = dirname($db_file);
if (!file_exists($db_dir)) {
    @mkdir($db_dir, 0777, true);
}

try {
    $pdo = new PDO("sqlite:" . $db_file);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->exec("PRAGMA foreign_keys = ON;");
    $pdo->exec("PRAGMA journal_mode = WAL;");
    $pdo->exec("PRAGMA synchronous = NORMAL;");
    $pdo->exec("PRAGMA busy_timeout = 10000;"); // Wait 10s on busy lock for 100+ concurrent users
    $pdo->exec("PRAGMA cache_size = -64000;"); // 64MB RAM Cache
    $pdo->exec("PRAGMA temp_store = MEMORY;");
} catch (PDOException $e) {
    die("Database Connection Error: " . $e->getMessage());
}

function save_db_snapshot($pdo) {
    if (defined('APP_ENV') && APP_ENV === 'production') {
        return; // Production mode strictly prevents modifying dev snapshot file
    }
    try {
        $snapshot_file = __DIR__ . '/db_snapshot.json';
        $user_count = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
        if (file_exists($snapshot_file)) {
            $existing_raw = @file_get_contents($snapshot_file);
            $existing_data = json_decode($existing_raw, true);
            $existing_user_count = !empty($existing_data['users']) ? count($existing_data['users']) : 0;
            if ($user_count == 0 && $existing_user_count > 0) {
                return; // Prevent saving an empty/corrupted user snapshot
            }
        }
        $tables = ['users', 'shifts', 'seats', 'allocations', 'fee_payments', 'attendance', 'complaints', 'notifications', 'chat_messages', 'system_settings'];
        $data = [];
        foreach ($tables as $t) {
            try {
                $data[$t] = $pdo->query("SELECT * FROM $t")->fetchAll(PDO::FETCH_ASSOC);
            } catch (Exception $e) {
                $data[$t] = [];
            }
        }
        @file_put_contents($snapshot_file, json_encode($data, JSON_PRETTY_PRINT));
    } catch (Exception $e) {}
}

register_shutdown_function(function() use ($pdo) {
    if (defined('APP_ENV') && APP_ENV === 'development' && isset($_SERVER['REQUEST_METHOD']) && in_array($_SERVER['REQUEST_METHOD'], ['POST', 'PUT', 'DELETE'])) {
        save_db_snapshot($pdo);
    }
});

function restore_db_snapshot($pdo) {
    if (defined('APP_ENV') && APP_ENV === 'production') {
        return false; // Production mode strictly forbids restoring snapshot JSON over live DB
    }
    $snapshot_file = __DIR__ . '/db_snapshot.json';
    if (!file_exists($snapshot_file)) return false;
    
    $raw = @file_get_contents($snapshot_file);
    if (empty($raw)) return false;
    
    $data = json_decode($raw, true);
    if (empty($data) || empty($data['users'])) return false;

    try {
        $pdo->exec("PRAGMA foreign_keys = OFF;");
        foreach ($data as $table => $rows) {
            if (empty($rows)) continue;
            
            $table_cols = [];
            try {
                $info = $pdo->query("PRAGMA table_info($table)")->fetchAll(PDO::FETCH_ASSOC);
                foreach ($info as $col) {
                    $table_cols[] = $col['name'];
                }
            } catch (Exception $ex) { continue; }
            
            if (empty($table_cols)) continue;

            foreach ($rows as $row) {
                $filtered_row = array_intersect_key($row, array_flip($table_cols));
                if (empty($filtered_row)) continue;

                $cols = array_keys($filtered_row);
                $placeholders = implode(',', array_fill(0, count($cols), '?'));
                $col_names = implode(',', $cols);
                
                try {
                    $stmt = $pdo->prepare("INSERT OR IGNORE INTO $table ($col_names) VALUES ($placeholders)");
                    $stmt->execute(array_values($filtered_row));
                } catch (Exception $ex) {}
            }
        }
        $pdo->exec("PRAGMA foreign_keys = ON;");
        return true;
    } catch (Exception $e) {
        return false;
    }
}

// Function to initialize database tables and seed data if empty
function init_database($pdo) {
    // 1. Users table (Admin & Students)
    $pdo->exec("CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'student',
        emergency_contact TEXT,
        id_proof_type TEXT,
        id_proof_no TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        otp_code TEXT,
        otp_expires_at DATETIME,
        registered_device_id TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )");

    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN otp_code TEXT");
    } catch (Exception $e) {}
    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN otp_expires_at DATETIME");
    } catch (Exception $e) {}
    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN registered_device_id TEXT");
    } catch (Exception $e) {}
    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN father_name TEXT");
    } catch (Exception $e) {}
    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN address TEXT");
    } catch (Exception $e) {}
    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN is_deleted INTEGER DEFAULT 0");
    } catch (Exception $e) {}
    try {
        $pdo->exec("ALTER TABLE users ADD COLUMN deleted_at DATETIME");
    } catch (Exception $e) {}

    // Auto-purge items in Recycle Bin older than 30 days
    try {
        $old_ids = $pdo->query("SELECT id FROM users WHERE role = 'student' AND is_deleted = 1 AND deleted_at < DATETIME('now', '-30 days')")->fetchAll(PDO::FETCH_COLUMN);
        if (!empty($old_ids)) {
            $in_clause = implode(',', array_fill(0, count($old_ids), '?'));
            $pdo->prepare("DELETE FROM fee_payments WHERE user_id IN ($in_clause)")->execute($old_ids);
            $pdo->prepare("DELETE FROM attendance WHERE user_id IN ($in_clause)")->execute($old_ids);
            $pdo->prepare("DELETE FROM allocations WHERE user_id IN ($in_clause)")->execute($old_ids);
            $pdo->prepare("DELETE FROM complaints WHERE user_id IN ($in_clause)")->execute($old_ids);
            $pdo->prepare("DELETE FROM notifications WHERE user_id IN ($in_clause)")->execute($old_ids);
            $pdo->prepare("DELETE FROM users WHERE id IN ($in_clause)")->execute($old_ids);
        }
    } catch (Exception $e) {}
    // Auto-purge Help Complaints/Tickets older than 1 month (30 days)
    try {
        $pdo->exec("DELETE FROM complaints WHERE created_at < DATETIME('now', '-30 days')");
    } catch (Exception $e) {}

    // 2. Shifts table
    $pdo->exec("CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        fee_amount REAL NOT NULL,
        is_active INTEGER DEFAULT 1
    )");

    // 3. Seats table (Desks)
    $pdo->exec("CREATE TABLE IF NOT EXISTS seats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        seat_number TEXT UNIQUE NOT NULL,
        row_label TEXT NOT NULL DEFAULT 'A',
        is_active INTEGER DEFAULT 1,
        remarks TEXT
    )");

    // 4. Allocations table
    $pdo->exec("CREATE TABLE IF NOT EXISTS allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        seat_id INTEGER NOT NULL,
        shift_id INTEGER NOT NULL,
        start_date DATE NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (seat_id) REFERENCES seats(id) ON DELETE CASCADE,
        FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE CASCADE
    )");

    // 5. Fee Payments table
    $pdo->exec("CREATE TABLE IF NOT EXISTS fee_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        allocation_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        month_year TEXT NOT NULL,
        amount REAL NOT NULL,
        due_date DATE NOT NULL,
        paid_date DATE,
        payment_status TEXT NOT NULL DEFAULT 'pending',
        payment_mode TEXT,
        receipt_no TEXT UNIQUE,
        remarks TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (allocation_id) REFERENCES allocations(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )");

    // 6. Attendance table
    $pdo->exec("CREATE TABLE IF NOT EXISTS attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date DATE NOT NULL,
        check_in_time TEXT,
        check_out_time TEXT,
        status TEXT DEFAULT 'present',
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )");

    // 7. Complaints table
    $pdo->exec("CREATE TABLE IF NOT EXISTS complaints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        subject TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'open',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )");

    // 8. Notifications table
    $pdo->exec("CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER DEFAULT 0,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )");

    // 9. Direct Chat Messages table
    $pdo->exec("CREATE TABLE IF NOT EXISTS chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender_id INTEGER NOT NULL,
        receiver_id INTEGER NOT NULL,
        message TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (receiver_id) REFERENCES users(id) ON DELETE CASCADE
    )");

    // 10. System Settings table (Dynamic App Name & App Logo)
    $pdo->exec("CREATE TABLE IF NOT EXISTS system_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT
    )");

    $pdo->exec("INSERT OR IGNORE INTO system_settings (setting_key, setting_value) VALUES ('app_name', 'Self Study Library')");
    $pdo->exec("INSERT OR IGNORE INTO system_settings (setting_key, setting_value) VALUES ('app_logo_url', '')");
    $pdo->exec("INSERT OR IGNORE INTO system_settings (setting_key, setting_value) VALUES ('app_tagline', 'Quiet Environment & High-Speed Wi-Fi')");

    // HIGH PERFORMANCE INDEXES FOR 100+ CONCURRENT USERS
    try {
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone)");
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)");
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_users_role_status ON users(role, status, is_deleted)");
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_allocations_user_status ON allocations(user_id, status)");
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_allocations_seat_shift ON allocations(seat_id, shift_id, status)");
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_attendance_user_date ON attendance(user_id, date)");
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_fee_payments_alloc_month ON fee_payments(allocation_id, month_year)");
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_chat_messages_participants ON chat_messages(sender_id, receiver_id)");
        $pdo->exec("CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications(user_id, is_read)");
    } catch (Exception $e) {}

    // SEED INITIAL SHIFTS ACCORDING TO USER'S TIMING SPECIFICATION
    $shift_count = $pdo->query("SELECT COUNT(*) FROM shifts")->fetchColumn();
    if ($shift_count == 0) {
        $stmt = $pdo->prepare("INSERT INTO shifts (name, start_time, end_time, fee_amount) VALUES (?, ?, ?, ?)");
        $stmt->execute(['Morning Half Day Shift', '08:00', '14:00', 600.00]);
        $stmt->execute(['Afternoon / Evening Shift', '14:00', '21:00', 600.00]);
        $stmt->execute(['Full Day', '08:00', '22:00', 700.00]);
        $stmt->execute(['Full Day (24 Hours)', '00:00', '23:59', 1200.00]);
    }

    // Seed Seats
    $seat_count = $pdo->query("SELECT COUNT(*) FROM seats")->fetchColumn();
    if ($seat_count == 0) {
        $stmt = $pdo->prepare("INSERT INTO seats (seat_number, row_label, remarks) VALUES (?, ?, ?)");
        $rows = ['A', 'B', 'C', 'D'];
        foreach ($rows as $row) {
            for ($i = 1; $i <= 10; $i++) {
                $seat_num = sprintf("%s-%02d", $row, $i);
                $stmt->execute([$seat_num, $row, "Standard Ergonomic Desk with Charging Socket"]);
            }
        }
    }

    // Seed Admin User ONLY on fresh database where no users exist
    $user_total = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
    if ($user_total == 0) {
        $admin_pass = password_hash('admin2003', PASSWORD_DEFAULT);
        $stmt = $pdo->prepare("INSERT INTO users (name, email, phone, password, role, status) VALUES (?, ?, ?, ?, 'admin', 'approved')");
        $stmt->execute(['Library Owner Admin', 'admin@library.com', '9876543210', $admin_pass]);
    }

    // Ensure extra user table columns exist without altering existing business data
    $alter_cols = [
        'otp_code' => 'TEXT',
        'otp_expires_at' => 'DATETIME',
        'registered_device_id' => 'TEXT',
        'father_name' => 'TEXT',
        'address' => 'TEXT',
        'is_deleted' => 'INTEGER DEFAULT 0',
        'deleted_at' => 'DATETIME'
    ];
    foreach ($alter_cols as $c_name => $c_type) {
        try { $pdo->exec("ALTER TABLE users ADD COLUMN $c_name $c_type"); } catch (Exception $e) {}
    }

    // Auto-purge chat_messages and notifications strictly older than 48 hours
    try {
        $pdo->exec("DELETE FROM chat_messages WHERE created_at IS NOT NULL AND created_at != '' AND created_at < DATETIME('now', '-48 hours')");
        $pdo->exec("DELETE FROM notifications WHERE created_at IS NOT NULL AND created_at != '' AND created_at < DATETIME('now', '-48 hours')");
    } catch (Exception $e) {}
}

function run_migrations($pdo) {
    try {
        $pdo->exec("CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            migration_name TEXT NOT NULL,
            applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )");

        $applied = $pdo->query("SELECT version FROM schema_migrations")->fetchAll(PDO::FETCH_COLUMN);
        if ($applied === false) $applied = [];

        $migrations = [
            1 => [
                'name' => 'add_user_extra_fields',
                'sql' => function($pdo) {
                    try { $pdo->exec("ALTER TABLE users ADD COLUMN father_name TEXT"); } catch(Exception $e){}
                    try { $pdo->exec("ALTER TABLE users ADD COLUMN address TEXT"); } catch(Exception $e){}
                    try { $pdo->exec("ALTER TABLE users ADD COLUMN is_deleted INTEGER DEFAULT 0"); } catch(Exception $e){}
                    try { $pdo->exec("ALTER TABLE users ADD COLUMN deleted_at DATETIME"); } catch(Exception $e){}
                }
            ],
            2 => [
                'name' => 'ensure_shifts_migration',
                'sql' => function($pdo) {
                    try {
                        $pdo->exec("UPDATE shifts SET name = 'Full Day', start_time = '08:00', end_time = '22:00' WHERE id = 3 AND name LIKE '%24 Hours%'");
                        $stmt_check4 = $pdo->query("SELECT id FROM shifts WHERE id = 4")->fetch();
                        if (!$stmt_check4) {
                            $pdo->exec("INSERT INTO shifts (id, name, start_time, end_time, fee_amount, is_active) VALUES (4, 'Full Day (24 Hours)', '00:00', '23:59', 1200.00, 0)");
                        }
                    } catch (Exception $e) {}
                }
            ],
            3 => [
                'name' => 'enforce_single_active_allocation_constraints',
                'sql' => function($pdo) {
                    try {
                        // De-duplicate any active allocations so that only the latest active allocation per user remains active
                        $dups = $pdo->query("
                            SELECT user_id, MAX(id) as keep_id 
                            FROM allocations 
                            WHERE status = 'active' 
                            GROUP BY user_id 
                            HAVING COUNT(*) > 1
                        ")->fetchAll(PDO::FETCH_ASSOC);
                        foreach ($dups as $d) {
                            $stmt = $pdo->prepare("UPDATE allocations SET status = 'cancelled' WHERE user_id = ? AND status = 'active' AND id != ?");
                            $stmt->execute([$d['user_id'], $d['keep_id']]);
                        }
                        // Create partial unique index on allocations: maximum 1 active allocation per student
                        $pdo->exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_allocations_active_user ON allocations(user_id) WHERE status = 'active'");
                        // Create partial unique index on allocations: maximum 1 active student per seat desk per shift
                        $pdo->exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_allocations_active_seat_shift ON allocations(seat_id, shift_id) WHERE status = 'active'");
                    } catch (Exception $e) {}
                }
            ]
        ];

        foreach ($migrations as $ver => $m) {
            if (!in_array($ver, $applied)) {
                $m['sql']($pdo);
                $stmt = $pdo->prepare("INSERT OR IGNORE INTO schema_migrations (version, migration_name) VALUES (?, ?)");
                $stmt->execute([$ver, $m['name']]);
            }
        }
    } catch (Exception $e) {}
}

// Check if database is fresh/empty
$is_fresh_db = false;
try {
    $user_cnt = (int)$pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
    if ($user_cnt == 0) $is_fresh_db = true;
} catch (Exception $e) {
    $is_fresh_db = true;
}

// Run initializer
init_database($pdo);

// Restore snapshot ONLY on fresh/empty database startup AND if NOT production
if ($is_fresh_db && (!defined('APP_ENV') || APP_ENV !== 'production')) {
    try {
        restore_db_snapshot($pdo);
    } catch (Exception $e) {}
}

// Run non-destructive schema migrations
run_migrations($pdo);
?>
