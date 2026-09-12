<?php
// master_12month_fee_report.php - Consolidated 12-Month Fee Ledger & CSV/Excel Export for Admin

require_once __DIR__ . '/config/auth.php';

// Only Admin can access
require_admin();

$format = $_GET['format'] ?? 'html'; // html or csv

// Fetch all students (active, approved, pending, hold, or deleted/left in last 12 months)
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

// Build 12-Month data for each student
$report_data = [];
$total_grand_collected = 0.0;
$total_grand_overdue = 0.0;

foreach ($students as $stu) {
    $uid = $stu['user_id'];
    
    // Fetch fee payments for this student
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
    $overdue_months = [];
    
    foreach ($payments as $p) {
        if ($p['payment_status'] === 'paid') {
            $paid_amount += (float)$p['amount'];
            $paid_months[] = $p['month_year'];
        } elseif ($p['payment_status'] === 'overdue') {
            $overdue_amount += (float)$p['amount'];
            $overdue_months[] = $p['month_year'];
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
        'paid_months_list' => implode(', ', array_slice($paid_months, 0, 12)),
        'overdue_months_list' => implode(', ', $overdue_months),
    ];
}

// CSV EXCEL DOWNLOAD HANDLER
if ($format === 'csv') {
    $filename = "12_Month_Master_Fee_Ledger_" . date('Y-m-d') . ".csv";
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    
    $output = fopen('php://output', 'w');
    fprintf($output, chr(0xEF).chr(0xBB).chr(0xBF)); // UTF-8 BOM
    
    fputcsv($output, [
        'Student ID',
        'Student Name',
        'Mobile Phone',
        'Email Address',
        'Status',
        'Desk Number',
        'Shift Timing',
        'Monthly Fee (INR)',
        'Enrollment Date',
        'Paid Cycles Count',
        'Total Fee Collected (INR)',
        'Total Overdue Amount (INR)',
        'Paid Months History',
        'Overdue Months'
    ]);
    
    foreach ($report_data as $row) {
        fputcsv($output, [
            $row['user_id'],
            $row['name'],
            $row['phone'],
            $row['email'],
            $row['status'],
            $row['seat_number'],
            $row['shift_name'],
            $row['monthly_fee'],
            format_date($row['start_date']),
            $row['paid_cycles_count'],
            $row['total_paid'],
            $row['total_overdue'],
            $row['paid_months_list'],
            $row['overdue_months_list']
        ]);
    }
    
    fputcsv($output, []);
    fputcsv($output, ['GRAND TOTALS', '', '', '', '', '', '', '', '', '', $total_grand_collected, $total_grand_overdue, '', '']);
    fclose($output);
    exit();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>12-Month Master Fee Ledger & Annual Report</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        body { font-family: 'Inter', sans-serif; background: #f8fafc; color: #0f172a; padding: 24px; margin: 0; }
        .report-card { max-width: 1100px; margin: 0 auto; background: #ffffff; border-radius: 14px; padding: 30px; box-shadow: 0 10px 25px rgba(0,0,0,0.06); border: 1px solid #cbd5e1; }
        .header-bar { display: flex; justify-content: space-between; align-items: center; border-bottom: 3px solid #1d4ed8; padding-bottom: 16px; margin-bottom: 20px; }
        .title { font-size: 1.6rem; font-weight: 800; color: #1d4ed8; }
        .subtitle { font-size: 0.85rem; color: #64748b; margin-top: 4px; }
        .summary-banner { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 24px; }
        .sum-card { background: #f1f5f9; padding: 16px; border-radius: 10px; text-align: center; border: 1px solid #e2e8f0; }
        .sum-card label { font-size: 0.75rem; font-weight: 700; color: #64748b; text-transform: uppercase; display: block; }
        .sum-card .val { font-size: 1.5rem; font-weight: 800; margin-top: 4px; }
        .table-responsive { overflow-x: auto; margin-bottom: 20px; }
        .report-table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
        .report-table th, .report-table td { padding: 12px 10px; border-bottom: 1px solid #e2e8f0; text-align: left; }
        .report-table th { background: #f1f5f9; color: #334155; font-weight: 700; text-transform: uppercase; font-size: 0.72rem; }
        .badge { display: inline-block; padding: 3px 8px; border-radius: 6px; font-size: 0.72rem; font-weight: 700; }
        .badge-active { background: #d1fae5; color: #047857; }
        .badge-left { background: #fee2e2; color: #b91c1c; }
        .badge-pending { background: #fef3c7; color: #b45309; }
        .btn-group { display: flex; gap: 10px; }
        .btn { padding: 10px 18px; border-radius: 8px; font-weight: 700; font-size: 0.85rem; cursor: pointer; text-decoration: none; display: inline-flex; align-items: center; gap: 8px; border: none; }
        .btn-excel { background: #10b981; color: #fff; }
        .btn-print { background: #1d4ed8; color: #fff; }
        @media print {
            body { background: #fff; padding: 0; }
            .report-card { box-shadow: none; border: none; padding: 0; max-width: 100%; }
            .no-print { display: none !important; }
        }
    </style>
</head>
<body>
    <div style="max-width: 1100px; margin: 0 auto 16px auto; display: flex; justify-content: space-between; align-items: center;" class="no-print">
        <a href="admin_dashboard.php" class="btn" style="background:#64748b; color:#fff;"><i class="fas fa-arrow-left"></i> Back to Dashboard</a>
        <div class="btn-group">
            <a href="master_12month_fee_report.php?format=csv" class="btn btn-excel"><i class="fas fa-file-excel"></i> Export Excel / CSV</a>
            <button onclick="window.print()" class="btn btn-print"><i class="fas fa-print"></i> Print / Save PDF</button>
        </div>
    </div>

    <div class="report-card">
        <div class="header-bar">
            <div>
                <div class="title"><i class="fas fa-book-reader"></i> StudySpace Competition Library</div>
                <div class="subtitle">12-Month Master Membership Fee Ledger & Annual Financial Report</div>
            </div>
            <div style="text-align: right;">
                <span style="font-size: 0.8rem; color: #64748b;">Report Generated</span><br>
                <strong><?php echo date('d M Y, g:i A'); ?></strong>
            </div>
        </div>

        <div class="summary-banner">
            <div class="sum-card">
                <label>Total Students Enrolled</label>
                <div class="val" style="color: #1d4ed8;"><?php echo count($report_data); ?></div>
            </div>
            <div class="sum-card">
                <label>12-Month Total Fee Collected</label>
                <div class="val" style="color: #10b981;">₹<?php echo number_format($total_grand_collected, 2); ?></div>
            </div>
            <div class="sum-card">
                <label>Total Overdue Amount</label>
                <div class="val" style="color: #ef4444;">₹<?php echo number_format($total_grand_overdue, 2); ?></div>
            </div>
        </div>

        <div class="table-responsive">
            <table class="report-table">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Student Name</th>
                        <th>Phone / Contact</th>
                        <th>Status</th>
                        <th>Desk</th>
                        <th>Shift</th>
                        <th>Joining Date</th>
                        <th>Paid Cycles</th>
                        <th>Total Paid (₹)</th>
                        <th>Overdue (₹)</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($report_data as $idx => $r): ?>
                        <tr>
                            <td><?php echo $idx + 1; ?></td>
                            <td>
                                <strong><?php echo htmlspecialchars($r['name']); ?></strong><br>
                                <small style="color: #64748b;"><?php echo htmlspecialchars($r['email']); ?></small>
                            </td>
                            <td><?php echo htmlspecialchars($r['phone']); ?></td>
                            <td>
                                <?php if ($r['status'] === 'Active'): ?>
                                    <span class="badge badge-active">Active</span>
                                <?php elseif ($r['status'] === 'Left / Deleted'): ?>
                                    <span class="badge badge-left">Left / Past</span>
                                <?php else: ?>
                                    <span class="badge badge-pending"><?php echo $r['status']; ?></span>
                                <?php endif; ?>
                            </td>
                            <td><strong><?php echo htmlspecialchars($r['seat_number']); ?></strong></td>
                            <td><?php echo htmlspecialchars($r['shift_name']); ?></td>
                            <td><?php echo format_date($r['start_date']); ?></td>
                            <td><strong><?php echo $r['paid_cycles_count']; ?></strong> months</td>
                            <td style="font-weight: 700; color: #10b981;">₹<?php echo number_format($r['total_paid'], 2); ?></td>
                            <td style="font-weight: 700; color: <?php echo $r['total_overdue'] > 0 ? '#ef4444' : '#64748b'; ?>;">
                                ₹<?php echo number_format($r['total_overdue'], 2); ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; border-top: 2px solid #e2e8f0; padding-top: 14px; font-size: 0.8rem; color: #64748b;">
            <div>Master 12-Month Consolidated Ledger &bull; StudySpace Self Study Hall</div>
            <div><strong>Page 1 of 1</strong></div>
        </div>
    </div>
</body>
</html>
