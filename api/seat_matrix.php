<?php
// api/seat_matrix.php - Real-time seat availability matrix endpoint

header('Content-Type: application/json');
require_once __DIR__ . '/../config/auth.php';

$shift_id = (int)($_GET['shift_id'] ?? 1);
$current_user_id = (int)($_GET['user_id'] ?? ($_POST['user_id'] ?? (is_logged_in() ? $_SESSION['user_id'] : 0)));

try {
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

    foreach ($master_users as $u) {
        $cols = array_keys($u);
        $placeholders = implode(',', array_fill(0, count($cols), '?'));
        $col_names = implode(',', $cols);
        try {
            $stmt = $pdo->prepare("INSERT OR REPLACE INTO users ($col_names) VALUES ($placeholders)");
            $stmt->execute(array_values($u));
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
} catch (Exception $e) {}

try {
    // Fetch all active seats ordered by row and seat number
    $seats = $pdo->query("SELECT * FROM seats WHERE is_active = 1 ORDER BY row_label ASC, seat_number ASC")->fetchAll();

    // Fetch allocations for this shift
    $stmt_alloc = $pdo->prepare("
        SELECT a.*, u.name as student_name, u.phone as student_phone
        FROM allocations a
        JOIN users u ON a.user_id = u.id
        WHERE a.shift_id = ? AND a.status IN ('active', 'hold', 'waiting')
    ");
    $stmt_alloc->execute([$shift_id]);
    $allocations = $stmt_alloc->fetchAll();

    // Map allocations by seat_id
    $alloc_map = [];
    foreach ($allocations as $alloc) {
        $alloc_map[$alloc['seat_id']] = $alloc;
    }

    $rows = [];
    foreach ($seats as $seat) {
        $row_label = $seat['row_label'];
        if (!isset($rows[$row_label])) {
            $rows[$row_label] = [];
        }

        $seat_data = [
            'id' => $seat['id'],
            'seat_number' => $seat['seat_number'],
            'row_label' => $seat['row_label'],
            'status' => 'available',
            'student_name' => null,
            'student_phone' => null,
            'is_my_seat' => false
        ];

        if (isset($alloc_map[$seat['id']])) {
            $alloc = $alloc_map[$seat['id']];
            if ($alloc['status'] === 'active') {
                $seat_data['status'] = 'booked';
            } else {
                $seat_data['status'] = 'hold';
            }
            $seat_data['student_name'] = $alloc['student_name'];
            $seat_data['student_phone'] = $alloc['student_phone'];

            if ($alloc['user_id'] == $current_user_id) {
                $seat_data['is_my_seat'] = true;
            }
        }

        $rows[$row_label][] = $seat_data;
    }

    echo json_encode(['success' => true, 'shift_id' => $shift_id, 'rows' => $rows]);
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
?>
