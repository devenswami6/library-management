<?php
// index.php - Public Landing Page

$page_title = "Home - Competition Self-Study Library";
require_once __DIR__ . '/includes/header.php';

// Fetch shifts for pricing grid
$shifts = $pdo->query("SELECT * FROM shifts WHERE is_active = 1 ORDER BY id ASC")->fetchAll();

// Fetch total seats & vacant counts
$total_seats = $pdo->query("SELECT COUNT(*) FROM seats WHERE is_active = 1")->fetchColumn();
$occupied_seats = $pdo->query("SELECT COUNT(DISTINCT seat_id) FROM allocations WHERE status = 'active'")->fetchColumn();
$vacant_seats = max(0, $total_seats - $occupied_seats);
?>

<!-- Hero Banner -->
<div class="card" style="background: linear-gradient(135deg, rgba(79, 70, 229, 0.05) 0%, rgba(124, 58, 237, 0.1) 100%); border: 1px solid var(--border-color); padding: 40px 30px; margin-bottom: 24px;">
    <div style="max-width: 750px;">
        <span class="badge badge-info" style="margin-bottom: 12px;"><i class="fas fa-bullhorn"></i> Exam Preparation Study Hall Open 24x7</span>
        <h1 style="font-size: 2.4rem; line-height: 1.25; margin-bottom: 14px;">Focus, Prepare & Succeed at StudySpace Library</h1>
        <p style="font-size: 1.05rem; color: var(--text-muted); margin-bottom: 20px;">
            A premier self-study hall designed exclusively for competitive exam aspirants (UPSC, SSC, Banking, NEET, JEE, GATE). Reserve your personal ergonomic desk, preferred shift timing, and uninterrupted study environment today.
        </p>
        <div style="display: flex; gap: 14px; flex-wrap: wrap;">
            <a href="login.php?tab=register" class="btn btn-primary" style="padding: 12px 24px;"><i class="fas fa-user-plus"></i> Submit Registration Request</a>
            <a href="#shifts" class="btn btn-secondary" style="padding: 12px 24px;"><i class="fas fa-clock"></i> View Shift Rates</a>
        </div>
    </div>
</div>

<!-- Stats Counter Banner -->
<div class="grid-3" style="margin-bottom: 24px;">
    <div class="stat-card">
        <div class="stat-icon" style="background: rgba(79, 70, 229, 0.1); color: var(--accent-primary);">
            <i class="fas fa-chair"></i>
        </div>
        <div>
            <div class="stat-value"><?php echo $total_seats; ?></div>
            <div class="stat-label">Total Study Desks</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon" style="background: rgba(16, 185, 129, 0.1); color: #059669;">
            <i class="fas fa-door-open"></i>
        </div>
        <div>
            <div class="stat-value"><?php echo $vacant_seats; ?></div>
            <div class="stat-label">Vacant Desks Available</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon" style="background: rgba(245, 158, 11, 0.1); color: #b45309;">
            <i class="fas fa-clock"></i>
        </div>
        <div>
            <div class="stat-value">4 Shifts</div>
            <div class="stat-label">Flexible Study Timings</div>
        </div>
    </div>
</div>

<!-- Key Amenities Grid -->
<div class="card">
    <div class="card-header">
        <h2 class="card-title"><i class="fas fa-star" style="color: var(--accent-primary);"></i> Premium Study Hall Amenities</h2>
    </div>
    <div class="grid-4" style="margin-top: 10px;">
        <div style="background: var(--bg-surface-elevated); padding: 18px; border-radius: var(--radius-md); border: 1px solid var(--border-color);">
            <i class="fas fa-volume-mute" style="font-size: 1.8rem; color: var(--accent-primary); margin-bottom: 10px;"></i>
            <h4>Pin-Drop Silence Zone</h4>
            <p style="font-size: 0.85rem; color: var(--text-muted); margin-top: 6px;">Noise-controlled environment for deep concentration and long study hours.</p>
        </div>
        <div style="background: var(--bg-surface-elevated); padding: 18px; border-radius: var(--radius-md); border: 1px solid var(--border-color);">
            <i class="fas fa-wifi" style="font-size: 1.8rem; color: #059669; margin-bottom: 10px;"></i>
            <h4>High-Speed Optical Fiber Wi-Fi</h4>
            <p style="font-size: 0.85rem; color: var(--text-muted); margin-top: 6px;">300 Mbps unlimited Wi-Fi for online lectures, test series, and downloads.</p>
        </div>
        <div style="background: var(--bg-surface-elevated); padding: 18px; border-radius: var(--radius-md); border: 1px solid var(--border-color);">
            <i class="fas fa-plug" style="font-size: 1.8rem; color: #b45309; margin-bottom: 10px;"></i>
            <h4>Personal Desk Charging</h4>
            <p style="font-size: 0.85rem; color: var(--text-muted); margin-top: 6px;">Dedicated power sockets and LED desk light switch at every individual seat.</p>
        </div>
        <div style="background: var(--bg-surface-elevated); padding: 18px; border-radius: var(--radius-md); border: 1px solid var(--border-color);">
            <i class="fas fa-snowflake" style="font-size: 1.8rem; color: #0284c7; margin-bottom: 10px;"></i>
            <h4>Fully Air-Conditioned</h4>
            <p style="font-size: 0.85rem; color: var(--text-muted); margin-top: 6px;">Optimal cooling and ventilation for comfortable all-season study.</p>
        </div>
    </div>
</div>

<!-- Shift Timings & Fee Structure -->
<div class="card" id="shifts">
    <div class="card-header">
        <h2 class="card-title"><i class="fas fa-tags" style="color: var(--accent-primary);"></i> Shift Timings & Monthly Fee Rates</h2>
    </div>
    <div class="grid-4" style="margin-top: 10px;">
        <?php foreach ($shifts as $shift): ?>
            <div style="background: var(--bg-surface-elevated); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 20px; text-align: center; display: flex; flex-direction: column; justify-content: space-between;">
                <div>
                    <span class="badge badge-info" style="margin-bottom: 10px;">Shift <?php echo $shift['id']; ?></span>
                    <h3 style="font-size: 1.2rem; margin-bottom: 8px;"><?php echo htmlspecialchars($shift['name']); ?></h3>
                    <div style="font-size: 1rem; color: var(--accent-primary); font-weight: 600; margin-bottom: 14px;">
                        <i class="far fa-clock"></i> <?php echo date('g:i A', strtotime($shift['start_time'])); ?> - <?php echo date('g:i A', strtotime($shift['end_time'])); ?>
                    </div>
                    <div style="font-size: 1.8rem; font-weight: 700; color: var(--text-main); margin-bottom: 14px;">
                        <?php echo format_currency($shift['fee_amount']); ?><small style="font-size: 0.85rem; color: var(--text-muted);">/month</small>
                    </div>
                    <ul style="list-style: none; text-align: left; font-size: 0.85rem; color: var(--text-muted); margin-bottom: 18px; line-height: 2;">
                        <li><i class="fas fa-check" style="color: var(--color-success-text);"></i> Ergonomic Desk Assigned by Admin</li>
                        <li><i class="fas fa-check" style="color: var(--color-success-text);"></i> Free High Speed Wi-Fi</li>
                        <li><i class="fas fa-check" style="color: var(--color-success-text);"></i> RO Mineral Water</li>
                    </ul>
                </div>
                <a href="login.php?tab=register&shift=<?php echo $shift['id']; ?>" class="btn btn-primary" style="width: 100%;">Apply For This Shift</a>
            </div>
        <?php endforeach; ?>
    </div>
</div>

<?php require_once __DIR__ . '/includes/footer.php'; ?>
