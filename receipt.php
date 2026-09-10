<?php
// receipt.php - Printable Digital Fee Payment Receipt

require_once __DIR__ . '/config/auth.php';

$receipt_no = trim($_GET['receipt_no'] ?? '');

if (empty($receipt_no)) {
    die("Receipt Number missing.");
}

$stmt = $pdo->prepare("
    SELECT fp.*, u.name as student_name, u.phone as student_phone, u.email as student_email, u.id_proof_type, u.id_proof_no,
           s.seat_number, s.row_label, sh.name as shift_name, sh.start_time, sh.end_time
    FROM fee_payments fp
    JOIN users u ON fp.user_id = u.id
    JOIN allocations a ON fp.allocation_id = a.id
    JOIN seats s ON a.seat_id = s.id
    JOIN shifts sh ON a.shift_id = sh.id
    WHERE fp.receipt_no = ?
");
$stmt->execute([$receipt_no]);
$receipt = $stmt->fetch();

if (!$receipt) {
    die("Receipt not found.");
}

// Check authorization if active session exists
if (isset($_SESSION['user_id'])) {
    $curr = current_user();
    if ($curr && $curr['role'] !== 'admin' && $curr['id'] != $receipt['user_id']) {
        die("Unauthorized access to receipt.");
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fee Receipt - <?php echo htmlspecialchars($receipt['receipt_no']); ?></title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        body {
            font-family: 'Inter', sans-serif;
            background: #f1f5f9;
            color: #0f172a;
            padding: 30px 15px;
        }
        .receipt-card {
            max-width: 650px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 12px;
            padding: 40px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
            border: 1px solid #cbd5e1;
            position: relative;
        }
        .header-brand {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px dashed #e2e8f0;
            padding-bottom: 20px;
            margin-bottom: 24px;
        }
        .receipt-title {
            font-size: 1.6rem;
            font-weight: 700;
            color: #4f46e5;
        }
        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 24px;
        }
        .info-box label {
            font-size: 0.8rem;
            color: #64748b;
            text-transform: uppercase;
            font-weight: 600;
            display: block;
        }
        .info-box span {
            font-size: 1rem;
            font-weight: 600;
            color: #0f172a;
        }
        .payment-table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 30px;
        }
        .payment-table th, .payment-table td {
            padding: 12px 16px;
            border-bottom: 1px solid #e2e8f0;
            text-align: left;
        }
        .payment-table th {
            background: #f8fafc;
            color: #475569;
            font-size: 0.85rem;
        }
        .paid-stamp {
            display: inline-block;
            padding: 8px 24px;
            border: 3px solid #10b981;
            color: #10b981;
            font-size: 1.4rem;
            font-weight: 800;
            text-transform: uppercase;
            letter-spacing: 2px;
            border-radius: 8px;
            transform: rotate(-5deg);
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
            .receipt-card { box-shadow: none; border: none; padding: 20px; }
            .no-print { display: none !important; }
        }
    </style>
</head>
<body>
    <div style="max-width: 650px; margin: 0 auto 20px auto; text-align: right;" class="no-print">
        <button onclick="window.print()" class="btn-print"><i class="fas fa-print"></i> Print Receipt</button>
    </div>

    <div class="receipt-card">
        <div class="header-brand">
            <div>
                <div class="receipt-title"><i class="fas fa-book-reader"></i> StudySpace Library</div>
                <div style="font-size: 0.85rem; color: #64748b;">Competition Exam Self-Study Hall</div>
                <div style="font-size: 0.8rem; color: #94a3b8; margin-top: 2px;">Phone: +91 98765 43210 &bull; GSTIN: 07AAAAA0000A1Z5</div>
            </div>
            <div style="text-align: right;">
                <div class="paid-stamp">PAID</div>
            </div>
        </div>

        <div class="info-grid">
            <div class="info-box">
                <label>Receipt Number</label>
                <span><?php echo htmlspecialchars($receipt['receipt_no']); ?></span>
            </div>
            <div class="info-box">
                <label>Payment Date</label>
                <span><?php echo date('d M Y, h:i A', strtotime($receipt['paid_date'])); ?></span>
            </div>
            <div class="info-box">
                <label>Student Name</label>
                <span><?php echo htmlspecialchars($receipt['student_name']); ?></span>
            </div>
            <div class="info-box">
                <label>Phone / Email</label>
                <span><?php echo htmlspecialchars($receipt['student_phone']); ?></span>
            </div>
            <div class="info-box">
                <label>Allotted Desk</label>
                <span>Desk <?php echo htmlspecialchars($receipt['seat_number']); ?> (Row <?php echo $receipt['row_label']; ?>)</span>
            </div>
            <div class="info-box">
                <label>Shift Timing</label>
                <span><?php echo htmlspecialchars($receipt['shift_name']); ?> (<?php echo date('g:i A', strtotime($receipt['start_time'])); ?> - <?php echo date('g:i A', strtotime($receipt['end_time'])); ?>)</span>
            </div>
        </div>

        <table class="payment-table">
            <thead>
                <tr>
                    <th>Description / Particulars</th>
                    <th>Billing Cycle</th>
                    <th>Payment Mode</th>
                    <th style="text-align: right;">Amount Paid</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Monthly Self-Study Desk Rent & Amenities</td>
                    <td><?php echo date('F Y', strtotime($receipt['month_year'] . '-01')); ?></td>
                    <td><?php echo htmlspecialchars($receipt['payment_mode'] ?? 'Cash'); ?></td>
                    <td style="text-align: right; font-weight: 700; font-size: 1.1rem; color: #4f46e5;">
                        ₹<?php echo number_format($receipt['amount'], 2); ?>
                    </td>
                </tr>
            </tbody>
        </table>

        <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 40px; border-top: 1px solid #e2e8f0; padding-top: 20px;">
            <div style="font-size: 0.8rem; color: #64748b;">
                <p>Thank you for studying with us!</p>
                <p style="margin-top: 2px;">This is a computer generated digital receipt.</p>
            </div>
            <div style="text-align: center;">
                <div style="font-family: 'Courier New', monospace; font-size: 0.85rem; font-weight: 700; color: #475569;">StudySpace Admin</div>
                <div style="font-size: 0.75rem; color: #94a3b8; border-top: 1px solid #cbd5e1; padding-top: 4px; margin-top: 4px; width: 140px;">Authorized Signature</div>
            </div>
        </div>
    </div>
</body>
</html>
