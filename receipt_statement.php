<?php
// receipt_statement.php - 12-Month Printable Fee Statement & Ledger Report

require_once __DIR__ . '/config/auth.php';
require_login();

$student_id = (int)($_GET['user_id'] ?? 0);
$curr_user = current_user();

if (!$student_id) {
    if ($curr_user['role'] === 'student') {
        $student_id = $curr_user['id'];
    } else {
        die("Student ID missing.");
    }
}

// Check authorization (Admin or the student themselves)
if ($curr_user['role'] !== 'admin' && $curr_user['id'] != $student_id) {
    die("Unauthorized access to fee statement.");
}

// Fetch Student Profile
$stmt_stu = $pdo->prepare("
    SELECT u.*, a.id as allocation_id, a.start_date, s.seat_number, s.row_label, sh.name as shift_name, sh.fee_amount
    FROM users u
    LEFT JOIN allocations a ON u.id = a.user_id AND a.status = 'active'
    LEFT JOIN seats s ON a.seat_id = s.id
    LEFT JOIN shifts sh ON a.shift_id = sh.id
    WHERE u.id = ?
");
$stmt_stu->execute([$student_id]);
$student = $stmt_stu->fetch();

if (!$student) {
    die("Student record not found.");
}

// Fetch 12-Month Fee History
$stmt_pay = $pdo->prepare("
    SELECT fp.*
    FROM fee_payments fp
    WHERE fp.user_id = ?
    ORDER BY fp.due_date DESC, fp.id DESC
    LIMIT 12
");
$stmt_pay->execute([$student_id]);
$payments = $stmt_pay->fetchAll();

$total_paid = 0;
foreach ($payments as $p) {
    if ($p['payment_status'] === 'paid') {
        $total_paid += (float)$p['amount'];
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>12-Month Fee Statement - <?php echo htmlspecialchars($student['name']); ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        body {
            font-family: 'Inter', sans-serif;
            background: #f8fafc;
            color: #0f172a;
            padding: 30px 15px;
            margin: 0;
        }
        .statement-card {
            max-width: 800px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.08);
            border: 1px solid #cbd5e1;
        }
        .header-brand {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px solid #4f46e5;
            padding-bottom: 20px;
            margin-bottom: 24px;
        }
        .title {
            font-size: 1.6rem;
            font-weight: 800;
            color: #4f46e5;
        }
        .subtitle {
            font-size: 0.85rem;
            color: #64748b;
            margin-top: 2px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 16px;
            background: #f1f5f9;
            padding: 16px;
            border-radius: 10px;
            margin-bottom: 24px;
        }
        .info-box label {
            font-size: 0.75rem;
            color: #64748b;
            text-transform: uppercase;
            font-weight: 700;
            display: block;
        }
        .info-box span {
            font-size: 0.95rem;
            font-weight: 600;
            color: #0f172a;
        }
        .custom-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 24px;
        }
        .custom-table th, .custom-table td {
            padding: 10px 14px;
            border-bottom: 1px solid #e2e8f0;
            text-align: left;
            font-size: 0.85rem;
        }
        .custom-table th {
            background: #f8fafc;
            color: #475569;
            font-weight: 700;
            text-transform: uppercase;
            font-size: 0.75rem;
        }
        .badge {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 6px;
            font-size: 0.75rem;
            font-weight: 700;
        }
        .badge-success { background: #d1fae5; color: #047857; }
        .badge-info { background: #dbeafe; color: #1d4ed8; }
        .badge-danger { background: #fee2e2; color: #b91c1c; }
        .badge-warning { background: #fef3c7; color: #b45309; }
        .summary-box {
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: #eef2ff;
            border: 1px solid #c7d2fe;
            padding: 16px 20px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .summary-box .amount {
            font-size: 1.4rem;
            font-weight: 800;
            color: #4f46e5;
        }
        .btn-print {
            background: #4f46e5;
            color: #fff;
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        @media print {
            body { background: #fff; padding: 0; }
            .statement-card { box-shadow: none; border: none; padding: 10px; }
            .no-print { display: none !important; }
        }
    </style>
</head>
<body>
    <div style="max-width: 800px; margin: 0 auto 20px auto; text-align: right;" class="no-print">
        <button onclick="window.print()" class="btn-print"><i class="fas fa-print"></i> Print / Save PDF Statement</button>
    </div>

    <div class="statement-card">
        <div class="header-brand">
            <div>
                <div class="title"><i class="fas fa-book-reader"></i> Keshav Library & Study Center</div>
                <div class="subtitle">Official 12-Month Membership Fee Ledger Statement</div>
            </div>
            <div style="text-align: right;">
                <span style="font-size: 0.8rem; color: #64748b;">Statement Date</span><br>
                <strong><?php echo date('d M Y'); ?></strong>
            </div>
        </div>

        <div class="info-grid">
            <div class="info-box">
                <label>Student Name</label>
                <span><?php echo htmlspecialchars($student['name']); ?></span>
            </div>
            <div class="info-box">
                <label>Phone / Contact</label>
                <span><?php echo htmlspecialchars($student['phone']); ?></span>
            </div>
            <div class="info-box">
                <label>Email Address</label>
                <span><?php echo htmlspecialchars($student['email']); ?></span>
            </div>
            <div class="info-box">
                <label>Allotted Desk</label>
                <span><?php echo $student['seat_number'] ? 'Desk ' . htmlspecialchars($student['seat_number']) : 'Not Allotted'; ?></span>
            </div>
            <div class="info-box">
                <label>Shift Timing</label>
                <span><?php echo htmlspecialchars($student['shift_name'] ?? 'N/A'); ?></span>
            </div>
            <div class="info-box">
                <label>Joining Date</label>
                <span><?php echo format_date($student['start_date']); ?></span>
            </div>
        </div>

        <table class="custom-table">
            <thead>
                <tr>
                    <th>Cycle Month</th>
                    <th>Cycle Due Date</th>
                    <th>Payment Status</th>
                    <th>Paid Date</th>
                    <th>Mode</th>
                    <th>Receipt No</th>
                    <th style="text-align: right;">Amount Paid</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($payments)): ?>
                    <tr><td colspan="7" style="text-align: center; color: #64748b;">No payment records found.</td></tr>
                <?php else: ?>
                    <?php foreach ($payments as $p): ?>
                        <?php 
                            $isPaid = $p['payment_status'] === 'paid';
                            $isAdvance = $p['month_year'] > date('Y-m');
                        ?>
                        <tr>
                            <td>
                                <strong><?php echo date('F Y', strtotime($p['month_year'] . '-01')); ?></strong>
                                <?php if ($isAdvance): ?>
                                    <span class="badge badge-info" style="font-size:0.65rem;">ADVANCE</span>
                                <?php endif; ?>
                            </td>
                            <td><?php echo format_date($p['due_date']); ?></td>
                            <td>
                                <?php if ($isPaid): ?>
                                    <span class="badge badge-success">PAID</span>
                                <?php elseif ($p['payment_status'] === 'overdue'): ?>
                                    <span class="badge badge-danger">OVERDUE</span>
                                <?php else: ?>
                                    <span class="badge badge-warning">PENDING</span>
                                <?php endif; ?>
                            </td>
                            <td><?php echo $p['paid_date'] ? format_date($p['paid_date']) : '<span style="color:#94a3b8;">--</span>'; ?></td>
                            <td><?php echo htmlspecialchars($p['payment_mode'] ?? 'N/A'); ?></td>
                            <td><code><?php echo htmlspecialchars($p['receipt_no'] ?? 'N/A'); ?></code></td>
                            <td style="text-align: right; font-weight: 700; color: #4f46e5;">
                                ₹<?php echo number_format($p['amount'], 2); ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>

        <div class="summary-box">
            <div>
                <span style="font-size: 0.85rem; color: #475569; font-weight: 600;">Total Fees Collected (12-Month Period)</span><br>
                <span style="font-size: 0.75rem; color: #64748b;">Total verified digital receipts issued</span>
            </div>
            <div class="amount">
                ₹<?php echo number_format($total_paid, 2); ?>
            </div>
        </div>

        <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 30px; border-top: 1px solid #e2e8f0; padding-top: 16px;">
            <div style="font-size: 0.75rem; color: #64748b;">
                <p>Computer generated 12-month membership ledger statement.</p>
                <p style="margin-top: 2px;">Keshav Library Management System &bull; All Rights Reserved.</p>
            </div>
            <div style="text-align: center;">
                <div style="font-size: 0.85rem; font-weight: 700; color: #475569;">Keshav Library Admin</div>
                <div style="font-size: 0.7rem; color: #94a3b8; border-top: 1px solid #cbd5e1; padding-top: 3px; margin-top: 3px; width: 140px;">Authorized Signatory</div>
            </div>
        </div>
    </div>
</body>
</html>
