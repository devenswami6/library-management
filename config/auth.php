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

// Helper to determine fee status badge for a student
function get_student_fee_status($pdo, $allocation_id, $start_date) {
    $current_month = date('Y-m');
    $due_date = get_current_due_date($start_date);
    
    // Check if there is a payment record for current month
    $stmt = $pdo->prepare("SELECT * FROM fee_payments WHERE allocation_id = ? AND month_year = ?");
    $stmt->execute([$allocation_id, $current_month]);
    $payment = $stmt->fetch();
    
    if ($payment && $payment['payment_status'] === 'paid') {
        return [
            'status' => 'paid',
            'label' => 'Paid',
            'badge_class' => 'badge-success',
            'due_date' => $due_date,
            'payment' => $payment
        ];
    }
    
    // If not paid, compare current date with due date
    $today = date('Y-m-d');
    if ($today > $due_date) {
        $days_overdue = (strtotime($today) - strtotime($due_date)) / 86400;
        return [
            'status' => 'overdue',
            'label' => "Overdue ($days_overdue days)",
            'badge_class' => 'badge-danger',
            'due_date' => $due_date,
            'payment' => $payment
        ];
    } else {
        return [
            'status' => 'pending',
            'label' => 'Due Soon',
            'badge_class' => 'badge-warning',
            'due_date' => $due_date,
            'payment' => $payment
        ];
    }
}
?>
