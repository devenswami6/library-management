<?php
// admin_dashboard.php - Admin Control Panel

$page_title = "Admin Dashboard";
require_once __DIR__ . '/includes/header.php';
require_admin();

// Auto-sync status for all students with active seat allocations
$pdo->exec("UPDATE users SET status = 'approved' WHERE (status = 'pending' OR status = 'active') AND id IN (SELECT user_id FROM allocations WHERE status = 'active')");

// Analytics Counters
$total_students = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student'")->fetchColumn();
$approved_students = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student' AND status = 'approved'")->fetchColumn();
$pending_students = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student' AND status = 'pending'")->fetchColumn();
$hold_students = $pdo->query("SELECT COUNT(*) FROM users WHERE role = 'student' AND status = 'hold'")->fetchColumn();

$total_seats = $pdo->query("SELECT COUNT(*) FROM seats WHERE is_active = 1")->fetchColumn();
$occupied_seats = $pdo->query("SELECT COUNT(DISTINCT seat_id) FROM allocations WHERE status = 'active'")->fetchColumn();
$vacant_seats = max(0, $total_seats - $occupied_seats);

// Today's attendance counters
$today = date('Y-m-d');
$today_present = $pdo->query("SELECT COUNT(*) FROM attendance WHERE date = '$today' AND check_out_time IS NULL")->fetchColumn();
$today_total_checkins = $pdo->query("SELECT COUNT(*) FROM attendance WHERE date = '$today'")->fetchColumn();

// Fetch Shifts & Seats for modals and dropdowns
$shifts = $pdo->query("SELECT * FROM shifts ORDER BY id ASC")->fetchAll();
$active_shifts = array_filter($shifts, function($s) { return $s['is_active'] == 1; });
$seats = $pdo->query("SELECT * FROM seats WHERE is_active = 1 ORDER BY row_label ASC, seat_number ASC")->fetchAll();
$all_allocations = $pdo->query("SELECT seat_id, shift_id, user_id FROM allocations WHERE status = 'active'")->fetchAll();

