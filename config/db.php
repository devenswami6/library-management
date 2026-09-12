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
    try {
        $pdo->exec("DELETE FROM chat_messages WHERE created_at < DATETIME('now', '-2 days')");
    } catch (Exception $e) {}

    // Auto-purge Notifications older than 2 days (48 hours)
    try {
        $pdo->exec("DELETE FROM notifications WHERE created_at < DATETIME('now', '-2 days')");
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

    // Seed Sample Students
    $student_count = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student'")->fetchColumn();
    if ($student_count == 0) {
        $pass = password_hash('student123', PASSWORD_DEFAULT);
        
        $stmt = $pdo->prepare("INSERT INTO users (name, email, phone, password, role, status, emergency_contact, id_proof_type, id_proof_no, created_at) VALUES (?, ?, ?, ?, 'student', 'approved', ?, ?, ?, ?)");
        $stmt->execute(['Rahul Sharma', 'rahul@gmail.com', '9812345678', $pass, '9812345600', 'Aadhaar', '1234-5678-9012', '2026-08-15 10:00:00']);
        $s1_id = $pdo->lastInsertId();

        $stmt->execute(['Priya Verma', 'priya@gmail.com', '9823456789', $pass, '9823456700', 'Voter ID', 'ABC1234567', '2026-07-10 11:30:00']);
        $s2_id = $pdo->lastInsertId();

        $stmt->execute(['Amit Kumar', 'amit@gmail.com', '9834567890', $pass, '9834567800', 'Aadhaar', '9876-5432-1098', '2026-09-01 09:15:00']);
        $s3_id = $pdo->lastInsertId();

        $stmt->execute(['Neha Patel', 'neha@gmail.com', '9845678901', $pass, '9845678900', 'Student ID', 'STU9988', '2026-09-02 14:20:00']);
        $s4_id = $pdo->lastInsertId();

        $stmt_alloc = $pdo->prepare("INSERT INTO allocations (user_id, seat_id, shift_id, start_date, status) VALUES (?, ?, ?, ?, ?)");
        $stmt_alloc->execute([$s1_id, 1, 1, '2026-08-15', 'active']);
        $alloc1_id = $pdo->lastInsertId();

        $stmt_alloc->execute([$s2_id, 2, 1, '2026-07-10', 'active']);
        $alloc2_id = $pdo->lastInsertId();

        $stmt_fee = $pdo->prepare("INSERT INTO fee_payments (allocation_id, user_id, month_year, amount, due_date, paid_date, payment_status, payment_mode, receipt_no) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
        $stmt_fee->execute([$alloc1_id, $s1_id, '2026-08', 600.00, '2026-08-15', '2026-08-15', 'paid', 'UPI', 'REC-20260815-01']);
        $stmt_fee->execute([$alloc1_id, $s1_id, '2026-09', 600.00, '2026-09-15', '2026-09-02', 'paid', 'UPI', 'REC-20260902-02']);

        $stmt_fee->execute([$alloc2_id, $s2_id, '2026-07', 600.00, '2026-07-10', '2026-07-10', 'paid', 'Cash', 'REC-20260710-01']);
        $stmt_fee->execute([$alloc2_id, $s2_id, '2026-08', 600.00, '2026-08-10', '2026-08-10', 'paid', 'Cash', 'REC-20260810-02']);
        $stmt_fee->execute([$alloc2_id, $s2_id, '2026-09', 600.00, '2026-09-10', NULL, 'overdue', NULL, NULL]);

        $stmt_comp = $pdo->prepare("INSERT INTO complaints (user_id, category, subject, description, status) VALUES (?, ?, ?, ?, ?)");
        $stmt_comp->execute([$s1_id, 'AC/Cooling', 'AC temperature too cold near Row A', 'Please keep AC at 24°C, Row A seats are directly facing air flow.', 'open']);
    }
}

// Run initializer
init_database($pdo);

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
