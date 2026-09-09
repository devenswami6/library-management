<?php
// api/seat_matrix.php - Real-time seat availability matrix endpoint

header('Content-Type: application/json');
require_once __DIR__ . '/../config/auth.php';

$shift_id = (int)($_GET['shift_id'] ?? 1);
$current_user_id = (int)($_GET['user_id'] ?? ($_POST['user_id'] ?? (is_logged_in() ? $_SESSION['user_id'] : 0)));

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