// Fetch All Students with Allocations
$stmt_students = $pdo->query("
    SELECT u.*, a.id as allocation_id, a.seat_id, a.shift_id, a.start_date, s.seat_number, s.row_label, sh.name as shift_name, sh.fee_amount
    FROM users u
    LEFT JOIN allocations a ON u.id = a.user_id AND a.status IN ('active', 'hold', 'waiting')
    LEFT JOIN seats s ON a.seat_id = s.id
    LEFT JOIN shifts sh ON a.shift_id = sh.id
    WHERE u.role = 'student' AND (u.is_deleted IS NULL OR u.is_deleted = 0)
    ORDER BY u.id DESC
");
$students = $stmt_students->fetchAll();

// Fetch Recycle Bin Deleted Students (Kept for 30 days)
$stmt_bin = $pdo->query("
    SELECT u.*, MAX(0, CAST(30 - (julianday('now') - julianday(u.deleted_at)) AS INTEGER)) as days_left
    FROM users u
    WHERE u.role = 'student' AND u.is_deleted = 1
    ORDER BY u.deleted_at DESC
");
$recycle_bin_students = $stmt_bin->fetchAll();

// Fetch Fee Management Ledger
$fee_ledger = [];
foreach ($students as $stu) {
    if ($stu['status'] === 'approved' && $stu['allocation_id']) {
        $status_info = get_student_fee_status($pdo, $stu['allocation_id'], $stu['start_date']);
        $fee_ledger[] = array_merge($stu, ['fee_info' => $status_info]);
    }
}

// Fetch Full Attendance Roster for Today
$stmt_att_full = $pdo->query("
    SELECT u.id as student_id, u.name as student_name, u.phone, s.seat_number, sh.name as shift_name,
           att.id as attendance_id, att.check_in_time, att.check_out_time
    FROM users u
    JOIN allocations a ON u.id = a.user_id AND a.status = 'active'
    JOIN seats s ON a.seat_id = s.id
    JOIN shifts sh ON a.shift_id = sh.id
    LEFT JOIN attendance att ON u.id = att.user_id AND att.date = '$today'
    WHERE u.role = 'student' AND u.status = 'approved'
    ORDER BY att.check_in_time DESC, u.name ASC
");
$attendance_roster = $stmt_att_full->fetchAll();

// Fetch Complaints
$stmt_comp_all = $pdo->query("
    SELECT c.*, u.name as student_name, u.phone
    FROM complaints c
    JOIN users u ON c.user_id = u.id
    ORDER BY c.id DESC
");
$complaints_all = $stmt_comp_all->fetchAll();

// Fetch Sent Notifications Log
$stmt_notifs = $pdo->query("
    SELECT n.*, u.name as student_name
    FROM notifications n
    LEFT JOIN users u ON n.user_id = u.id
    ORDER BY n.id DESC
");
$sent_notifications = $stmt_notifs->fetchAll();

$active_tab = $_GET['tab'] ?? 'seatmap';
?>

<script>
    const isAdmin = true;
</script>

<!-- Welcome Admin Banner -->
<div class="card" style="border-left: 4px solid var(--accent-primary);">
    <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px;">
        <div>
            <h2><i class="fas fa-user-shield" style="color: var(--accent-primary);"></i> Admin Command Center</h2>
            <p style="color: var(--text-muted); font-size: 0.9rem;">
                Manage student registrations, seat allotments, shift timings, fee collections, and data backups.
            </p>
        </div>
        <div style="display: flex; gap: 10px; flex-wrap: wrap;">
            <a href="api/admin_actions.php?action=export_csv" class="btn btn-secondary btn-sm"><i class="fas fa-file-excel" style="color:#10b981;"></i> Export Excel (CSV)</a>
            <a href="api/admin_actions.php?action=backup_db" class="btn btn-secondary btn-sm"><i class="fas fa-download" style="color:#0284c7;"></i> Download DB Backup</a>
            <button class="btn btn-primary btn-sm" onclick="openModal('modalApproveAllot')">
                <i class="fas fa-plus-circle"></i> Quick Seat Allotment
            </button>
        </div>
    </div>
</div>

<!-- Stats Counter Grid -->
<div class="grid-4" style="margin-bottom: 24px;">
    <div class="stat-card">
        <div class="stat-icon" style="background: rgba(79, 70, 229, 0.1); color: var(--accent-primary);">
            <i class="fas fa-users"></i>
        </div>
        <div>
            <div class="stat-value"><?php echo $total_students; ?></div>
            <div class="stat-label">Total Registered Students</div>
        </div>
    </div>

    <div class="stat-card">
        <div class="stat-icon" style="background: rgba(16, 185, 129, 0.1); color: #059669;">
            <i class="fas fa-chair"></i>
        </div>
        <div>
            <div class="stat-value"><?php echo $occupied_seats; ?> / <?php echo $total_seats; ?></div>
            <div class="stat-label">Occupied Desks (<?php echo $vacant_seats; ?> Vacant)</div>
        </div>
    </div>

    <div class="stat-card">
        <div class="stat-icon" style="background: rgba(245, 158, 11, 0.1); color: #b45309;">
            <i class="fas fa-clock"></i>
        </div>
        <div>
            <div class="stat-value"><?php echo $pending_students; ?> Pending</div>
            <div class="stat-label"><?php echo $hold_students; ?> On Waiting List</div>
        </div>
    </div>

    <div class="stat-card">
        <div class="stat-icon" style="background: rgba(2, 132, 199, 0.1); color: #0284c7;">
            <i class="fas fa-user-check"></i>
        </div>
        <div>
            <div class="stat-value"><?php echo $today_present; ?> Inside</div>
            <div class="stat-label"><?php echo $today_total_checkins; ?> Total Check-ins Today</div>
        </div>
    </div>
</div>

<!-- Main Admin Tabs -->
<div class="card">
    <div class="tab-navigation">
        <button class="tab-btn <?php echo $active_tab === 'seatmap' ? 'active' : ''; ?>" data-tab="tabAdminSeatMap">
            <i class="fas fa-th"></i> Visual Seat Map Grid
        </button>
        <button class="tab-btn <?php echo $active_tab === 'students' ? 'active' : ''; ?>" data-tab="tabAdminStudents">
            <i class="fas fa-user-graduate"></i> Student Approvals (<?php echo $pending_students; ?> New)
        </button>
        <button class="tab-btn <?php echo $active_tab === 'fees' ? 'active' : ''; ?>" data-tab="tabAdminFees">
            <i class="fas fa-file-invoice-dollar"></i> Monthly Fee Ledger
        </button>
        <button class="tab-btn <?php echo $active_tab === 'attendance' ? 'active' : ''; ?>" data-tab="tabAdminAttendance">
            <i class="fas fa-calendar-check"></i> Live Attendance Manager
        </button>
        <button class="tab-btn <?php echo $active_tab === 'notifs' ? 'active' : ''; ?>" data-tab="tabAdminNotifs">
            <i class="fas fa-bell"></i> Send Notifications & Announcements
        </button>
        <button class="tab-btn <?php echo $active_tab === 'complaints' ? 'active' : ''; ?>" data-tab="tabAdminComplaints">
            <i class="fas fa-headset"></i> Complaints Desk
        </button>
        <button class="tab-btn <?php echo $active_tab === 'chat' ? 'active' : ''; ?>" data-tab="tabAdminChat">
            <i class="fas fa-comments" style="color: #06b6d4;"></i> Direct Student Chat
        </button>
        <button class="tab-btn <?php echo $active_tab === 'settings' ? 'active' : ''; ?>" data-tab="tabAdminSettings">
            <i class="fas fa-cog"></i> Shift Timings & Backups
        </button>
        <button class="tab-btn <?php echo $active_tab === 'recyclebin' ? 'active' : ''; ?>" data-tab="tabAdminRecycleBin">
            <i class="fas fa-trash-alt" style="color: #ef4444;"></i> Recycle Bin (30-Day Purge)
            <?php if (!empty($recycle_bin_students)): ?>
                <span class="badge badge-danger" style="margin-left: 4px;"><?php echo count($recycle_bin_students); ?></span>
            <?php endif; ?>
        </button>
    </div>

    <!-- TAB 1: VISUAL SEAT MAP GRID -->
    <div id="tabAdminSeatMap" class="tab-pane <?php echo $active_tab === 'seatmap' ? 'active' : ''; ?>">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px; margin-bottom: 16px;">
            <h3><i class="fas fa-map-marked-alt" style="color: var(--accent-primary);"></i> Interactive Library Seat Layout Matrix</h3>
            <div style="display: flex; align-items: center; gap: 10px;">
                <label class="form-label" style="margin: 0;">Select Shift:</label>
                <select id="seatMapShiftSelector" class="form-control" style="width: auto; padding: 6px 12px;">
                    <?php foreach ($shifts as $s): ?>
                        <?php if ($s['is_active']): ?>
                            <option value="<?php echo $s['id']; ?>"><?php echo htmlspecialchars($s['name']); ?></option>
                        <?php endif; ?>
                    <?php endforeach; ?>
                </select>
            </div>
        </div>

        <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 16px;">
            <i class="fas fa-info-circle"></i> Click on any <strong>Green Available Desk</strong> to quickly assign a student to that seat!
        </p>

        <div class="seat-map-legend">
            <div class="legend-item"><div class="legend-color" style="background: var(--color-success-bg); border: 1px solid var(--color-success-border);"></div> Available Desk</div>
            <div class="legend-item"><div class="legend-color" style="background: var(--color-danger-bg); border: 1px solid var(--color-danger-border);"></div> Booked Desk</div>
            <div class="legend-item"><div class="legend-color" style="background: var(--color-warning-bg); border: 1px solid var(--color-warning-border);"></div> On Hold / Pending</div>
        </div>

        <div id="seatGridContainer" class="seat-map-container">
            <!-- Loaded via JS -->
        </div>
    </div>

    <!-- TAB 2: STUDENT APPROVALS & ALLOTMENTS -->
    <div id="tabAdminStudents" class="tab-pane <?php echo $active_tab === 'students' ? 'active' : ''; ?>">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px; margin-bottom: 20px;">
            <div>
                <h3><i class="fas fa-user-check" style="color: var(--accent-primary);"></i> Student Registrations & Allotments</h3>
                <p style="font-size: 0.85rem; color: var(--text-muted);">Review pending student requests, assign seat desks, or import/export Excel files.</p>
            </div>
            <div style="display: flex; gap: 10px;">
                <a href="api/admin_actions.php?action=export_csv" class="btn btn-secondary btn-sm"><i class="fas fa-file-excel" style="color:#10b981;"></i> Export Excel (CSV)</a>
                <button class="btn btn-primary btn-sm" onclick="openModal('modalImportCSV')"><i class="fas fa-file-import"></i> Bulk Import CSV</button>
            </div>
        </div>

        <div class="table-responsive">
            <table class="custom-table">
                <thead>
                    <tr>
                        <th>Student Name</th>
                        <th>Contact / Phone</th>
                        <th>ID Proof Details</th>
                        <th>Reg. Date</th>
                        <th>Allotted Seat</th>
                        <th>Shift Timing</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($students)): ?>
                        <tr><td colspan="8" style="text-align: center; color: var(--text-muted);">No student records found.</td></tr>
                    <?php else: ?>
                        <?php foreach ($students as $stu): ?>
                            <tr>
                                <td>
                                    <strong><?php echo htmlspecialchars($stu['name']); ?></strong><br>
                                    <small style="color: var(--text-muted);"><?php echo htmlspecialchars($stu['email']); ?></small>
                                </td>
                                <td>
                                    <?php echo htmlspecialchars($stu['phone']); ?><br>
                                    <small style="color: var(--text-dim);">Emg: <?php echo htmlspecialchars($stu['emergency_contact'] ?? 'N/A'); ?></small>
                                </td>
                                <td>
                                    <span class="badge badge-info"><?php echo htmlspecialchars($stu['id_proof_type'] ?? 'ID Proof'); ?></span><br>
                                    <small><code><?php echo htmlspecialchars($stu['id_proof_no'] ?? 'N/A'); ?></code></small>
                                </td>
                                <td><?php echo format_date($stu['created_at']); ?></td>
                                <td>
                                    <?php if ($stu['seat_number']): ?>
                                        <span class="badge badge-success" style="font-size: 0.85rem;">Desk <?php echo htmlspecialchars($stu['seat_number']); ?></span>
                                    <?php else: ?>
                                        <span class="badge badge-warning">Not Allotted</span>
                                    <?php endif; ?>
                                </td>
                                <td><?php echo htmlspecialchars($stu['shift_name'] ?? 'N/A'); ?></td>
                                <td>
                                    <?php if ($stu['status'] === 'approved' || $stu['status'] === 'active'): ?>
                                        <span class="badge badge-success">Approved</span>
                                    <?php elseif ($stu['status'] === 'hold'): ?>
                                        <span class="badge badge-warning">On Hold</span>
                                    <?php elseif ($stu['status'] === 'cancelled'): ?>
                                        <span class="badge badge-danger">Cancelled</span>
                                    <?php else: ?>
                                        <span class="badge badge-info">Pending Approval</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <div style="display: flex; gap: 4px; flex-wrap: wrap;">
                                        <button class="btn btn-info btn-sm" onclick='openStudentDetailsModal(<?php echo json_encode($stu, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP); ?>)' title="View Full Student Details">
                                            <i class="fas fa-eye"></i> Details
                                        </button>

                                        <button class="btn btn-primary btn-sm" onclick="openApproveModal(<?php echo $stu['id']; ?>, <?php echo $stu['seat_id'] ?? 0; ?>, <?php echo $stu['shift_id'] ?? 1; ?>)" title="Allot or Edit Desk">
                                            <i class="fas fa-edit"></i> Desk
                                        </button>
                                        
                                        <?php if ($stu['status'] !== 'hold'): ?>
                                            <form action="api/admin_actions.php" method="POST" style="display:inline;">
                                                <input type="hidden" name="action" value="hold_student">
                                                <input type="hidden" name="user_id" value="<?php echo $stu['id']; ?>">
                                                <button type="submit" class="btn btn-warning btn-sm" title="Put on Hold / Waiting"><i class="fas fa-pause"></i></button>
                                            </form>
                                        <?php endif; ?>

                                        <form action="api/admin_actions.php" method="POST" style="display:inline;" onsubmit="return confirm('⚠️ PERMANENT DELETE WARNING:\n\nAre you sure you want to PERMANENTLY DELETE student \'<?php echo addslashes($stu['name']); ?>\'?\n\nThis will permanently erase all attendance, fee payments, chat messages, and seat allocations.');">
                                            <input type="hidden" name="action" value="delete_student">
                                            <input type="hidden" name="user_id" value="<?php echo $stu['id']; ?>">
                                            <button type="submit" class="btn btn-danger btn-sm" title="Permanently Delete Student Record"><i class="fas fa-trash-alt"></i> Delete</button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>

    <!-- TAB 3: MONTHLY FEE LEDGER & RENEWAL TRACKER -->
    <div id="tabAdminFees" class="tab-pane <?php echo $active_tab === 'fees' ? 'active' : ''; ?>">
        <h3><i class="fas fa-file-invoice-dollar" style="color: var(--accent-primary);"></i> Monthly Fee Renewal & Collection Ledger</h3>
        <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 20px;">
            Fees are automatically tracked based on each student's joining date.
        </p>

        <div class="table-responsive">
            <table class="custom-table">
                <thead>
                    <tr>
                        <th>Student Name</th>
                        <th>Desk & Shift</th>
                        <th>Joining Date</th>
                        <th>Current Cycle Due Date</th>
                        <th>Fee Amount</th>
                        <th>Payment Status</th>
                        <th>Record Collection</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($fee_ledger)): ?>
                        <tr><td colspan="7" style="text-align: center; color: var(--text-muted);">No active student fee records found.</td></tr>
                    <?php else: ?>
                        <?php foreach ($fee_ledger as $row): ?>
                            <?php $info = $row['fee_info']; ?>
                            <tr>
                                <td>
                                    <strong><?php echo htmlspecialchars($row['name']); ?></strong><br>
                                    <small style="color: var(--text-muted);"><?php echo htmlspecialchars($row['phone']); ?></small>
                                </td>
                                <td>
                                    <span class="badge badge-info">Desk <?php echo htmlspecialchars($row['seat_number']); ?></span><br>
                                    <small><?php echo htmlspecialchars($row['shift_name']); ?></small>
                                </td>
                                <td><?php echo format_date($row['start_date']); ?></td>
                                <td><strong><?php echo format_date($info['due_date']); ?></strong></td>
                                <td><?php echo format_currency($row['fee_amount']); ?></td>
                                <td>
                                    <span class="badge <?php echo $info['badge_class']; ?>">
                                        <?php echo $info['label']; ?>
                                    </span>
                                </td>
                                <td>
                                    <div style="display:flex; gap:6px; flex-wrap:wrap;">
                                        <button class="btn btn-success btn-sm" onclick="openPaymentModal(<?php echo $row['allocation_id']; ?>, <?php echo $row['id']; ?>, '<?php echo addslashes($row['name']); ?>', <?php echo $row['fee_amount']; ?>, '<?php echo $info['target_month']; ?>')">
                                            <i class="fas fa-cash-register"></i> <?php echo !empty($info['is_advance']) ? 'Collect Advance Fee (' . date('M Y', strtotime($info['target_month'].'-01')) . ')' : 'Collect Fee (' . date('M Y', strtotime($info['target_month'].'-01')) . ')'; ?>
                                        </button>
                                        <button class="btn btn-secondary btn-sm" onclick="openStudentHistoryModal(<?php echo $row['id']; ?>, '<?php echo addslashes($row['name']); ?>')">
                                            <i class="fas fa-history"></i> 12-Mo History & PDF
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>

    <!-- TAB 4: LIVE ATTENDANCE MANAGER -->
    <div id="tabAdminAttendance" class="tab-pane <?php echo $active_tab === 'attendance' ? 'active' : ''; ?>">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px; margin-bottom: 16px;">
            <div>
                <h3><i class="fas fa-calendar-check" style="color: var(--accent-primary);"></i> Live Attendance & Present Hall Manager</h3>
                <p style="font-size: 0.85rem; color: var(--text-muted);">
                    Admin can view who is inside the hall, perform manual check-in, or force check-out students who left without marking exit.
                </p>
            </div>
            <div>
                <span class="badge badge-success" style="font-size: 0.9rem; padding: 6px 12px;">
                    <i class="fas fa-user-clock"></i> Currently Inside Hall: <?php echo $today_present; ?> Students
                </span>
            </div>
        </div>

        <div class="table-responsive" style="margin-top: 16px;">
            <table class="custom-table">
                <thead>
                    <tr>
                        <th>Student Name</th>
                        <th>Allotted Desk</th>
                        <th>Shift Timing</th>
                        <th>Check-In Time</th>
                        <th>Check-Out Time</th>
                        <th>Live Status</th>
                        <th>Admin Attendance Control</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($attendance_roster)): ?>
                        <tr><td colspan="7" style="text-align: center; color: var(--text-muted);">No approved students found.</td></tr>
                    <?php else: ?>
                        <?php foreach ($attendance_roster as $att): ?>
                            <tr>
                                <td>
                                    <strong><?php echo htmlspecialchars($att['student_name']); ?></strong><br>
                                    <small style="color: var(--text-muted);"><?php echo htmlspecialchars($att['phone']); ?></small>
                                </td>
                                <td><span class="badge badge-info">Desk <?php echo htmlspecialchars($att['seat_number']); ?></span></td>
                                <td><small><?php echo htmlspecialchars($att['shift_name']); ?></small></td>
                                <td>
                                    <?php echo $att['check_in_time'] ? date('g:i:s A', strtotime($att['check_in_time'])) : '<span style="color:var(--text-muted);">--</span>'; ?>
                                </td>
                                <td>
                                    <?php echo $att['check_out_time'] ? date('g:i:s A', strtotime($att['check_out_time'])) : '<span style="color:var(--text-muted);">--</span>'; ?>
                                </td>
                                <td>
                                    <?php if ($att['check_in_time'] && !$att['check_out_time']): ?>
                                        <span class="badge badge-success"><i class="fas fa-circle" style="font-size:0.6rem;"></i> Present In Hall</span>
                                    <?php elseif ($att['check_in_time'] && $att['check_out_time']): ?>
                                        <span class="badge badge-info"><i class="fas fa-check"></i> Checked Out</span>
                                    <?php else: ?>
                                        <span class="badge badge-warning">Not Checked In Today</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <?php if ($att['check_in_time'] && !$att['check_out_time']): ?>
                                        <form action="api/admin_actions.php" method="POST" style="display:inline;">
                                            <input type="hidden" name="action" value="admin_checkout">
                                            <input type="hidden" name="user_id" value="<?php echo $att['student_id']; ?>">
                                            <button type="submit" class="btn btn-danger btn-sm" title="Mark student as Left Hall / Force Exit">
                                                <i class="fas fa-sign-out-alt"></i> Force Check-Out
                                            </button>
                                        </form>
                                    <?php else: ?>
                                        <form action="api/admin_actions.php" method="POST" style="display:inline;">
                                            <input type="hidden" name="action" value="admin_checkin">
                                            <input type="hidden" name="user_id" value="<?php echo $att['student_id']; ?>">
                                            <button type="submit" class="btn btn-success btn-sm">
                                                <i class="fas fa-sign-in-alt"></i> Manual Check-In
                                            </button>
                                        </form>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>

    <!-- TAB 5: SEND NOTIFICATIONS & ANNOUNCEMENTS -->
    <div id="tabAdminNotifs" class="tab-pane <?php echo $active_tab === 'notifs' ? 'active' : ''; ?>">
        <div class="grid-2">
            <!-- Form: Send Notification -->
            <div style="background: var(--bg-surface-elevated); padding: 20px; border-radius: var(--radius-md); border: 1px solid var(--border-color);">
                <h3><i class="fas fa-paper-plane" style="color: var(--accent-primary);"></i> Send Notice / Notification</h3>
                <p style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 16px;">
                    Send announcement notices to ALL students or send a direct private message to a specific student.
                </p>

                <form action="api/admin_actions.php" method="POST">
                    <input type="hidden" name="action" value="send_notification">

                    <div class="form-group">
                        <label class="form-label">Recipient Selection</label>
                        <select name="recipient_type" id="notifRecipientType" class="form-control" onchange="toggleNotifUserSelect(this.value)" required>
                            <option value="all">📢 Broadcast Notice to ALL Students</option>
                            <option value="specific">👤 Direct Private Message to Particular Student</option>
                        </select>
                    </div>

                    <div class="form-group" id="notifTargetUserGroup" style="display: none;">
                        <label class="form-label">Select Student</label>
                        <select name="target_user_id" class="form-control">
                            <option value="">-- Choose Student --</option>
                            <?php foreach ($students as $stu): ?>
                                <option value="<?php echo $stu['id']; ?>">
                                    <?php echo htmlspecialchars($stu['name']); ?> (Phone: <?php echo htmlspecialchars($stu['phone']); ?>)
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Notice Title</label>
                        <input type="text" name="title" class="form-control" placeholder="e.g. Fee Due Reminder / AC Servicing Notice" required>
                    </div>

                    <div class="form-group">
                        <label class="form-label">Notice Description / Message</label>
                        <textarea name="message" class="form-control" rows="4" placeholder="Type message details here..." required></textarea>
                    </div>

                    <button type="submit" class="btn btn-primary" style="width: 100%;">
                        <i class="fas fa-bell"></i> Dispatch Notification Now
                    </button>
                </form>
            </div>

            <!-- Sent Notifications Log -->
            <div style="background: var(--bg-surface-elevated); padding: 20px; border-radius: var(--radius-md); border: 1px solid var(--border-color);">
                <h3><i class="fas fa-history" style="color: var(--accent-primary);"></i> Sent Notifications Log</h3>
                <div class="table-responsive" style="margin-top: 14px; max-height: 400px; overflow-y: auto;">
                    <table class="custom-table">
                        <thead>
                            <tr>
                                <th>Recipient</th>
                                <th>Notice Title & Message</th>
                                <th>Sent Date</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($sent_notifications)): ?>
                                <tr><td colspan="3" style="text-align: center; color: var(--text-muted);">No notifications sent yet.</td></tr>
                            <?php else: ?>
                                <?php foreach ($sent_notifications as $not): ?>
                                    <tr>
                                        <td>
                                            <?php if ($not['user_id'] == 0): ?>
                                                <span class="badge badge-info"><i class="fas fa-bullhorn"></i> ALL STUDENTS</span>
                                            <?php else: ?>
                                                <span class="badge badge-success"><i class="fas fa-user"></i> <?php echo htmlspecialchars($not['student_name'] ?? 'Student #' . $not['user_id']); ?></span>
                                            <?php endif; ?>
                                        </td>
                                        <td>
                                            <strong><?php echo htmlspecialchars($not['title']); ?></strong><br>
                                            <small style="color: var(--text-muted);"><?php echo htmlspecialchars($not['message']); ?></small>
                                        </td>
                                        <td><small><?php echo format_date($not['created_at']); ?></small></td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <!-- TAB 6: COMPLAINTS DESK -->
    <div id="tabAdminComplaints" class="tab-pane <?php echo $active_tab === 'complaints' ? 'active' : ''; ?>">
        <h3><i class="fas fa-headset" style="color: var(--accent-primary);"></i> Facility Complaints & Support Tickets</h3>
        
        <div class="table-responsive" style="margin-top: 16px;">
            <table class="custom-table">
                <thead>
                    <tr>
                        <th>Ticket ID</th>
                        <th>Student Name</th>
                        <th>Category</th>
                        <th>Subject & Description</th>
                        <th>Date</th>
                        <th>Status</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($complaints_all)): ?>
                        <tr><td colspan="7" style="text-align: center; color: var(--text-muted);">No complaints logged.</td></tr>
                    <?php else: ?>
                        <?php foreach ($complaints_all as $comp): ?>
                            <tr>
                                <td>#TKT-<?php echo sprintf("%04d", $comp['id']); ?></td>
                                <td>
                                    <strong><?php echo htmlspecialchars($comp['student_name']); ?></strong><br>
                                    <small><?php echo htmlspecialchars($comp['phone']); ?></small>
                                </td>
                                <td><span class="badge badge-info"><?php echo htmlspecialchars($comp['category']); ?></span></td>
                                <td style="max-width: 320px;">
                                    <strong><?php echo htmlspecialchars($comp['subject']); ?></strong><br>
                                    <span style="font-size: 0.85rem; color: var(--text-muted);"><?php echo htmlspecialchars($comp['description']); ?></span>
                                </td>
                                <td><?php echo format_date($comp['created_at']); ?></td>
                                <td>
                                    <?php if ($comp['status'] === 'resolved'): ?>
                                        <span class="badge badge-success">Resolved</span>
                                    <?php elseif ($comp['status'] === 'in_progress'): ?>
                                        <span class="badge badge-warning">In Progress</span>
                                    <?php else: ?>
                                        <span class="badge badge-danger">Open</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <form action="api/admin_actions.php" method="POST" style="display:flex; gap:6px;">
                                        <input type="hidden" name="action" value="update_complaint">
                                        <input type="hidden" name="complaint_id" value="<?php echo $comp['id']; ?>">
                                        <select name="status" class="form-control" style="padding:4px 8px; font-size:0.8rem;">
                                            <option value="open" <?php echo $comp['status'] === 'open' ? 'selected' : ''; ?>>Open</option>
                                            <option value="in_progress" <?php echo $comp['status'] === 'in_progress' ? 'selected' : ''; ?>>In Progress</option>
                                            <option value="resolved" <?php echo $comp['status'] === 'resolved' ? 'selected' : ''; ?>>Resolved</option>
                                        </select>
                                        <button type="submit" class="btn btn-primary btn-sm">Save</button>
                                    </form>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>

    <!-- TAB 7: SEATS, SHIFTS & DATABASE BACKUP SETTINGS -->
    <div id="tabAdminSettings" class="tab-pane <?php echo $active_tab === 'settings' ? 'active' : ''; ?>">
        
        <!-- SHIFT TIMINGS & FEES MANAGER -->
        <div style="background: var(--bg-surface-elevated); padding: 24px; border-radius: var(--radius-md); border: 1px solid var(--border-color); margin-bottom: 24px;">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px; margin-bottom: 16px;">
                <div>
                    <h3><i class="fas fa-clock" style="color: var(--accent-primary);"></i> Manage Library Shift Timings & Monthly Fees</h3>
                    <p style="font-size: 0.88rem; color: var(--text-muted);">Admin can edit shift hours, monthly fee amounts, or disable shifts according to library schedule.</p>
                </div>
                <button class="btn btn-primary btn-sm" onclick="openModal('modalAddShift')">
                    <i class="fas fa-plus"></i> Create New Shift
                </button>
            </div>

            <div class="table-responsive">
                <table class="custom-table">
                    <thead>
                        <tr>
                            <th>Shift ID</th>
                            <th>Shift Title</th>
                            <th>Timing Hours</th>
                            <th>Monthly Fee (₹)</th>
                            <th>Status</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($shifts as $sh): ?>
                            <tr>
                                <td>#SH-<?php echo $sh['id']; ?></td>
                                <td><strong><?php echo htmlspecialchars($sh['name']); ?></strong></td>
                                <td>
                                    <span class="badge badge-info">
                                        <i class="far fa-clock"></i> <?php echo date('g:i A', strtotime($sh['start_time'])); ?> - <?php echo date('g:i A', strtotime($sh['end_time'])); ?>
                                    </span>
                                </td>
                                <td><strong><?php echo format_currency($sh['fee_amount']); ?></strong></td>
                                <td>
                                    <?php if ($sh['is_active']): ?>
                                        <span class="badge badge-success">Active</span>
                                    <?php else: ?>
                                        <span class="badge badge-danger">Disabled</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <div style="display: flex; gap: 6px;">
                                        <button class="btn btn-secondary btn-sm" onclick="openEditShiftModal(<?php echo $sh['id']; ?>, '<?php echo addslashes($sh['name']); ?>', '<?php echo $sh['start_time']; ?>', '<?php echo $sh['end_time']; ?>', <?php echo $sh['fee_amount']; ?>)">
                                            <i class="fas fa-edit"></i> Edit Shift
                                        </button>
                                        <form action="api/admin_actions.php" method="POST" style="display:inline;">
                                            <input type="hidden" name="action" value="toggle_shift">
                                            <input type="hidden" name="shift_id" value="<?php echo $sh['id']; ?>">
                                            <input type="hidden" name="status" value="<?php echo $sh['is_active'] ? 0 : 1; ?>">
                                            <button type="submit" class="btn <?php echo $sh['is_active'] ? 'btn-warning' : 'btn-success'; ?> btn-sm">
                                                <?php echo $sh['is_active'] ? 'Disable' : 'Enable'; ?>
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- DATABASE BACKUP & RESTORE UTILITY SECTION -->
        <div style="background: var(--bg-surface-elevated); padding: 24px; border-radius: var(--radius-md); border: 2px dashed var(--accent-primary); margin-bottom: 24px;">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px;">
                <div>
                    <h3 style="color: var(--accent-primary);"><i class="fas fa-database"></i> Database Backup & Data Protection Utility</h3>
                    <p style="font-size: 0.88rem; color: var(--text-muted); margin-top: 4px;">
                        Download a 1-click full database backup (`.sqlite`) or restore data in case of accidental deletion.
                    </p>
                </div>
                <div style="display: flex; gap: 12px;">
                    <a href="api/admin_actions.php?action=backup_db" class="btn btn-primary"><i class="fas fa-download"></i> Download Database Backup (.sqlite)</a>
                </div>
            </div>

            <hr style="border: 0; border-top: 1px solid var(--border-color); margin: 20px 0;">

            <form action="api/admin_actions.php" method="POST" enctype="multipart/form-data" style="display: flex; align-items: flex-end; gap: 16px; flex-wrap: wrap;" onsubmit="return confirm('CAUTION: Restoring a database backup will overwrite all current system data! Do you wish to proceed?');">
                <input type="hidden" name="action" value="restore_db">
                <div style="flex: 1; min-width: 250px;">
                    <label class="form-label"><i class="fas fa-upload"></i> Upload Backup File to Restore (.sqlite / .db)</label>
                    <input type="file" name="backup_file" class="form-control" accept=".sqlite,.db" required>
                </div>
                <button type="submit" class="btn btn-danger"><i class="fas fa-undo"></i> Restore Database Backup</button>
            </form>
        </div>

        <!-- BULK SEAT RANGE CREATOR & DELETION MANAGER -->
        <div style="background: var(--bg-surface-elevated); padding: 24px; border-radius: var(--radius-md); border: 1px solid var(--border-color); margin-top: 24px;">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px; margin-bottom: 16px;">
                <div>
                    <h4 style="color: var(--accent-primary);"><i class="fas fa-cubes"></i> ⚡ Bulk Create Seats in Range & Seat Desk Manager</h4>
                    <p style="font-size: 0.88rem; color: var(--text-muted); margin-top: 4px;">
                        Easily create an entire range of seats at once (e.g., Row E from E-01 to E-10) or delete desks/rows.
                    </p>
                </div>
            </div>

            <!-- Form 1: Bulk Range Creator -->
            <form action="api/admin_actions.php" method="POST" style="background: var(--bg-body); padding: 18px; border-radius: var(--radius-sm); border: 1px solid var(--border-color); margin-bottom: 24px;">
                <input type="hidden" name="action" value="bulk_create_seats">
                <h5 style="margin-bottom: 12px; color: var(--text-heading);"><i class="fas fa-magic" style="color: #10b981;"></i> 1-Click Range Seat Creator</h5>
                
                <div class="grid-4" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px;">
                    <div class="form-group">
                        <label class="form-label">Row Letter (e.g. E, F, G)</label>
                        <input type="text" name="row_label" class="form-control" placeholder="E" value="E" required style="text-transform: uppercase;">
                    </div>
                    <div class="form-group">
                        <label class="form-label">Start No. (e.g. 1)</label>
                        <input type="number" name="start_num" class="form-control" value="1" min="1" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">End No. (e.g. 10)</label>
                        <input type="number" name="end_num" class="form-control" value="10" min="1" required>
                    </div>
                    <div class="form-group">
                        <label class="form-label">Number Format</label>
                        <select name="format_digits" class="form-control">
                            <option value="2">2-Digit (01, 02 ... 10)</option>
                            <option value="1">1-Digit (1, 2 ... 10)</option>
                        </select>
                    </div>
                </div>

                <div style="display: flex; justify-content: flex-end; margin-top: 12px;">
                    <button type="submit" class="btn btn-success"><i class="fas fa-plus-circle"></i> ⚡ Generate Range (e.g. E-01 to E-10)</button>
                </div>
            </form>

            <!-- Table 2: Existing Seats Manager & Delete Actions -->
            <h5><i class="fas fa-list-ul"></i> Manage & Delete Existing Seat Desks (Total Desks: <?php echo count($seats); ?>)</h5>
            <div class="table-responsive" style="max-height: 350px; overflow-y: auto; margin-top: 12px; border: 1px solid var(--border-color); border-radius: var(--radius-sm);">
                <table class="custom-table" style="font-size: 0.88rem;">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Desk Number</th>
                            <th>Row</th>
                            <th>Active Allocations</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($seats as $st): ?>
                            <?php
                                $alloc_count = $pdo->query("SELECT COUNT(*) FROM allocations WHERE seat_id = " . $st['id'] . " AND status = 'active'")->fetchColumn();
                            ?>
                            <tr>
                                <td>#<?php echo $st['id']; ?></td>
                                <td><strong>Desk <?php echo htmlspecialchars($st['seat_number']); ?></strong></td>
                                <td><span class="badge badge-info">Row <?php echo htmlspecialchars($st['row_label']); ?></span></td>
                                <td>
                                    <?php if ($alloc_count > 0): ?>
                                        <span class="badge badge-warning"><?php echo $alloc_count; ?> Active Shift Student(s)</span>
                                    <?php else: ?>
                                        <span class="badge badge-success">Vacant / Unassigned</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <form action="api/admin_actions.php" method="POST" style="display:inline;" onsubmit="return confirm('Are you sure you want to delete Desk <?php echo htmlspecialchars($st['seat_number']); ?>? Any active student allocation will be freed.');">
                                        <input type="hidden" name="action" value="delete_seat">
                                        <input type="hidden" name="seat_id" value="<?php echo $st['id']; ?>">
                                        <button type="submit" class="btn btn-danger btn-sm"><i class="fas fa-trash-alt"></i> Delete Desk</button>
                                    </form>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <!-- TAB 8: DIRECT STUDENT CHAT -->
    <div id="tabAdminChat" class="tab-pane <?php echo $active_tab === 'chat' ? 'active' : ''; ?>">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
            <h3><i class="fas fa-comments" style="color: #06b6d4;"></i> Direct 1-on-1 Student Support Chat Center</h3>
            <span class="badge badge-info"><i class="fas fa-clock"></i> Auto-clears messages > 48h</span>
        </div>

        <div style="display: grid; grid-template-columns: 300px 1fr; gap: 20px; min-height: 520px; background: var(--bg-card); border-radius: 12px; border: 1px solid var(--border-color); overflow: hidden;">
            <!-- Left: Student Threads List -->
            <div style="border-right: 1px solid var(--border-color); display: flex; flex-direction: column; background: rgba(0,0,0,0.02);">
                <div style="padding: 12px; border-bottom: 1px solid var(--border-color);">
                    <input type="text" id="webChatSearch" class="form-control" placeholder="Search student name/desk..." onkeyup="filterWebChatThreads()">
                </div>
                <div id="webChatThreadsList" style="flex: 1; overflow-y: auto; max-height: 460px;">
                    <div style="text-align: center; padding: 20px; color: var(--text-muted);">Loading chat threads...</div>
                </div>
            </div>

            <!-- Right: Active Chat Conversation Pane -->
            <div style="display: flex; flex-direction: column; height: 100%;">
                <!-- Header -->
                <div id="webChatHeader" style="padding: 14px 20px; border-bottom: 1px solid var(--border-color); background: rgba(79, 70, 229, 0.05); display: flex; justify-content: space-between; align-items: center;">
                    <h4 style="margin:0;"><i class="fas fa-user-circle"></i> Select a student from the left panel to start chatting</h4>
                </div>

                <!-- Messages area -->
                <div id="webChatMessagesBox" style="flex: 1; padding: 20px; overflow-y: auto; min-height: 320px; max-height: 380px; display: flex; flex-direction: column; gap: 12px; background: rgba(0,0,0,0.01);">
                    <div style="text-align: center; color: var(--text-muted); margin-top: 40px;">
                        <i class="fas fa-comments" style="font-size: 3rem; opacity: 0.3;"></i>
                        <p style="margin-top: 10px;">Select a student thread on the left to view messages.</p>
                    </div>
                </div>

                <!-- Quick Replies -->
                <div style="padding: 8px 16px; background: rgba(0,0,0,0.02); border-top: 1px solid var(--border-color); display: flex; gap: 8px; flex-wrap: wrap;" id="webQuickReplies">
                    <button class="btn btn-secondary btn-sm" onclick="insertWebQuickReply('Your seat desk is confirmed. 👍')">Seat Confirmed 👍</button>
                    <button class="btn btn-secondary btn-sm" onclick="insertWebQuickReply('Monthly fee payment received, thank you! 💳')">Fee Received 💳</button>
                    <button class="btn btn-secondary btn-sm" onclick="insertWebQuickReply('Please check your library shift timing.')">Shift Timing ⏰</button>
                </div>

                <!-- Input form -->
                <div style="padding: 12px 16px; border-top: 1px solid var(--border-color); display: flex; gap: 10px;">
                    <input type="text" id="webChatInput" class="form-control" placeholder="Type reply message to student..." disabled onkeypress="if(event.key==='Enter') sendWebChatMessage()">
                    <button id="webChatSendBtn" class="btn btn-primary" onclick="sendWebChatMessage()" disabled><i class="fas fa-paper-plane"></i> Send</button>
                </div>
            </div>
        </div>
    </div>

    <!-- TAB 9: RECYCLE BIN & SOFT-DELETED RECORDS (30 DAYS HOLD) -->
    <div id="tabAdminRecycleBin" class="tab-pane <?php echo $active_tab === 'recyclebin' ? 'active' : ''; ?>">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 15px; margin-bottom: 20px;">
            <div>
                <h3><i class="fas fa-trash-restore" style="color: #ef4444;"></i> Recycle Bin / Student Data Recovery</h3>
                <p style="font-size: 0.85rem; color: var(--text-muted);">
                    Student records deleted by Admin are safely stored here for <strong>30 days</strong>. You can restore them to Active status or permanently erase them.
                </p>
            </div>
            <div>
                <span class="badge badge-info" style="font-size: 0.9rem; padding: 6px 12px;">
                    <i class="fas fa-history"></i> 30-Day Automatic Data Purge Active
                </span>
            </div>
        </div>

        <div class="table-responsive">
            <table class="custom-table">
                <thead>
                    <tr>
                        <th>Student Name</th>
                        <th>Contact Phone</th>
                        <th>Date Deleted</th>
                        <th>Auto-Purge In</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($recycle_bin_students)): ?>
                        <tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 30px;">Recycle Bin is currently empty. No deleted student records.</td></tr>
                    <?php else: ?>
                        <?php foreach ($recycle_bin_students as $bin): ?>
                            <tr>
                                <td>
                                    <strong><?php echo htmlspecialchars($bin['name']); ?></strong><br>
                                    <small style="color: var(--text-muted);"><?php echo htmlspecialchars($bin['email']); ?></small>
                                </td>
                                <td><?php echo htmlspecialchars($bin['phone']); ?></td>
                                <td><?php echo format_date($bin['deleted_at']); ?></td>
                                <td>
                                    <span class="badge badge-warning" style="font-size: 0.85rem;">
                                        <i class="fas fa-clock"></i> <?php echo $bin['days_left']; ?> Days Remaining
                                    </span>
                                </td>
                                <td>
                                    <div style="display: flex; gap: 6px;">
                                        <form action="api/admin_actions.php" method="POST" style="display:inline;">
                                            <input type="hidden" name="action" value="restore_student">
                                            <input type="hidden" name="user_id" value="<?php echo $bin['id']; ?>">
                                            <button type="submit" class="btn btn-success btn-sm" title="Restore Student to Active Directory">
                                                <i class="fas fa-trash-restore"></i> Restore Student
                                            </button>
                                        </form>

                                        <form action="api/admin_actions.php" method="POST" style="display:inline;" onsubmit="return confirm('⚠️ PERMANENT PURGE WARNING:\n\nAre you sure you want to PERMANENTLY ERASE student \'<?php echo addslashes($bin['name']); ?>\'?\n\nThis will erase all attendance, fees, and chat records permanently. This CANNOT be undone.');">
                                            <input type="hidden" name="action" value="permanent_delete_student">
                                            <input type="hidden" name="user_id" value="<?php echo $bin['id']; ?>">
                                            <button type="submit" class="btn btn-danger btn-sm" title="Permanently Delete Record">
                                                <i class="fas fa-times-circle"></i> Delete Permanently
                                            </button>
                                        </form>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<!-- MODAL: EDIT SHIFT -->
