<?php
// config/db.php - Database connection and SQLite auto-initialization

$db_file = __DIR__ . '/../library.db';

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

if (!class_exists('ApiConfig')) {
    class ApiConfig {
        public static $baseUrl = 'https://library-management-hmwx.onrender.com';
    }
}

function save_db_snapshot($pdo) {
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
    if (isset($_SERVER['REQUEST_METHOD']) && in_array($_SERVER['REQUEST_METHOD'], ['POST', 'PUT', 'DELETE'])) {
        save_db_snapshot($pdo);
    }
});

function restore_db_snapshot($pdo) {
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
                    $stmt = $pdo->prepare("INSERT OR REPLACE INTO $table ($col_names) VALUES ($placeholders)");
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

    // Seed Admin User
    $admin_count = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'admin'")->fetchColumn();
    if ($admin_count == 0) {
        $admin_pass = password_hash('admin2003', PASSWORD_DEFAULT);
        $stmt = $pdo->prepare("INSERT INTO users (name, email, phone, password, role, status) VALUES (?, ?, ?, ?, 'admin', 'approved')");
        $stmt->execute(['Library Owner Admin', 'admin@library.com', '9876543210', $admin_pass]);
    } else {
        // Ensure active admin password hash is updated to admin2003
        $new_admin_pass = password_hash('admin2003', PASSWORD_DEFAULT);
        $pdo->prepare("UPDATE users SET password = ? WHERE role = 'admin' AND email = 'admin@library.com'")->execute([$new_admin_pass]);
    }

    // Seed All 11 Student Accounts from Master Record unconditionally
    $pdo->exec("PRAGMA foreign_keys = OFF;");
    
    $master_users = [
        ['id' => 1, 'name' => 'Library Owner Admin', 'email' => 'admin@library.com', 'phone' => '9876543210', 'password' => '$2y$12$DzSrSmkHcFu1yWhNXmGj3.eBmtbkgLzRcJmFGzgu3O1azcFT7AE1G', 'role' => 'admin', 'status' => 'approved', 'is_deleted' => 0],
        ['id' => 2, 'name' => 'Rahul Sharma', 'email' => 'rahul@gmail.com', 'phone' => '9812345678', 'password' => '$2y$10$Am4tp.dr.bWP/1zimiLideVNp/mePvhBVfwrK2056CywQvVVe7Vym', 'role' => 'student', 'emergency_contact' => '9812345600', 'id_proof_type' => 'Aadhaar', 'id_proof_no' => '1234-5678-9012', 'status' => 'approved', 'is_deleted' => 0],
        ['id' => 3, 'name' => 'Priya Verma', 'email' => 'priya@gmail.com', 'phone' => '9823456789', 'password' => '$2y$10$Am4tp.dr.bWP/1zimiLideVNp/mePvhBVfwrK2056CywQvVVe7Vym', 'role' => 'student', 'emergency_contact' => '9823456700', 'id_proof_type' => 'Voter ID', 'id_proof_no' => 'ABC1234567', 'status' => 'approved', 'is_deleted' => 0],
        ['id' => 4, 'name' => 'Amit Kumar', 'email' => 'amit@gmail.com', 'phone' => '9834567890', 'password' => '$2y$10$Am4tp.dr.bWP/1zimiLideVNp/mePvhBVfwrK2056CywQvVVe7Vym', 'role' => 'student', 'emergency_contact' => '9834567800', 'id_proof_type' => 'Aadhaar', 'id_proof_no' => '9876-5432-1098', 'status' => 'pending', 'is_deleted' => 1],
        ['id' => 5, 'name' => 'Neha Patel', 'email' => 'neha@gmail.com', 'phone' => '9845678901', 'password' => '$2y$10$Am4tp.dr.bWP/1zimiLideVNp/mePvhBVfwrK2056CywQvVVe7Vym', 'role' => 'student', 'emergency_contact' => '9845678900', 'id_proof_type' => 'Student ID', 'id_proof_no' => 'STU9988', 'status' => 'approved', 'is_deleted' => 0],
        ['id' => 6, 'name' => 'Deven Swami', 'email' => 'devenswami64@gmail.com', 'phone' => '07727880903', 'password' => '$2y$10$LYRhalZmnQEwe7XRYvtsYeq8.J1iHCIr1ra.gKXGqUB9K3iyxaKTm', 'role' => 'student', 'emergency_contact' => '07727880903', 'id_proof_type' => 'Aadhaar', 'id_proof_no' => '12341234123444', 'status' => 'approved', 'registered_device_id' => 'DEV-1788788407526-5718', 'is_deleted' => 0],
        ['id' => 7, 'name' => 'Deven Swami', 'email' => 'thestylye4@gmail.com', 'phone' => '07727880903', 'password' => '$2y$10$MppgCIhhbe6KHRC8uXU7CeyjJS31eEPqvQxXQbvZZlW1EBGHl1Qg2', 'role' => 'student', 'emergency_contact' => '1234567890', 'id_proof_type' => 'Aadhaar', 'id_proof_no' => '123412341234', 'status' => 'approved', 'is_deleted' => 0],
        ['id' => 8, 'name' => 'Mr ram', 'email' => 'ram@gmail.com', 'phone' => '9898989898', 'password' => '$2y$10$Am4tp.dr.bWP/1zimiLideVNp/mePvhBVfwrK2056CywQvVVe7Vym', 'role' => 'student', 'emergency_contact' => '9898989898', 'id_proof_type' => 'Aadhaar', 'id_proof_no' => '999988887777', 'status' => 'pending', 'is_deleted' => 0],
        ['id' => 9, 'name' => 'jitu', 'email' => 'jitendrapuri766@gmail.com', 'phone' => '9782742040', 'password' => '$2y$10$y8UJEuDN8R.Nc6TM/eeAJudqUu5zTGhe4DEQFJrXz/WBxAVMB5JlW', 'role' => 'student', 'emergency_contact' => '2222222222', 'id_proof_type' => 'Aadhaar Card', 'id_proof_no' => '123456789013', 'status' => 'approved', 'is_deleted' => 0],
        ['id' => 10, 'name' => 'Krishna', 'email' => 'thestyleboy6@gmail.com', 'phone' => '8888888888', 'password' => '$2y$10$Am4tp.dr.bWP/1zimiLideVNp/mePvhBVfwrK2056CywQvVVe7Vym', 'role' => 'student', 'emergency_contact' => '8888888888', 'id_proof_type' => 'Aadhaar', 'id_proof_no' => '888877776666', 'status' => 'pending', 'is_deleted' => 0],
        ['id' => 11, 'name' => 'DEV', 'email' => 'dev@gmail.com', 'phone' => '7777777777', 'password' => '$2y$10$Am4tp.dr.bWP/1zimiLideVNp/mePvhBVfwrK2056CywQvVVe7Vym', 'role' => 'student', 'emergency_contact' => '7777777777', 'id_proof_type' => 'Aadhaar', 'id_proof_no' => '777766665555', 'status' => 'pending', 'is_deleted' => 0]
    ];

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

    $user_table_cols = [];
    try {
        $info = $pdo->query("PRAGMA table_info(users)")->fetchAll(PDO::FETCH_ASSOC);
        foreach ($info as $col) {
            $user_table_cols[] = $col['name'];
        }
    } catch (Exception $ex) {}

    foreach ($master_users as $u) {
        $filtered_u = !empty($user_table_cols) ? array_intersect_key($u, array_flip($user_table_cols)) : $u;
        $cols = array_keys($filtered_u);
        $placeholders = implode(',', array_fill(0, count($cols), '?'));
        $col_names = implode(',', $cols);
        try {
            $stmt = $pdo->prepare("INSERT OR REPLACE INTO users ($col_names) VALUES ($placeholders)");
            $stmt->execute(array_values($filtered_u));
        } catch (Exception $ex) {}
    }

    $master_allocs = [
        ['id' => 1, 'user_id' => 2, 'seat_id' => 1, 'shift_id' => 1, 'start_date' => '2026-08-15', 'status' => 'active'],
        ['id' => 2, 'user_id' => 3, 'seat_id' => 2, 'shift_id' => 1, 'start_date' => '2026-07-10', 'status' => 'active'],
        ['id' => 3, 'user_id' => 6, 'seat_id' => 3, 'shift_id' => 1, 'start_date' => '2026-09-04', 'status' => 'active'],
        ['id' => 4, 'user_id' => 7, 'seat_id' => 10, 'shift_id' => 3, 'start_date' => '2026-09-03', 'status' => 'active'],
        ['id' => 5, 'user_id' => 8, 'seat_id' => 1, 'shift_id' => 1, 'start_date' => '2026-09-04', 'status' => 'hold', 'notes' => 'Requested registration by student'],
        ['id' => 7, 'user_id' => 9, 'seat_id' => 1, 'shift_id' => 2, 'start_date' => '2026-09-07', 'status' => 'active', 'notes' => 'Seat desk allotted by Admin'],
        ['id' => 8, 'user_id' => 10, 'seat_id' => 1, 'shift_id' => 3, 'start_date' => '2026-09-07', 'status' => 'hold', 'notes' => 'Requested registration by student'],
        ['id' => 9, 'user_id' => 11, 'seat_id' => 1, 'shift_id' => 1, 'start_date' => '2026-09-07', 'status' => 'hold', 'notes' => 'Requested registration by student']
    ];

    foreach ($master_allocs as $a) {
        $cols = array_keys($a);
        $placeholders = implode(',', array_fill(0, count($cols), '?'));
        $col_names = implode(',', $cols);
        try {
            $stmt = $pdo->prepare("INSERT OR REPLACE INTO allocations ($col_names) VALUES ($placeholders)");
            $stmt->execute(array_values($a));
        } catch (Exception $ex) {}
    }
    $pdo->exec("PRAGMA foreign_keys = ON;");

    // Always attempt snapshot restore at end of initialization
    restore_db_snapshot($pdo);

    // Auto-purge chat_messages and notifications strictly older than 48 hours
    try {
        $pdo->exec("DELETE FROM chat_messages WHERE created_at IS NOT NULL AND created_at != '' AND created_at < DATETIME('now', '-48 hours')");
        $pdo->exec("DELETE FROM notifications WHERE created_at IS NOT NULL AND created_at != '' AND created_at < DATETIME('now', '-48 hours')");
    } catch (Exception $e) {}
}

// Run initializer
init_database($pdo);

// Always sync snapshot into DB if db_snapshot.json exists
try {
    restore_db_snapshot($pdo);
} catch (Exception $e) {}

// Ensure notifications table exists
$pdo->exec("CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER DEFAULT 0,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
)");

// Migration check: Ensure shift #3 is 'Full Day' and shift #4 is 'Full Day (24 Hours)'
try {
    $pdo->exec("UPDATE shifts SET name = 'Full Day', start_time = '08:00', end_time = '22:00' WHERE id = 3 AND name LIKE '%24 Hours%'");
    $stmt_check4 = $pdo->query("SELECT id FROM shifts WHERE id = 4")->fetch();
    if (!$stmt_check4) {
        $pdo->exec("INSERT INTO shifts (id, name, start_time, end_time, fee_amount, is_active) VALUES (4, 'Full Day (24 Hours)', '00:00', '23:59', 1200.00, 1)");
    }
} catch (Exception $e) {}
?>
