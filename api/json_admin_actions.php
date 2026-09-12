<?php
// api/json_admin_actions.php - Mobile REST API for Admin Dashboard & Management

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

// Support raw JSON body or POST form-data
$input = json_decode(file_get_contents('php://input'), true);
if (!empty($input)) {
    $_POST = array_merge($_POST, $input);
    $_GET = array_merge($_GET, $input);
}

$action = $_GET['action'] ?? ($_POST['action'] ?? '');

try {
    $pdo->exec("UPDATE users SET status = 'approved' WHERE (status = 'pending' OR status = 'active') AND id IN (SELECT user_id FROM allocations WHERE status = 'active')");

    if ($action === 'get_dashboard_stats') {
        $total_students = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student' AND (status = 'approved' OR status = 'active')")->fetchColumn();
        $pending_students = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student' AND status = 'pending'")->fetchColumn();
        $total_seats = $pdo->query("SELECT COUNT(*) FROM seats WHERE is_active = 1")->fetchColumn();
        
        $today = date('Y-m-d');
        $present_today = $pdo->query("SELECT COUNT(DISTINCT user_id) FROM attendance WHERE date = '$today' AND status = 'present'")->fetchColumn();
        $currently_inside = $pdo->query("SELECT COUNT(DISTINCT user_id) FROM attendance WHERE date = '$today' AND check_out_time IS NULL")->fetchColumn();

        $admin_id = (int)$pdo->query("SELECT id FROM users WHERE role = 'admin' LIMIT 1")->fetchColumn();
        if ($admin_id <= 0) $admin_id = 1;
        $unread_chats = (int)$pdo->query("SELECT COUNT(*) FROM chat_messages WHERE (receiver_id = $admin_id OR receiver_id = 1 OR receiver_id = 0) AND (is_read = 0 OR is_read IS NULL)")->fetchColumn();

        echo json_encode([
            'success' => true,
            'stats' => [
                'total_students' => (int)$total_students,
                'pending_students' => (int)$pending_students,
                'total_seats' => (int)$total_seats,
                'present_today' => (int)$present_today,
                'currently_inside' => (int)$currently_inside,
                'unread_chats_count' => (int)$unread_chats
            ]
        ]);
        exit();

    } elseif ($action === 'get_pending_students') {
        $pending = $pdo->query("
            SELECT u.id, u.name, u.email, u.phone, u.created_at, a.shift_id, sh.name as shift_name
            FROM users u
            LEFT JOIN allocations a ON u.id = a.user_id
            LEFT JOIN shifts sh ON a.shift_id = sh.id
            WHERE u.role = 'student' AND u.status = 'pending'
            ORDER BY u.id DESC
        ")->fetchAll();

        $available_seats = $pdo->query("SELECT id, seat_number, row_label FROM seats WHERE is_active = 1 ORDER BY row_label ASC, seat_number ASC")->fetchAll();
        $shifts = $pdo->query("SELECT * FROM shifts WHERE is_active = 1")->fetchAll();
        $active_allocations = $pdo->query("SELECT seat_id, shift_id, user_id FROM allocations WHERE status = 'active'")->fetchAll();

        echo json_encode([
            'success' => true,
            'pending_students' => $pending,
            'available_seats' => $available_seats,
            'shifts' => $shifts,
            'active_allocations' => $active_allocations
        ]);
        exit();

    } elseif ($action === 'allot_seat') {
        $student_id = (int)($_POST['student_id'] ?? 0);
        $seat_id = (int)($_POST['seat_id'] ?? 0);
        $shift_id = (int)($_POST['shift_id'] ?? 1);

        if ($student_id <= 0 || $seat_id <= 0) {
            echo json_encode(['success' => false, 'message' => 'Please select a valid student and seat desk.']);
            exit();
        }

        // Check if seat desk is already occupied in this shift by another student
        $stmt_check = $pdo->prepare("
            SELECT a.id, u.name as student_name, s.seat_number, sh.name as shift_name
            FROM allocations a
            JOIN users u ON a.user_id = u.id
            JOIN seats s ON a.seat_id = s.id
            JOIN shifts sh ON a.shift_id = sh.id
            WHERE a.seat_id = ? AND a.shift_id = ? AND a.status = 'active' AND a.user_id != ?
        ");
        $stmt_check->execute([$seat_id, $shift_id, $student_id]);
        $occupied = $stmt_check->fetch();
        if ($occupied) {
            echo json_encode([
                'success' => false,
                'message' => "Seat Desk {$occupied['seat_number']} is ALREADY OCCUPIED by {$occupied['student_name']} in {$occupied['shift_name']}! Please select an available desk."
            ]);
            exit();
        }

        // Approve user
        $pdo->prepare("UPDATE users SET status = 'approved' WHERE id = ?")->execute([$student_id]);

        // Remove old pending allocation if any
        $pdo->prepare("DELETE FROM allocations WHERE user_id = ?")->execute([$student_id]);

        // Insert new active allocation
        $stmt_alloc = $pdo->prepare("
            INSERT INTO allocations (user_id, seat_id, shift_id, start_date, status, notes)
            VALUES (?, ?, ?, DATE('now'), 'active', 'Seat desk allotted by Admin')
        ");
        $stmt_alloc->execute([$student_id, $seat_id, $shift_id]);

        // Fetch seat number for response notification
        $stmt_s = $pdo->prepare("SELECT seat_number FROM seats WHERE id = ?");
        $stmt_s->execute([$seat_id]);
        $seat_no = $stmt_s->fetchColumn();

        // Create notification for student
        $pdo->prepare("
            INSERT INTO notifications (title, message, user_id)
            VALUES ('Seat Allotted!', 'Congratulations! Admin has allotted Seat Desk: " . $seat_no . " to you.', ?)
        ")->execute([$student_id]);

        echo json_encode(['success' => true, 'message' => "Seat Desk $seat_no allotted successfully!"]);
        exit();

    } elseif ($action === 'get_live_attendance') {
        $target_date = trim($_GET['date'] ?? ($_POST['date'] ?? date('Y-m-d')));
        
        $stmt_att = $pdo->prepare("
            SELECT u.id as user_id, u.name as student_name, u.phone, s.seat_number, sh.name as shift_name,
                   att.id as attendance_id, att.check_in_time, att.check_out_time
            FROM users u
            JOIN allocations a ON u.id = a.user_id AND a.status = 'active'
            JOIN seats s ON a.seat_id = s.id
            JOIN shifts sh ON a.shift_id = sh.id
            LEFT JOIN attendance att ON u.id = att.user_id AND att.date = ?
            WHERE u.role = 'student' AND (u.status = 'approved' OR u.status = 'active') AND u.is_deleted = 0
            ORDER BY s.seat_number ASC
        ");
        $stmt_att->execute([$target_date]);
        $students_att = $stmt_att->fetchAll(PDO::FETCH_ASSOC);

        $total_count = count($students_att);
        $inside_count = 0;
        
        foreach ($students_att as &$sa) {
            $check_in_str = 'Not Arrived';
            $check_out_str = 'N/A';
            $duration_str = '--';
            
            if (!empty($sa['check_in_time'])) {
                $check_in_ts = strtotime($sa['check_in_time']);
                $check_in_str = date('g:i A', $check_in_ts);
                
                if (!empty($sa['check_out_time'])) {
                    $check_out_ts = strtotime($sa['check_out_time']);
                    $check_out_str = date('g:i A', $check_out_ts);
                    $diff = max(0, $check_out_ts - $check_in_ts);
                    $hrs = floor($diff / 3600);
                    $mins = floor(($diff % 3600) / 60);
                    $duration_str = "{$hrs}h {$mins}m";
                } else {
                    $inside_count++;
                    $check_out_str = 'In Hall 🟢';
                    $diff = max(0, time() - $check_in_ts);
                    $hrs = floor($diff / 3600);
                    $mins = floor(($diff % 3600) / 60);
                    $duration_str = "{$hrs}h {$mins}m (In)";
                }
            }
            
            $sa['check_in_formatted'] = $check_in_str;
            $sa['check_out_formatted'] = $check_out_str;
            $sa['duration_today'] = $duration_str;
        }
        unset($sa);
        
        $absent_count = $total_count - $inside_count;

        echo json_encode([
            'success' => true,
            'date' => $target_date,
            'total_students' => $total_count,
            'currently_inside' => $inside_count,
            'absent_outside' => $absent_count,
            'attendance_list' => $students_att
        ]);
        exit();

    } elseif ($action === 'get_12month_master_fee_report') {
        $stmt_students = $pdo->query("
            SELECT u.id as user_id, u.name, u.email, u.phone, u.status as user_status, u.is_deleted, u.deleted_at, u.created_at,
                   a.start_date, s.seat_number, sh.name as shift_name, sh.fee_amount
            FROM users u
            LEFT JOIN allocations a ON u.id = a.user_id AND a.status = 'active'
            LEFT JOIN seats s ON a.seat_id = s.id
            LEFT JOIN shifts sh ON a.shift_id = sh.id
            WHERE u.role = 'student'
            ORDER BY u.name ASC
        ");
        $students = $stmt_students->fetchAll(PDO::FETCH_ASSOC);

        $report_data = [];
        $total_grand_collected = 0.0;
        $total_grand_overdue = 0.0;

        foreach ($students as $stu) {
            $uid = $stu['user_id'];
            $stmt_pay = $pdo->prepare("
                SELECT month_year, amount, payment_status, paid_date, payment_mode, receipt_no, due_date
                FROM fee_payments
                WHERE user_id = ?
                ORDER BY due_date DESC
            ");
            $stmt_pay->execute([$uid]);
            $payments = $stmt_pay->fetchAll(PDO::FETCH_ASSOC);
            
            $paid_amount = 0.0;
            $overdue_amount = 0.0;
            $paid_months = [];
            
            foreach ($payments as $p) {
                if ($p['payment_status'] === 'paid') {
                    $paid_amount += (float)$p['amount'];
                    $paid_months[] = $p['month_year'];
                } elseif ($p['payment_status'] === 'overdue') {
                    $overdue_amount += (float)$p['amount'];
                }
            }
            
            $total_grand_collected += $paid_amount;
            $total_grand_overdue += $overdue_amount;
            
            $status_label = 'Active';
            if ($stu['is_deleted'] == 1) {
                $status_label = 'Left / Deleted';
            } elseif ($stu['user_status'] === 'pending') {
                $status_label = 'Pending Approval';
            }
            
            $report_data[] = [
                'user_id' => $uid,
                'name' => $stu['name'],
                'phone' => $stu['phone'],
                'email' => $stu['email'],
                'status' => $status_label,
                'seat_number' => $stu['seat_number'] ?? 'N/A',
                'shift_name' => $stu['shift_name'] ?? 'N/A',
                'monthly_fee' => (float)($stu['fee_amount'] ?? 600.0),
                'start_date' => $stu['start_date'] ?? $stu['created_at'],
                'total_paid' => $paid_amount,
                'total_overdue' => $overdue_amount,
                'paid_cycles_count' => count($paid_months),
                'payments' => $payments
            ];
        }

        echo json_encode([
            'success' => true,
            'summary' => [
                'total_students' => count($report_data),
                'total_collected' => $total_grand_collected,
                'total_overdue' => $total_grand_overdue,
            ],
            'csv_url' => 'https://library-management-hmwx.onrender.com/master_12month_fee_report.php?format=csv',
            'web_report_url' => 'https://library-management-hmwx.onrender.com/master_12month_fee_report.php',
            'students' => $report_data
        ]);
        exit();

    } elseif ($action === 'get_shifts') {
        $stmt = $pdo->query("
            SELECT sh.*, COUNT(a.id) as active_students_count
            FROM shifts sh
            LEFT JOIN allocations a ON sh.id = a.shift_id AND a.status = 'active'
            GROUP BY sh.id
            ORDER BY sh.id ASC
        ");
        $shifts = $stmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode(['success' => true, 'shifts' => $shifts]);
        exit();

    } elseif ($action === 'add_shift') {
        $name = trim($_POST['name'] ?? '');
        $start_time = trim($_POST['start_time'] ?? '');
        $end_time = trim($_POST['end_time'] ?? '');
        $fee_amount = (float)($_POST['fee_amount'] ?? 0);

        if (empty($name) || empty($start_time) || empty($end_time) || $fee_amount <= 0) {
            echo json_encode(['success' => false, 'message' => 'Please provide valid shift name, start time, end time, and fee amount.']);
            exit();
        }

        $stmt = $pdo->prepare("INSERT INTO shifts (name, start_time, end_time, fee_amount, is_active) VALUES (?, ?, ?, ?, 1)");
        $stmt->execute([$name, $start_time, $end_time, $fee_amount]);

        echo json_encode(['success' => true, 'message' => "New Shift '$name' added successfully!"]);
        exit();

    } elseif ($action === 'edit_shift') {
        $shift_id = (int)($_POST['shift_id'] ?? 0);
        $name = trim($_POST['name'] ?? '');
        $start_time = trim($_POST['start_time'] ?? '');
        $end_time = trim($_POST['end_time'] ?? '');
        $fee_amount = (float)($_POST['fee_amount'] ?? 0);

        if (!$shift_id || empty($name) || empty($start_time) || empty($end_time) || $fee_amount <= 0) {
            echo json_encode(['success' => false, 'message' => 'Please fill in all required shift fields correctly.']);
            exit();
        }

        $stmt = $pdo->prepare("UPDATE shifts SET name = ?, start_time = ?, end_time = ?, fee_amount = ? WHERE id = ?");
        $stmt->execute([$name, $start_time, $end_time, $fee_amount, $shift_id]);

        echo json_encode(['success' => true, 'message' => "Shift '$name' details updated successfully!"]);
        exit();

    } elseif ($action === 'toggle_shift') {
        $shift_id = (int)($_POST['shift_id'] ?? 0);
        $is_active = (int)($_POST['is_active'] ?? 1);

        if (!$shift_id) {
            echo json_encode(['success' => false, 'message' => 'Shift ID is required.']);
            exit();
        }

        $stmt = $pdo->prepare("UPDATE shifts SET is_active = ? WHERE id = ?");
        $stmt->execute([$is_active, $shift_id]);

        $status_text = ($is_active == 1) ? 'activated' : 'deactivated';
        echo json_encode(['success' => true, 'message' => "Shift has been $status_text."]);
        exit();

    } elseif ($action === 'admin_attendance_toggle') {
        $student_id = (int)($_POST['student_id'] ?? 0);
        $toggle_type = trim($_POST['toggle_type'] ?? 'checkin'); // checkin or checkout
        $today = date('Y-m-d');
        $current_time = date('H:i:s');

        $stmt_att = $pdo->prepare("SELECT id, check_in_time, check_out_time FROM attendance WHERE user_id = ? AND date = ? ORDER BY id DESC LIMIT 1");
        $stmt_att->execute([$student_id, $today]);
        $att = $stmt_att->fetch();

        if ($toggle_type === 'checkin') {
            if (!$att) {
                $pdo->prepare("INSERT INTO attendance (user_id, date, check_in_time, status) VALUES (?, ?, ?, 'present')")->execute([$student_id, $today, $current_time]);
            } else {
                $pdo->prepare("UPDATE attendance SET check_in_time = ?, check_out_time = NULL WHERE id = ?")->execute([$current_time, $att['id']]);
            }
            echo json_encode(['success' => true, 'message' => 'Admin checked in student at ' . $current_time]);
        } else { // checkout
            if ($att && empty($att['check_out_time'])) {
                $pdo->prepare("UPDATE attendance SET check_out_time = ? WHERE id = ?")->execute([$current_time, $att['id']]);
            }
            echo json_encode(['success' => true, 'message' => 'Admin checked out student at ' . $current_time]);
        }
        exit();

    } elseif ($action === 'send_notification') {
        $title = trim($_POST['title'] ?? 'Notice');
        $message = trim($_POST['message'] ?? ($_POST['content'] ?? ''));
        $target_user_id = !empty($_POST['target_user_id']) ? (int)$_POST['target_user_id'] : 0;

        if (empty($message)) {
            echo json_encode(['success' => false, 'message' => 'Notification content cannot be empty.']);
            exit();
        }

        // Auto-delete notifications older than 2 days (48 hours)
        try {
            $pdo->exec("DELETE FROM notifications WHERE created_at < DATETIME('now', '-2 days')");
        } catch (Exception $e) {}

        $stmt_ins = $pdo->prepare("INSERT INTO notifications (title, message, user_id) VALUES (?, ?, ?)");
        $stmt_ins->execute([$title, $message, $target_user_id]);

        echo json_encode(['success' => true, 'message' => 'Notification sent successfully!']);
        exit();

    } elseif ($action === 'bulk_create_seats') {
        $row_label = strtoupper(trim($_POST['row_label'] ?? 'A'));
        $start_num = (int)($_POST['start_num'] ?? 1);
        $end_num = (int)($_POST['end_num'] ?? 10);
        $format_digits = (int)($_POST['format_digits'] ?? 2);

        if (empty($row_label) || $start_num <= 0 || $end_num < $start_num) {
            echo json_encode(['success' => false, 'message' => 'Invalid range parameters.']);
            exit();
        }

        $created_count = 0;
        $skipped_count = 0;

        $stmt_check = $pdo->prepare("SELECT id FROM seats WHERE seat_number = ?");
        $stmt_insert = $pdo->prepare("INSERT INTO seats (seat_number, row_label, is_active) VALUES (?, ?, 1)");

        for ($i = $start_num; $i <= $end_num; $i++) {
            $num_str = str_pad($i, $format_digits, '0', STR_PAD_LEFT);
            $seat_no = $row_label . '-' . $num_str;

            $stmt_check->execute([$seat_no]);
            if (!$stmt_check->fetch()) {
                $stmt_insert->execute([$seat_no, $row_label]);
                $created_count++;
            } else {
                $skipped_count++;
            }
        }

        echo json_encode([
            'success' => true,
            'message' => "Created $created_count new seat desks in Row $row_label ($start_num to $end_num)!"
        ]);
        exit();

    } elseif ($action === 'delete_seat') {
        $seat_id = (int)($_POST['seat_id'] ?? 0);
        if ($seat_id > 0) {
            $pdo->prepare("DELETE FROM allocations WHERE seat_id = ?")->execute([$seat_id]);
            $pdo->prepare("DELETE FROM seats WHERE id = ?")->execute([$seat_id]);
            echo json_encode(['success' => true, 'message' => 'Seat desk deleted successfully!']);
        } else {
            echo json_encode(['success' => false, 'message' => 'Invalid seat ID.']);
        }
        exit();

    } elseif ($action === 'get_all_complaints') {
        $complaints = $pdo->query("
            SELECT c.*, u.name as student_name, u.phone as student_phone
            FROM complaints c
            JOIN users u ON c.user_id = u.id
            ORDER BY c.id DESC
        ")->fetchAll();
        echo json_encode(['success' => true, 'complaints' => $complaints]);
        exit();

    } elseif ($action === 'update_complaint_status') {
        $complaint_id = (int)($_POST['complaint_id'] ?? 0);
        $status = trim($_POST['status'] ?? 'resolved');

        if ($complaint_id > 0) {
            $stmt_upd = $pdo->prepare("UPDATE complaints SET status = ? WHERE id = ?");
            $stmt_upd->execute([$status, $complaint_id]);

            $stmt_c = $pdo->prepare("SELECT user_id, subject FROM complaints WHERE id = ?");
            $stmt_c->execute([$complaint_id]);
            $comp = $stmt_c->fetch();
            if ($comp) {
                $status_label = strtoupper(str_replace('_', ' ', $status));
                $pdo->prepare("
                    INSERT INTO notifications (title, message, user_id)
                    VALUES ('Ticket Status Updated', 'Your support ticket #" . sprintf("%04d", $complaint_id) . " (" . $comp['subject'] . ") has been marked as " . $status_label . ".', ?)
                ")->execute([$comp['user_id']]);
            }

            echo json_encode(['success' => true, 'message' => "Ticket status updated to $status!"]);
        } else {
            echo json_encode(['success' => false, 'message' => 'Invalid complaint ticket ID.']);
        }
        exit();

    } elseif ($action === 'get_fee_payments') {
        require_once __DIR__ . '/../config/auth.php';
        // Fetch fee status for all students with active allocations
        $allocations = $pdo->query("
            SELECT a.id as allocation_id, a.user_id, a.start_date, u.name as student_name, u.phone as student_phone, u.email as student_email,
                   s.seat_number, s.row_label, sh.name as shift_name, sh.fee_amount
            FROM allocations a
            JOIN users u ON a.user_id = u.id
            JOIN seats s ON a.seat_id = s.id
            JOIN shifts sh ON a.shift_id = sh.id
            WHERE a.status = 'active'
            ORDER BY u.name ASC
        ")->fetchAll();

        $payments_list = [];
        $total_collected = 0;
        $pending_count = 0;
        $overdue_count = 0;

        foreach ($allocations as $alloc) {
            $fee_status = get_student_fee_status($pdo, $alloc['allocation_id'], $alloc['start_date']);

            if ($fee_status['status'] === 'overdue') {
                $overdue_count++;
            } elseif ($fee_status['status'] === 'pending') {
                $pending_count++;
            } elseif ($fee_status['status'] === 'paid') {
                $total_collected += (float)$alloc['fee_amount'];
            }

            $payments_list[] = [
                'allocation_id' => (int)$alloc['allocation_id'],
                'user_id' => (int)$alloc['user_id'],
                'student_name' => $alloc['student_name'],
                'student_phone' => $alloc['student_phone'],
                'student_email' => $alloc['student_email'],
                'seat_number' => $alloc['seat_number'],
                'row_label' => $alloc['row_label'],
                'shift_name' => $alloc['shift_name'],
                'fee_amount' => (float)$alloc['fee_amount'],
                'month_year' => $fee_status['target_month'],
                'month_year_label' => $fee_status['target_month_label'],
                'due_date' => $fee_status['due_date'],
                'payment_status' => $fee_status['status'],
                'label' => $fee_status['label'],
                'is_advance' => $fee_status['is_advance'],
            ];
        }

        echo json_encode([
            'success' => true,
            'stats' => [
                'total_collected' => $total_collected,
                'pending_count' => $pending_count,
                'overdue_count' => $overdue_count,
                'total_active' => count($allocations),
            ],
            'payments' => $payments_list,
        ]);
        exit();

    } elseif ($action === 'record_fee_payment') {
        require_once __DIR__ . '/../config/auth.php';
        $allocation_id = (int)($_POST['allocation_id'] ?? 0);
        $user_id = (int)($_POST['user_id'] ?? 0);
        $amount = (float)($_POST['amount'] ?? 0);
        $payment_mode = trim($_POST['payment_mode'] ?? 'Cash');
        $month_year = trim($_POST['month_year'] ?? '');

        if ($allocation_id <= 0 || $user_id <= 0 || $amount <= 0) {
            echo json_encode(['success' => false, 'message' => 'Invalid fee payment details provided.']);
            exit();
        }

        // Fetch student start date
        $stmt_alloc = $pdo->prepare("SELECT start_date FROM allocations WHERE id = ?");
        $stmt_alloc->execute([$allocation_id]);
        $alloc = $stmt_alloc->fetch();
        $start_date = $alloc['start_date'] ?? date('Y-m-d');

        // Check if submitted month_year is empty OR already paid
        if (!empty($month_year)) {
            $stmt_check = $pdo->prepare("SELECT id FROM fee_payments WHERE allocation_id = ? AND month_year = ? AND payment_status = 'paid'");
            $stmt_check->execute([$allocation_id, $month_year]);
            if ($stmt_check->fetch()) {
                // Submitted month is already paid, clear it so fee_status calculates next unpaid cycle
                $month_year = '';
            }
        }

        if (empty($month_year)) {
            $fee_status = get_student_fee_status($pdo, $allocation_id, $start_date);
            $month_year = $fee_status['target_month'];
        }

        // Calculate due date for the specified month_year
        $start_day = (int)date('d', strtotime($start_date));
        $ym_parts = explode('-', $month_year);
        $target_y = (int)($ym_parts[0] ?? date('Y'));
        $target_m = (int)($ym_parts[1] ?? date('m'));
        $days_in_m = (int)date('t', strtotime(sprintf("%04d-%02d-01", $target_y, $target_m)));
        $actual_day = min($start_day, $days_in_m);
        $due_date = sprintf("%04d-%02d-%02d", $target_y, $target_m, $actual_day);

        $receipt_no = "REC-" . date('Ymd') . "-" . rand(1000, 9999);
        $today = date('Y-m-d');

        $stmt = $pdo->prepare("SELECT id FROM fee_payments WHERE allocation_id = ? AND month_year = ? AND payment_status != 'paid'");
        $stmt->execute([$allocation_id, $month_year]);
        $existing = $stmt->fetch();

        if ($existing) {
            $update = $pdo->prepare("
                UPDATE fee_payments 
                SET amount = ?, paid_date = ?, payment_status = 'paid', payment_mode = ?, receipt_no = ?, due_date = ? 
                WHERE id = ?
            ");
            $update->execute([$amount, $today, $payment_mode, $receipt_no, $due_date, $existing['id']]);
        } else {
            $insert = $pdo->prepare("
                INSERT INTO fee_payments (allocation_id, user_id, month_year, amount, due_date, paid_date, payment_status, payment_mode, receipt_no) 
                VALUES (?, ?, ?, ?, ?, ?, 'paid', ?, ?)
            ");
            $insert->execute([$allocation_id, $user_id, $month_year, $amount, $due_date, $today, $payment_mode, $receipt_no]);
        }

        $month_label = date('F Y', strtotime($month_year . '-01'));

        // Notify Student
        $pdo->prepare("
            INSERT INTO notifications (title, message, user_id)
            VALUES ('Monthly Fee Payment Received 💳', 'Thank you! Fee payment of ₹" . number_format($amount, 2) . " for " . $month_label . " has been recorded. Receipt No: " . $receipt_no . "', ?)
        ")->execute([$user_id]);

        echo json_encode([
            'success' => true,
            'message' => "Payment of ₹$amount for $month_label recorded successfully!",
            'receipt_no' => $receipt_no,
        ]);
        exit();

    } elseif ($action === 'get_student_fee_history') {
        $student_id = (int)($_GET['user_id'] ?? $_POST['user_id'] ?? 0);
        $stmt_pay = $pdo->prepare("
            SELECT fp.*, s.seat_number, sh.name as shift_name
            FROM fee_payments fp
            LEFT JOIN allocations a ON fp.allocation_id = a.id
            LEFT JOIN seats s ON a.seat_id = s.id
            LEFT JOIN shifts sh ON a.shift_id = sh.id
            WHERE fp.user_id = ?
            ORDER BY fp.due_date DESC, fp.id DESC
            LIMIT 12
        ");
        $stmt_pay->execute([$student_id]);
        $payments = $stmt_pay->fetchAll();

        echo json_encode([
            'success' => true,
            'fee_history' => $payments
        ]);
        exit();

    } elseif ($action === 'backup_db') {
        $db_file = __DIR__ . '/../library.db';
        if (!file_exists($db_file)) {
            die("Database file not found.");
        }
        $filename = "library_backup_" . date('Y-m-d_H-i-s') . ".sqlite";
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . $filename . '"');
        header('Content-Length: ' . filesize($db_file));
        readfile($db_file);
        exit();

    } elseif ($action === 'get_database_backup_info') {
        $db_file = __DIR__ . '/../library.db';
        if (!file_exists($db_file)) {
            echo json_encode(['success' => false, 'message' => 'Database file not found.']);
            exit();
        }

        $tables = ['users', 'allocations', 'seats', 'shifts', 'attendance', 'fee_payments', 'complaints', 'notifications', 'chat_messages'];
        $counts = [];
        foreach ($tables as $t) {
            try {
                $counts[$t] = (int)$pdo->query("SELECT COUNT(*) FROM $t")->fetchColumn();
            } catch (Exception $e) {
                $counts[$t] = 0;
            }
        }

        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? "https" : "http";
        $host = $_SERVER['HTTP_HOST'] ?? 'library-management-hmwx.onrender.com';
        $base_url = "$protocol://$host";

        echo json_encode([
            'success' => true,
            'filename' => "library_backup_" . date('Y-m-d_H-i-s') . ".sqlite",
            'db_size_bytes' => filesize($db_file),
            'db_size_formatted' => round(filesize($db_file) / 1024, 2) . " KB",
            'table_counts' => $counts,
            'backup_url' => "$base_url/api/json_admin_actions.php?action=backup_db"
        ]);
        exit();

    } elseif ($action === 'restore_db') {
        if (isset($_FILES['backup_file']) && $_FILES['backup_file']['error'] === UPLOAD_ERR_OK) {
            $tmp_name = $_FILES['backup_file']['tmp_name'];
            $db_file = __DIR__ . '/../library.db';
            try {
                $test_pdo = new PDO("sqlite:" . $tmp_name);
                $test_pdo->query("SELECT COUNT(*) FROM users");
                $test_pdo = null;
                $pdo = null;

                copy($tmp_name, $db_file);
                echo json_encode(['success' => true, 'message' => 'Database successfully restored from backup!']);
            } catch (Exception $e) {
                echo json_encode(['success' => false, 'message' => 'Invalid database backup file: ' . $e->getMessage()]);
            }
        } else {
            echo json_encode(['success' => false, 'message' => 'No database backup file uploaded.']);
        }
        exit();

    } elseif ($action === 'get_admin_chat_threads') {
        try {
            $pdo->exec("DELETE FROM complaints WHERE created_at < DATETIME('now', '-30 days')");
            $pdo->exec("DELETE FROM notifications WHERE created_at < DATETIME('now', '-2 days')");
            $pdo->exec("DELETE FROM chat_messages WHERE created_at < DATETIME('now', '-2 days')");
        } catch (Exception $e) {}

        $admin_id = (int)$pdo->query("SELECT id FROM users WHERE role = 'admin' LIMIT 1")->fetchColumn();
        if ($admin_id <= 0) $admin_id = 1;

        $stmt = $pdo->query("
            SELECT u.id as student_id, u.name as student_name, u.phone, s.seat_number, sh.name as shift_name,
                   (SELECT message FROM chat_messages 
                    WHERE (sender_id = u.id AND receiver_id = $admin_id) OR (sender_id = $admin_id AND receiver_id = u.id) 
                    ORDER BY id DESC LIMIT 1) as last_message,
                   (SELECT created_at FROM chat_messages 
                    WHERE (sender_id = u.id AND receiver_id = $admin_id) OR (sender_id = $admin_id AND receiver_id = u.id) 
                    ORDER BY id DESC LIMIT 1) as last_message_time,
                   (SELECT COUNT(*) FROM chat_messages 
                    WHERE sender_id = u.id AND receiver_id = $admin_id AND is_read = 0) as unread_count
            FROM users u
            LEFT JOIN allocations a ON u.id = a.user_id AND a.status = 'active'
            LEFT JOIN seats s ON a.seat_id = s.id
            LEFT JOIN shifts sh ON a.shift_id = sh.id
            WHERE u.role = 'student' AND (u.is_deleted IS NULL OR u.is_deleted = 0)
            ORDER BY last_message_time DESC, u.name ASC
        ");
        $threads = $stmt->fetchAll();

        echo json_encode(['success' => true, 'threads' => $threads]);
        exit();

    } elseif ($action === 'get_admin_chat_messages') {
        $student_id = (int)($_GET['student_id'] ?? ($_POST['student_id'] ?? 0));
        $admin_id = (int)$pdo->query("SELECT id FROM users WHERE role = 'admin' LIMIT 1")->fetchColumn();
        if ($admin_id <= 0) $admin_id = 1;

        if ($student_id <= 0) {
            echo json_encode(['success' => false, 'message' => 'Student ID is required.']);
            exit();
        }

        // Mark student's messages as read
        $pdo->prepare("UPDATE chat_messages SET is_read = 1 WHERE sender_id = ? AND receiver_id = ?")
            ->execute([$student_id, $admin_id]);

        $stmt = $pdo->prepare("
            SELECT cm.*, u_send.name as sender_name
            FROM chat_messages cm
            JOIN users u_send ON cm.sender_id = u_send.id
            WHERE (cm.sender_id = ? AND cm.receiver_id = ?) OR (cm.sender_id = ? AND cm.receiver_id = ?)
            ORDER BY cm.id ASC
        ");
        $stmt->execute([$student_id, $admin_id, $admin_id, $student_id]);
        $messages = $stmt->fetchAll();

        $stmt_u = $pdo->prepare("SELECT id, name, phone, status FROM users WHERE id = ?");
        $stmt_u->execute([$student_id]);
        $student = $stmt_u->fetch();

        echo json_encode([
            'success' => true,
            'messages' => $messages,
            'student' => $student,
            'admin_id' => $admin_id
        ]);
        exit();

    } elseif ($action === 'send_admin_chat_message') {
        $student_id = (int)($_POST['student_id'] ?? 0);
        $msg_text = trim($_POST['message'] ?? '');

        if ($student_id <= 0 || empty($msg_text)) {
            echo json_encode(['success' => false, 'message' => 'Invalid student ID or message content.']);
            exit();
        }

        $admin_id = (int)$pdo->query("SELECT id FROM users WHERE role = 'admin' LIMIT 1")->fetchColumn();
        if ($admin_id <= 0) $admin_id = 1;

        $stmt = $pdo->prepare("INSERT INTO chat_messages (sender_id, receiver_id, message) VALUES (?, ?, ?)");
        $stmt->execute([$admin_id, $student_id, $msg_text]);
        $msg_id = $pdo->lastInsertId();

        // Also insert notification for student so app gets push notification pop-up
        $pdo->prepare("
            INSERT INTO notifications (title, message, user_id)
            VALUES ('New Message from Admin 💬', ?, ?)
        ")->execute([$msg_text, $student_id]);

        echo json_encode(['success' => true, 'message_id' => $msg_id]);
        exit();

    } elseif ($action === 'get_all_students') {
        try {
            $pdo->exec("ALTER TABLE users ADD COLUMN father_name TEXT");
        } catch (Exception $e) {}
        try {
            $pdo->exec("ALTER TABLE users ADD COLUMN address TEXT");
        } catch (Exception $e) {}

        $stmt = $pdo->query("
            SELECT u.id, u.name, u.email, u.phone, u.father_name, u.address, u.emergency_contact,
                   u.id_proof_type, u.id_proof_no, u.status, u.registered_device_id, u.created_at,
                   s.seat_number, s.row_label, sh.name as shift_name, sh.fee_amount, a.start_date
            FROM users u
            LEFT JOIN allocations a ON u.id = a.user_id AND a.status IN ('active', 'hold', 'waiting', 'approved')
            LEFT JOIN seats s ON a.seat_id = s.id
            LEFT JOIN shifts sh ON a.shift_id = sh.id
            WHERE u.role = 'student' AND (u.is_deleted IS NULL OR u.is_deleted = 0)
            ORDER BY u.id DESC
        ");
        $students = $stmt->fetchAll();

        echo json_encode(['success' => true, 'students' => $students]);
        exit();

    } elseif ($action === 'delete_student' || $action === 'soft_delete_student') {
        $student_id = (int)($_POST['student_id'] ?? ($_GET['student_id'] ?? 0));
        if ($student_id <= 0) {
            echo json_encode(['success' => false, 'message' => 'Invalid student ID.']);
            exit();
        }

        $stmt_name = $pdo->prepare("SELECT name FROM users WHERE id = ? AND role = 'student'");
        $stmt_name->execute([$student_id]);
        $student_name = $stmt_name->fetchColumn();

        if (!$student_name) {
            echo json_encode(['success' => false, 'message' => 'Student record not found.']);
            exit();
        }

        $now = date('Y-m-d H:i:s');
        $pdo->prepare("UPDATE users SET is_deleted = 1, deleted_at = ? WHERE id = ? AND role = 'student'")->execute([$now, $student_id]);
        $pdo->prepare("UPDATE allocations SET status = 'cancelled' WHERE user_id = ?")->execute([$student_id]);

        echo json_encode(['success' => true, 'message' => "Student '$student_name' moved to Recycle Bin (Kept for 30 days)."]);
        exit();

    } elseif ($action === 'get_recycle_bin_students') {
        // Auto-purge items older than 30 days
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

        $stmt = $pdo->query("
            SELECT u.id, u.name, u.email, u.phone, u.father_name, u.address, u.emergency_contact,
                   u.id_proof_type, u.id_proof_no, u.status, u.deleted_at, u.registered_device_id, u.created_at,
                   MAX(0, CAST(30 - (julianday('now') - julianday(u.deleted_at)) AS INTEGER)) as days_left
            FROM users u
            WHERE u.role = 'student' AND u.is_deleted = 1
            ORDER BY u.deleted_at DESC
        ");
        $deleted_students = $stmt->fetchAll();

        echo json_encode(['success' => true, 'students' => $deleted_students]);
        exit();

    } elseif ($action === 'restore_student') {
        $student_id = (int)($_POST['student_id'] ?? ($_GET['student_id'] ?? 0));
        if ($student_id <= 0) {
            echo json_encode(['success' => false, 'message' => 'Invalid student ID.']);
            exit();
        }

        $stmt_name = $pdo->prepare("SELECT name FROM users WHERE id = ? AND role = 'student'");
        $stmt_name->execute([$student_id]);
        $student_name = $stmt_name->fetchColumn();

        if (!$student_name) {
            echo json_encode(['success' => false, 'message' => 'Student record not found.']);
            exit();
        }

        $pdo->prepare("UPDATE users SET is_deleted = 0, deleted_at = NULL, status = 'pending' WHERE id = ? AND role = 'student'")->execute([$student_id]);

        echo json_encode(['success' => true, 'message' => "Student '$student_name' restored to active list successfully."]);
        exit();

    } elseif ($action === 'permanent_delete_student') {
        $student_id = (int)($_POST['student_id'] ?? ($_GET['student_id'] ?? 0));
        if ($student_id <= 0) {
            echo json_encode(['success' => false, 'message' => 'Invalid student ID.']);
            exit();
        }

        $stmt_name = $pdo->prepare("SELECT name FROM users WHERE id = ? AND role = 'student'");
        $stmt_name->execute([$student_id]);
        $student_name = $stmt_name->fetchColumn();

        if (!$student_name) {
            echo json_encode(['success' => false, 'message' => 'Student record not found.']);
            exit();
        }

        // Purge student record from all tables
        $pdo->prepare("DELETE FROM fee_payments WHERE user_id = ?")->execute([$student_id]);
        $pdo->prepare("DELETE FROM attendance WHERE user_id = ?")->execute([$student_id]);
        $pdo->prepare("DELETE FROM allocations WHERE user_id = ?")->execute([$student_id]);
        $pdo->prepare("DELETE FROM complaints WHERE user_id = ?")->execute([$student_id]);
        $pdo->prepare("DELETE FROM chat_messages WHERE sender_id = ? OR receiver_id = ?")->execute([$student_id, $student_id]);
        $pdo->prepare("DELETE FROM notifications WHERE user_id = ?")->execute([$student_id]);
        $pdo->prepare("DELETE FROM users WHERE id = ? AND role = 'student'")->execute([$student_id]);

        echo json_encode(['success' => true, 'message' => "Student record '$student_name' permanently deleted from database."]);
        exit();

    } elseif ($action === 'get_admin_notifications') {
        $req_user_id = (int)($_GET['user_id'] ?? ($_POST['user_id'] ?? 0));
        if ($req_user_id > 0) {
            $user_role = $pdo->query("SELECT role FROM users WHERE id = $req_user_id")->fetchColumn();
            if ($user_role !== 'admin') {
                echo json_encode(['success' => true, 'admin_notifications' => []]);
                exit();
            }
        }

        // Fetch new pending student registrations, open support tickets, unread direct chat messages, and admin notifications
        $admin_id = (int)$pdo->query("SELECT id FROM users WHERE role = 'admin' LIMIT 1")->fetchColumn();
        if ($admin_id <= 0) $admin_id = 1;

        $pending = $pdo->query("SELECT id, name, phone, created_at FROM users WHERE role = 'student' AND status = 'pending' ORDER BY id DESC LIMIT 5")->fetchAll();
        $open_complaints = $pdo->query("SELECT c.id, c.subject, c.category, u.name as student_name, c.created_at FROM complaints c JOIN users u ON c.user_id = u.id WHERE (c.status IS NULL OR c.status = '' OR c.status = 'open') ORDER BY c.id DESC LIMIT 5")->fetchAll();
        $unread_chats = $pdo->query("SELECT m.id, m.message, m.sender_id, u.name as student_name, m.created_at FROM chat_messages m JOIN users u ON m.sender_id = u.id WHERE (m.receiver_id = $admin_id OR m.receiver_id = 1 OR m.receiver_id = 0) AND (m.is_read = 0 OR m.is_read IS NULL) ORDER BY m.id DESC LIMIT 5")->fetchAll();
        $direct_notifs = $pdo->query("SELECT id, title, message, created_at FROM notifications WHERE user_id = $admin_id OR user_id = 0 ORDER BY id DESC LIMIT 5")->fetchAll();

        $admin_notifs = [];

        foreach ($pending as $p) {
            $admin_notifs[] = [
                'id' => 1000000 + (int)$p['id'],
                'type' => 'registration',
                'title' => '🎓 New Student Registration Pending!',
                'message' => "Student {$p['name']} (Phone: {$p['phone']}) registered. Click to assign seat desk.",
                'created_at' => $p['created_at']
            ];
        }

        foreach ($open_complaints as $c) {
            $admin_notifs[] = [
                'id' => 2000000 + (int)$c['id'],
                'type' => 'complaint',
                'title' => '⚠️ New Facility Support Request!',
                'message' => "{$c['student_name']} logged ticket: {$c['subject']} ({$c['category']}).",
                'created_at' => $c['created_at']
            ];
        }

        foreach ($unread_chats as $ch) {
            $admin_notifs[] = [
                'id' => 3000000 + (int)$ch['id'],
                'type' => 'chat',
                'title' => "💬 New Direct Message from {$ch['student_name']}",
                'message' => $ch['message'],
                'created_at' => $ch['created_at']
            ];
        }

        foreach ($direct_notifs as $dn) {
            $admin_notifs[] = [
                'id' => 4000000 + (int)$dn['id'],
                'type' => 'notice',
                'title' => $dn['title'],
                'message' => $dn['message'],
                'created_at' => $dn['created_at']
            ];
        }

        // Sort all admin notifications in strict LIFO order (Latest / Newest at top)
        usort($admin_notifs, function($a, $b) {
            return strcmp($b['created_at'] ?? '', $a['created_at'] ?? '');
        });

        echo json_encode([
            'success' => true,
            'admin_notifications' => $admin_notifs
        ]);
        exit();

    } elseif ($action === 'get_app_settings') {
        $settings = [];
        try {
            $rows = $pdo->query("SELECT setting_key, setting_value FROM system_settings")->fetchAll();
            foreach ($rows as $r) {
                $settings[$r['setting_key']] = $r['setting_value'];
            }
        } catch (Exception $e) {}

        echo json_encode([
            'success' => true,
            'settings' => [
                'app_name' => $settings['app_name'] ?? 'Self Study Library',
                'app_logo_url' => $settings['app_logo_url'] ?? '',
                'app_tagline' => $settings['app_tagline'] ?? 'Quiet Environment & High-Speed Wi-Fi'
            ]
        ]);
        exit();

    } elseif ($action === 'update_app_settings') {
        $app_name = trim($_POST['app_name'] ?? '');
        $app_logo_url = trim($_POST['app_logo_url'] ?? '');
        $app_tagline = trim($_POST['app_tagline'] ?? '');

        if (isset($_FILES['logo_file']) && $_FILES['logo_file']['error'] === UPLOAD_ERR_OK) {
            $uploads_dir = __DIR__ . '/../assets/uploads';
            if (!file_exists($uploads_dir)) {
                @mkdir($uploads_dir, 0777, true);
            }
            $ext = pathinfo($_FILES['logo_file']['name'], PATHINFO_EXTENSION);
            $filename = 'app_logo_' . time() . '.' . ($ext ?: 'png');
            $target_path = $uploads_dir . '/' . $filename;
            if (move_uploaded_file($_FILES['logo_file']['tmp_name'], $target_path)) {
                $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? "https" : "http";
                $host = $_SERVER['HTTP_HOST'] ?? 'library-management-hmwx.onrender.com';
                $app_logo_url = "$protocol://$host/assets/uploads/$filename";
            }
        }

        try {
            if ($app_name !== '') {
                $stmt = $pdo->prepare("INSERT OR REPLACE INTO system_settings (setting_key, setting_value) VALUES ('app_name', ?)");
                $stmt->execute([$app_name]);
            }
            if ($app_logo_url !== '') {
                $stmt = $pdo->prepare("INSERT OR REPLACE INTO system_settings (setting_key, setting_value) VALUES ('app_logo_url', ?)");
                $stmt->execute([$app_logo_url]);
            }
            if ($app_tagline !== '') {
                $stmt = $pdo->prepare("INSERT OR REPLACE INTO system_settings (setting_key, setting_value) VALUES ('app_tagline', ?)");
                $stmt->execute([$app_tagline]);
            }

            echo json_encode([
                'success' => true,
                'message' => 'App branding settings updated successfully!',
                'app_name' => $app_name,
                'app_logo_url' => $app_logo_url,
                'app_tagline' => $app_tagline
            ]);
        } catch (Exception $e) {
            echo json_encode(['success' => false, 'message' => 'Failed to update app settings: ' . $e->getMessage()]);
        }
        exit();

    } else {
        echo json_encode(['success' => false, 'message' => 'Invalid admin action specified.']);
        exit();
    }
} catch (Exception $e) {
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
    exit();
}
?>