<div id="modalEditShift" class="modal-overlay">
    <div class="modal-content">
        <div class="modal-header">
            <h3><i class="fas fa-edit"></i> Edit Shift Timings & Fee</h3>
            <button class="modal-close">&times;</button>
        </div>
        <form action="api/admin_actions.php" method="POST">
            <input type="hidden" name="action" value="edit_shift">
            <input type="hidden" name="shift_id" id="editShiftId">

            <div class="form-group">
                <label class="form-label">Shift Title Name</label>
                <input type="text" name="name" id="editShiftName" class="form-control" required>
            </div>

            <div class="grid-2">
                <div class="form-group">
                    <label class="form-label">Start Time</label>
                    <input type="time" name="start_time" id="editShiftStartTime" class="form-control" required>
                </div>
                <div class="form-group">
                    <label class="form-label">End Time</label>
                    <input type="time" name="end_time" id="editShiftEndTime" class="form-control" required>
                </div>
            </div>

            <div class="form-group">
                <label class="form-label">Monthly Fee Rate (₹)</label>
                <input type="number" step="50" name="fee_amount" id="editShiftFee" class="form-control" required>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 20px;">
                <button type="button" class="btn btn-secondary modal-close">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fas fa-save"></i> Save Shift Changes</button>
            </div>
        </form>
    </div>
