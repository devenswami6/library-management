<?php
// config/auth.php - Session and authentication management

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/db.php';

// 50-Meter GPS Geofencing Constants (Keshav Library)
if (!defined('LIBRARY_LAT')) define('LIBRARY_LAT', 28.0087395);
if (!defined('LIBRARY_LNG')) define('LIBRARY_LNG', 73.2924508);
if (!defined('GEOFENCE_RADIUS_METERS')) define('GEOFENCE_RADIUS_METERS', 50.0);

/**
 * Haversine formula to calculate distance between two GPS coordinates in meters
 */
function calculate_geofence_distance($lat1, $lon1, $lat2 = LIBRARY_LAT, $lon2 = LIBRARY_LNG) {
    $earth_radius = 6371000; // Earth radius in meters
    $dLat = deg2rad($lat2 - (float)$lat1);
    $dLon = deg2rad($lon2 - (float)$lon1);
    $a = sin($dLat / 2) * sin($dLat / 2) +
         cos(deg2rad((float)$lat1)) * cos(deg2rad($lat2)) *
         sin($dLon / 2) * sin($dLon / 2);
    $c = 2 * atan2(sqrt($a), sqrt(1 - $a));
    return $earth_radius * $c;
}


function is_logged_in() {
    return isset($_SESSION['user_id']);
}

function current_user() {
    global $pdo;
    if (!is_logged_in()) {
        return null;
    }
    $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
    $stmt->execute([$_SESSION['user_id']]);
    return $stmt->fetch();
}

function is_admin() {
    $user = current_user();
    return $user && $user['role'] === 'admin';
}

function require_login() {
    if (!is_logged_in()) {
        header("Location: login.php");
        exit();
    }
}

function require_admin() {
    require_login();
    if (!is_admin()) {
        header("Location: student_dashboard.php");
        exit();
    }
}

function format_currency($amount) {
    return '₹' . number_format($amount, 2);
}

function format_date($date_str) {
    if (!$date_str) return 'N/A';
    return date('d M Y', strtotime($date_str));
}

// Calculate due date for the current billing cycle based on student start date
function get_current_due_date($start_date) {
    $start = new DateTime($start_date);
    $today = new DateTime();
    
    // Day of month registered
    $day_of_month = (int)$start->format('d');
    
    // Construct due date for current month & year
    $year = (int)$today->format('Y');
    $month = (int)$today->format('m');
    
    // Check total days in current month (Natively supported without extra calendar extension)
    $days_in_month = (int)date('t', strtotime(sprintf("%04d-%02d-01", $year, $month)));
    $actual_day = min($day_of_month, $days_in_month);
    
    $current_cycle_due = new DateTime(sprintf("%04d-%02d-%02d", $year, $month, $actual_day));
    
    // If today is past this month's due date, check if paid or overdue
    return $current_cycle_due->format('Y-m-d');
}

// Helper to determine fee status badge and next payment target for a student
function get_student_fee_status($pdo, $allocation_id, $start_date) {
    if (!$start_date) {
        $start_date = date('Y-m-d');
    }
    
    $start = new DateTime($start_date);
    $day_of_month = (int)$start->format('d');
    
    // Fetch all paid records for this allocation
    $stmt = $pdo->prepare("SELECT month_year, paid_date, due_date, amount, payment_mode, receipt_no FROM fee_payments WHERE allocation_id = ? AND payment_status = 'paid' ORDER BY month_year ASC");
    $stmt->execute([$allocation_id]);
    $paid_records = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $paid_months = array_column($paid_records, 'month_year');
    
    // Find the first unpaid month starting from registration month or 3 months prior
    $start_year = (int)$start->format('Y');
    $start_month = (int)$start->format('m');
    
    $curr_dt = new DateTime(sprintf("%04d-%02d-01", $start_year, $start_month));
    $today = new DateTime();
    $today_str = $today->format('Y-m-d');
    
    $target_month = null;
    $target_due_date = null;
    $last_paid_due_date = null;
    
    for ($i = 0; $i < 36; $i++) {
        $m_str = $curr_dt->format('Y-m');
        $days_in_m = (int)$curr_dt->format('t');
        $actual_day = min($day_of_month, $days_in_m);
        $due_str = sprintf("%s-%02d", $m_str, $actual_day);
        
        if (in_array($m_str, $paid_months)) {
            $last_paid_due_date = $due_str;
        } else {
            $target_month = $m_str;
            $target_due_date = $due_str;
            break;
        }
        $curr_dt->modify('+1 month');
    }
    
    if (!$target_month) {
        $target_month = date('Y-m');
        $target_due_date = date('Y-m-d');
    }
    
    $current_month_str = date('Y-m');
    $is_current_paid = in_array($current_month_str, $paid_months);
    
    // If today is past last paid date or current month is paid, determine status
    if ($is_current_paid || ($last_paid_due_date && $today_str < $target_due_date)) {
        return [
            'status' => 'paid',
            'label' => 'Paid (Valid till ' . date('d M Y', strtotime($target_due_date)) . ')',
            'badge_class' => 'badge-success',
            'due_date' => $target_due_date,
            'target_month' => $target_month,
            'target_month_label' => date('F Y', strtotime($target_month . '-01')) . ' (Advance)',
            'is_advance' => true,
            'last_paid_due' => $last_paid_due_date
        ];
    } else {
        if ($today_str > $target_due_date) {
            $days_overdue = (int)floor((strtotime($today_str) - strtotime($target_due_date)) / 86400);
            $days_overdue = max(1, $days_overdue);
            return [
                'status' => 'overdue',
                'label' => "Overdue ($days_overdue days)",
                'badge_class' => 'badge-danger',
                'due_date' => $target_due_date,
                'target_month' => $target_month,
                'target_month_label' => date('F Y', strtotime($target_month . '-01')),
                'is_advance' => false,
                'last_paid_due' => $last_paid_due_date
            ];
        } else {
            return [
                'status' => 'pending',
                'label' => 'Due Soon (' . date('d M Y', strtotime($target_due_date)) . ')',
                'badge_class' => 'badge-warning',
                'due_date' => $target_due_date,
                'target_month' => $target_month,
                'target_month_label' => date('F Y', strtotime($target_month . '-01')),
                'is_advance' => false,
                'last_paid_due' => $last_paid_due_date
            ];
        }
    }
}
?>