</div>

<!-- MODAL: ADD SHIFT -->
<div id="modalAddShift" class="modal-overlay">
    <div class="modal-content">
        <div class="modal-header">
            <h3><i class="fas fa-plus"></i> Create New Shift Option</h3>
            <button class="modal-close">&times;</button>
        </div>
        <form action="api/admin_actions.php" method="POST">
            <input type="hidden" name="action" value="add_shift">
            
            <div class="form-group">
                <label class="form-label">Shift Title</label>
                <input type="text" name="name" class="form-control" placeholder="Night Owls Shift" required>
            </div>
            <div class="grid-2">
                <div class="form-group">
                    <label class="form-label">Start Time</label>
                    <input type="time" name="start_time" class="form-control" required>
                </div>
                <div class="form-group">
                    <label class="form-label">End Time</label>
                    <input type="time" name="end_time" class="form-control" required>
                </div>
            </div>
            <div class="form-group">
                <label class="form-label">Monthly Fee (₹)</label>
                <input type="number" step="50" name="fee_amount" class="form-control" placeholder="750.00" required>
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 20px;">
                <button type="button" class="btn btn-secondary modal-close">Cancel</button>
                <button type="submit" class="btn btn-primary">Add Shift</button>
            </div>
        </form>
    </div>
</div>

<!-- MODAL: BULK IMPORT STUDENTS FROM CSV -->
<div id="modalImportCSV" class="modal-overlay">
    <div class="modal-content">
        <div class="modal-header">
            <h3><i class="fas fa-file-import"></i> Bulk Import Students from Excel (CSV)</h3>
            <button class="modal-close">&times;</button>
        </div>
        <form action="api/admin_actions.php" method="POST" enctype="multipart/form-data">
            <input type="hidden" name="action" value="import_csv">

            <div class="alert alert-info" style="font-size:0.85rem;">
                <strong>CSV Format Guide:</strong><br>
                Columns: <code>Full Name, Email, Mobile Phone, Emergency Contact, ID Proof Type, ID Proof No</code>
            </div>

            <div class="form-group">
                <label class="form-label">Select CSV File (.csv)</label>
                <input type="file" name="csv_file" class="form-control" accept=".csv" required>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 20px;">
                <button type="button" class="btn btn-secondary modal-close">Cancel</button>
                <button type="submit" class="btn btn-success"><i class="fas fa-upload"></i> Start Bulk Import</button>
            </div>
        </form>
    </div>
</div>

<!-- MODAL: APPROVE REGISTRATION & ALLOT SEAT -->
<div id="modalApproveAllot" class="modal-overlay">
    <div class="modal-content">
        <div class="modal-header">
            <h3><i class="fas fa-user-check"></i> Assign Seat & Approve Student</h3>
            <button class="modal-close">&times;</button>
        </div>
        <form action="api/admin_actions.php" method="POST">
            <input type="hidden" name="action" value="approve_student">
            
            <div class="form-group">
                <label class="form-label">Select Student</label>
                <select name="user_id" id="modalAllotUserId" class="form-control" required>
                    <option value="">-- Choose Student --</option>
                    <?php foreach ($students as $stu): ?>
                        <option value="<?php echo $stu['id']; ?>">
                            <?php echo htmlspecialchars($stu['name']); ?> (Phone: <?php echo htmlspecialchars($stu['phone']); ?>) - Status: <?php echo strtoupper($stu['status']); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div class="grid-2">
                <div class="form-group">
                    <label class="form-label">Assign Desk Seat</label>
                    <select name="seat_id" id="modalAllotSeatId" class="form-control" required>
                        <option value="">-- Choose Desk --</option>
                        <?php foreach ($seats as $st): ?>
                            <option value="<?php echo $st['id']; ?>">Desk <?php echo htmlspecialchars($st['seat_number']); ?> (Row <?php echo $st['row_label']; ?>)</option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="form-group">
                    <label class="form-label">Assign Shift Timing</label>
                    <select name="shift_id" id="modalAllotShiftId" class="form-control" required>
                        <?php foreach ($active_shifts as $sh): ?>
                            <option value="<?php echo $sh['id']; ?>">
                                <?php echo htmlspecialchars($sh['name']); ?> (<?php echo format_currency($sh['fee_amount']); ?>/mo)
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
            </div>

            <div class="form-group">
                <label class="form-label">Membership Start Date</label>
                <input type="date" name="start_date" class="form-control" value="<?php echo date('Y-m-d'); ?>" required>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 20px;">
                <button type="button" class="btn btn-secondary modal-close">Cancel</button>
                <button type="submit" class="btn btn-primary"><i class="fas fa-check"></i> Approve & Save Allotment</button>
            </div>
        </form>
    </div>
</div>

<!-- MODAL: RECORD FEE PAYMENT -->
<div id="modalRecordPayment" class="modal-overlay">
    <div class="modal-content">
        <div class="modal-header">
            <h3 id="payModalTitle"><i class="fas fa-cash-register"></i> Record Monthly Fee Collection</h3>
            <button class="modal-close">&times;</button>
        </div>
        <form action="api/admin_actions.php" method="POST">
            <input type="hidden" name="action" value="record_payment">
            <input type="hidden" name="allocation_id" id="payAllocationId">
            <input type="hidden" name="user_id" id="payUserId">

            <div class="form-group">
                <label class="form-label">Student Name</label>
                <input type="text" id="payStudentName" class="form-control" readonly>
            </div>

            <div class="grid-2">
                <div class="form-group">
                    <label class="form-label">Collection Month Cycle</label>
                    <input type="month" name="month_year" id="payMonthYear" class="form-control" value="<?php echo date('Y-m'); ?>" required>
                </div>
                <div class="form-group">
                    <label class="form-label">Fee Amount (₹)</label>
                    <input type="number" step="10" name="amount" id="payAmount" class="form-control" required>
                </div>
            </div>

            <div class="form-group">
                <label class="form-label">Payment Mode</label>
                <select name="payment_mode" class="form-control" required>
                    <option value="UPI / PhonePe / GPay">UPI (PhonePe / GPay / Paytm)</option>
                    <option value="Cash">Cash</option>
                    <option value="NetBanking">Net Banking</option>
                    <option value="Card">Debit / Credit Card</option>
                </select>
            </div>

            <div style="display: flex; justify-content: flex-end; gap: 12px; margin-top: 20px;">
                <button type="button" class="btn btn-secondary modal-close">Cancel</button>
                <button type="submit" class="btn btn-success"><i class="fas fa-receipt"></i> Generate Digital Receipt</button>
            </div>
        </form>
    </div>
</div>

<!-- MODAL: STUDENT FEE HISTORY (LAST 12 MONTHS) -->
<div id="modalStudentHistory" class="modal-overlay">
    <div class="modal-content" style="max-width: 700px;">
        <div class="modal-header">
            <h3><i class="fas fa-history"></i> Fee History (Last 12 Months) - <span id="histStudentName">Student</span></h3>
            <button class="modal-close">&times;</button>
        </div>
        <div id="histModalContent" style="padding: 10px 0;">
            <p style="text-align: center; color: var(--text-muted);">Loading payment history...</p>
        </div>
        <div style="display: flex; justify-content: flex-end; margin-top: 15px;">
            <button type="button" class="btn btn-secondary modal-close">Close</button>
        </div>
    </div>
</div>

<script>
const allSeats = <?php echo json_encode($seats); ?>;
const allAllocations = <?php echo json_encode($all_allocations); ?>;

function updateSeatDropdownForShift() {
    const shiftSelect = document.getElementById('modalAllotShiftId');
    const seatSelect = document.getElementById('modalAllotSeatId');
    const studentSelect = document.getElementById('modalAllotUserId');
    if (!shiftSelect || !seatSelect) return;

    const selectedShiftId = parseInt(shiftSelect.value || 1);
    const selectedUserId = parseInt(studentSelect ? studentSelect.value : 0);
    const currentSeatVal = seatSelect.value;

    // Find seat IDs occupied in this shift by other students
    const occupiedSeatIds = new Set();
    allAllocations.forEach(a => {
        if (parseInt(a.shift_id) === selectedShiftId && parseInt(a.user_id) !== selectedUserId) {
            occupiedSeatIds.add(parseInt(a.seat_id));
        }
    });

    seatSelect.innerHTML = '<option value="">-- Choose Desk --</option>';
    let availableCount = 0;

    allSeats.forEach(s => {
        const isOccupied = occupiedSeatIds.has(parseInt(s.id));
        const opt = document.createElement('option');
        opt.value = s.id;

        if (isOccupied) {
            opt.textContent = `Desk ${s.seat_number} (Row ${s.row_label}) - [OCCUPIED IN THIS SHIFT]`;
            opt.disabled = true;
            opt.style.color = 'red';
        } else {
            opt.textContent = `Desk ${s.seat_number} (Row ${s.row_label}) - [AVAILABLE]`;
            opt.style.color = 'green';
            availableCount++;
        }

        if (currentSeatVal && parseInt(currentSeatVal) === parseInt(s.id) && !isOccupied) {
            opt.selected = true;
        }

        seatSelect.appendChild(opt);
    });

    if (availableCount === 0) {
        const warningOpt = document.createElement('option');
        warningOpt.value = "";
        warningOpt.textContent = "⚠️ ALL DESKS FULL IN THIS SHIFT!";
        warningOpt.disabled = true;
        warningOpt.selected = true;
        seatSelect.insertBefore(warningOpt, seatSelect.firstChild);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const shiftSelect = document.getElementById('modalAllotShiftId');
    const studentSelect = document.getElementById('modalAllotUserId');
    if (shiftSelect) shiftSelect.addEventListener('change', updateSeatDropdownForShift);
    if (studentSelect) studentSelect.addEventListener('change', updateSeatDropdownForShift);
});

function toggleNotifUserSelect(type) {
    const group = document.getElementById('notifTargetUserGroup');
    if (group) {
        group.style.display = (type === 'specific') ? 'block' : 'none';
    }
}

function openEditShiftModal(id, name, startTime, endTime, fee) {
    document.getElementById('editShiftId').value = id;
    document.getElementById('editShiftName').value = name;
    document.getElementById('editShiftStartTime').value = startTime;
    document.getElementById('editShiftEndTime').value = endTime;
    document.getElementById('editShiftFee').value = fee;
    openModal('modalEditShift');
}

function openApproveModal(userId, seatId, shiftId) {
    if (userId) document.getElementById('modalAllotUserId').value = userId;
    if (shiftId) document.getElementById('modalAllotShiftId').value = shiftId;
    if (seatId) document.getElementById('modalAllotSeatId').value = seatId;
    updateSeatDropdownForShift();
    openModal('modalApproveAllot');
}

function openPaymentModal(allocationId, userId, studentName, amount, monthYear) {
    document.getElementById('payAllocationId').value = allocationId;
    document.getElementById('payUserId').value = userId;
    document.getElementById('payStudentName').value = studentName;
    document.getElementById('payAmount').value = amount;
    
    const nowMonthStr = new Date().toISOString().slice(0, 7);
    const titleElem = document.getElementById('payModalTitle');
    
    if (monthYear) {
        document.getElementById('payMonthYear').value = monthYear;
        if (monthYear > nowMonthStr) {
            titleElem.innerHTML = `<i class="fas fa-forward" style="color:#0284c7;"></i> Record Advance Fee Collection (${monthYear})`;
        } else {
            titleElem.innerHTML = `<i class="fas fa-cash-register"></i> Record Monthly Fee Collection (${monthYear})`;
        }
    } else {
        titleElem.innerHTML = `<i class="fas fa-cash-register"></i> Record Monthly Fee Collection`;
    }
    openModal('modalRecordPayment');
}

function openStudentHistoryModal(userId, studentName) {
    document.getElementById('histStudentName').innerText = studentName;
    const container = document.getElementById('histModalContent');
    container.innerHTML = '<p style="text-align: center; color: var(--text-muted); padding: 15px;"><i class="fas fa-spinner fa-spin"></i> Loading 12-month payment history...</p>';
    openModal('modalStudentHistory');

    fetch(`api/json_admin_actions.php?action=get_student_fee_history&user_id=${userId}`)
        .then(res => res.json())
        .then(data => {
            if (data.success && data.fee_history && data.fee_history.length > 0) {
                let html = `
                    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
                        <span style="font-size:0.85rem; color:var(--text-muted); font-weight:600;">Found ${data.fee_history.length} payment records in the last 12 months</span>
                        <a href="receipt_statement.php?user_id=${userId}" target="_blank" class="btn btn-primary btn-sm">
                            <i class="fas fa-file-pdf"></i> Download PDF / Print 12-Mo Statement
                        </a>
                    </div>
                    <div class="table-responsive">
                        <table class="custom-table" style="font-size: 0.85rem;">
                            <thead>
                                <tr>
                                    <th>Cycle Month</th>
                                    <th>Fee Amount</th>
                                    <th>Paid Date</th>
                                    <th>Mode</th>
                                    <th>Receipt</th>
                                </tr>
                            </thead>
                            <tbody>
                `;
                data.fee_history.forEach(p => {
                    const isPaid = p.payment_status === 'paid';
                    const isAdvance = p.month_year > new Date().toISOString().slice(0, 7);
                    const badgeClass = isPaid ? 'badge-success' : (p.payment_status === 'overdue' ? 'badge-danger' : 'badge-warning');
                    
                    html += `
                        <tr>
                            <td>
                                <strong>${p.month_year}</strong>
                                ${isAdvance ? '<span class="badge badge-info" style="font-size:0.65rem; margin-left:4px;">ADVANCE</span>' : ''}
                            </td>
                            <td>₹${parseFloat(p.amount).toFixed(2)}</td>
                            <td>${p.paid_date ? p.paid_date : '<span style="color:var(--text-muted);">Unpaid</span>'}</td>
                            <td>${p.payment_mode || 'N/A'}</td>
                            <td>
                                ${isPaid && p.receipt_no 
                                    ? `<a href="receipt.php?receipt_no=${encodeURIComponent(p.receipt_no)}" target="_blank" class="btn btn-secondary btn-sm" style="padding: 2px 6px; font-size: 0.75rem;"><i class="fas fa-receipt"></i> ${p.receipt_no}</a>` 
                                    : `<span class="badge ${badgeClass}">${p.payment_status.toUpperCase()}</span>`}
                            </td>
                        </tr>
                    `;
                });
                html += `</tbody></table></div>`;
                container.innerHTML = html;
            } else {
                container.innerHTML = '<p style="text-align: center; color: var(--text-muted); padding: 20px;">No payment history found for the last 12 months.</p>';
            }
        })
        .catch(err => {
            container.innerHTML = '<p style="text-align: center; color: var(--text-danger); padding: 20px;">Failed to load payment history.</p>';
        });
}

// WEB ADMIN DIRECT CHAT ENGINE
let currentSelectedStudentId = null;
let currentSelectedStudentName = '';
let webChatThreadsData = [];

function loadWebChatThreads() {
    fetch('api/json_admin_actions.php?action=get_admin_chat_threads')
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                webChatThreadsData = data.threads || [];
                renderWebChatThreads();
            }
        }).catch(err => console.error("Web chat threads error:", err));
}

function renderWebChatThreads() {
    const container = document.getElementById('webChatThreadsList');
    if (!container) return;
    const filter = (document.getElementById('webChatSearch')?.value || '').toLowerCase();

    const filtered = webChatThreadsData.filter(t => {
        const name = (t.student_name || '').toLowerCase();
        const phone = (t.student_phone || '').toLowerCase();
        const desk = (t.seat_number || '').toLowerCase();
        return name.includes(filter) || phone.includes(filter) || desk.includes(filter);
    });

    if (filtered.length === 0) {
        container.innerHTML = '<div style="padding: 20px; text-align: center; color: var(--text-muted);">No student chat threads found</div>';
        return;
    }

    let html = '';
    filtered.forEach(t => {
        const isSelected = parseInt(t.student_id) === currentSelectedStudentId;
        const unread = parseInt(t.unread_count || 0);
        const lastMsg = t.last_message || 'Tap to start chat';
        const desk = t.seat_number ? ` (Desk: ${t.seat_number})` : '';

        html += `
            <div onclick="selectWebChatStudent(${t.student_id}, '${escapeHtml(t.student_name)}', '${t.seat_number || ''}')" 
                 style="padding: 12px 14px; border-bottom: 1px solid var(--border-color); cursor: pointer; background: ${isSelected ? 'rgba(79, 70, 229, 0.15)' : 'transparent'}; border-left: ${isSelected ? '4px solid var(--accent-primary)' : 'none'};">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <strong style="font-size: 0.95rem;">${escapeHtml(t.student_name)}${desk}</strong>
                    ${unread > 0 ? `<span class="badge badge-danger">${unread}</span>` : ''}
                </div>
                <div style="font-size: 0.8rem; color: var(--text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 4px;">
                    ${escapeHtml(lastMsg)}
                </div>
            </div>
        `;
    });
    container.innerHTML = html;
}

function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#039;");
}

function filterWebChatThreads() {
    renderWebChatThreads();
}

function selectWebChatStudent(studentId, name, desk) {
    currentSelectedStudentId = parseInt(studentId);
    currentSelectedStudentName = name;
    renderWebChatThreads();

    const header = document.getElementById('webChatHeader');
    if (header) {
        header.innerHTML = `<h4 style="margin:0;"><i class="fas fa-user"></i> ${name} ${desk ? '(Desk: ' + desk + ')' : ''}</h4><span class="badge badge-success">Online 🟢</span>`;
    }

    document.getElementById('webChatInput').disabled = false;
    document.getElementById('webChatSendBtn').disabled = false;
    loadWebChatMessages();
}

function loadWebChatMessages() {
    if (!currentSelectedStudentId) return;
    fetch(`api/json_admin_actions.php?action=get_admin_chat_messages&student_id=${currentSelectedStudentId}`)
        .then(res => res.json())
        .then(data => {
            if (data.success) {
                const box = document.getElementById('webChatMessagesBox');
                if (!box) return;
                const adminId = parseInt(data.admin_id || 1);
                const msgs = data.messages || [];

                if (msgs.length === 0) {
                    box.innerHTML = `<div style="text-align: center; color: var(--text-muted); margin-top: 40px;"><p>No messages yet. Send a reply below!</p></div>`;
                    return;
                }

                let html = '';
                msgs.forEach(m => {
                    const isAdmin = parseInt(m.sender_id) === adminId;
                    const align = isAdmin ? 'flex-end' : 'flex-start';
                    const bg = isAdmin ? 'var(--accent-primary)' : 'rgba(0,0,0,0.06)';
                    const color = isAdmin ? '#ffffff' : 'var(--text-main)';

                    html += `
                        <div style="display: flex; justify-content: ${align}; margin-bottom: 8px;">
                            <div style="max-width: 70%; padding: 10px 14px; border-radius: 12px; background: ${bg}; color: ${color}; font-size: 0.9rem; border: 1px solid var(--border-color);">
                                <div>${escapeHtml(m.message)}</div>
                                <div style="font-size: 0.7rem; opacity: 0.7; text-align: right; margin-top: 4px;">${m.created_at || ''}</div>
                            </div>
                        </div>
                    `;
                });
                box.innerHTML = html;
                box.scrollTop = box.scrollHeight;
            }
        }).catch(err => console.error("Web chat msgs error:", err));
}

function sendWebChatMessage() {
    const input = document.getElementById('webChatInput');
    const msg = input.value.trim();
    if (!msg || !currentSelectedStudentId) return;

    input.value = '';
    const formData = new FormData();
    formData.append('action', 'send_admin_chat_message');
    formData.append('student_id', currentSelectedStudentId);
    formData.append('message', msg);

    fetch('api/json_admin_actions.php', {
        method: 'POST',
        body: formData
    }).then(res => res.json())
    .then(data => {
        if (data.success) {
            loadWebChatMessages();
            loadWebChatThreads();
        }
    });
}

function insertWebQuickReply(text) {
    const input = document.getElementById('webChatInput');
    if (input) {
        input.value = text;
        sendWebChatMessage();
    }
}

// Auto start chat polling if chat tab active
document.addEventListener('DOMContentLoaded', () => {
    loadWebChatThreads();
    setInterval(() => {
        loadWebChatThreads();
        if (currentSelectedStudentId) {
            loadWebChatMessages();
        }
    }, 4000);
});

function openStudentDetailsModal(stu) {
    const body = document.getElementById('studentDetailsModalBody');
    if (!body) return;

    let statusBadge = '<span class="badge badge-info">Pending</span>';
    if (stu.status === 'approved' || stu.status === 'active') statusBadge = '<span class="badge badge-success">Approved</span>';
    else if (stu.status === 'hold') statusBadge = '<span class="badge badge-warning">On Hold</span>';
    else if (stu.status === 'cancelled') statusBadge = '<span class="badge badge-danger">Cancelled</span>';

    body.innerHTML = `
        <div style="display: flex; gap: 15px; align-items: center; padding-bottom: 15px; border-bottom: 1px solid var(--border-color); margin-bottom: 15px;">
            <div style="width: 54px; height: 54px; border-radius: 50%; background: var(--accent-primary); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; font-weight: bold;">
                ${(stu.name || 'S').charAt(0).toUpperCase()}
            </div>
            <div>
                <h4 style="margin: 0;">${escapeHtml(stu.name)} ${statusBadge}</h4>
                <div style="font-size: 0.85rem; color: var(--text-muted);">Student ID: #STU-${String(stu.id).padStart(4, '0')}</div>
            </div>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; font-size: 0.9rem;">
            <div><strong><i class="fas fa-phone"></i> Mobile Phone:</strong> ${escapeHtml(stu.phone || 'N/A')}</div>
            <div><strong><i class="fas fa-envelope"></i> Email:</strong> ${escapeHtml(stu.email || 'N/A')}</div>
            <div><strong><i class="fas fa-user-friends"></i> Father Name:</strong> ${escapeHtml(stu.father_name || 'N/A')}</div>
            <div><strong><i class="fas fa-phone-alt"></i> Emergency Contact:</strong> ${escapeHtml(stu.emergency_contact || 'N/A')}</div>
            <div><strong><i class="fas fa-id-badge"></i> ID Proof Type:</strong> ${escapeHtml(stu.id_proof_type || 'N/A')}</div>
            <div><strong><i class="fas fa-barcode"></i> ID Proof No:</strong> ${escapeHtml(stu.id_proof_no || 'N/A')}</div>
            <div><strong><i class="fas fa-chair"></i> Allotted Desk:</strong> ${stu.seat_number ? 'Desk ' + escapeHtml(stu.seat_number) : 'Not Allotted'}</div>
            <div><strong><i class="fas fa-clock"></i> Shift:</strong> ${escapeHtml(stu.shift_name || 'N/A')}</div>
            <div><strong><i class="fas fa-calendar-alt"></i> Joining Date:</strong> ${escapeHtml(stu.start_date || 'N/A')}</div>
            <div><strong><i class="fas fa-mobile-alt"></i> Registered Hardware ID:</strong> <code>${escapeHtml(stu.registered_device_id || 'Not Bound Yet')}</code></div>
            <div style="grid-column: span 2;"><strong><i class="fas fa-map-marker-alt"></i> Address:</strong> ${escapeHtml(stu.address || 'N/A')}</div>
        </div>
    `;
    openModal('modalStudentDetails');
}
</script>

<!-- Modal: Student Profile Full Details -->
<div id="modalStudentDetails" class="modal">
    <div class="modal-content" style="max-width: 650px;">
        <div class="modal-header">
            <h3><i class="fas fa-id-card" style="color: var(--accent-primary);"></i> Student Full Profile Details</h3>
            <button type="button" class="modal-close" onclick="closeModal('modalStudentDetails')">&times;</button>
        </div>
        <div class="modal-body" id="studentDetailsModalBody">
            <!-- Dynamic Content -->
        </div>
        <div class="modal-footer">
            <button type="button" class="btn btn-secondary" onclick="closeModal('modalStudentDetails')">Close</button>
        </div>
    </div>
</div>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
