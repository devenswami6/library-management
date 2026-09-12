<?php
// api/student_actions.php - Student actions API handler

require_once __DIR__ . '/../config/auth.php';
require_login();

$user = current_user();
$action = $_REQUEST['action'] ?? '';

// 1. DAILY ATTENDANCE CHECK-IN (USES STUDENT DEVICE TIME IF PROVIDED & GPS GEOFENCE)
if ($action === 'checkin') {
    $today = date('Y-m-d');
    $device_time = trim($_POST['device_time'] ?? '');
    $lat = isset($_POST['latitude']) ? (float)$_POST['latitude'] : 0.0;
    $lng = isset($_POST['longitude']) ? (float)$_POST['longitude'] : 0.0;

    if ($lat == 0.0 || $lng == 0.0) {
        header("Location: ../student_dashboard.php?tab=tabAttendance&error=" . urlencode("Location permission required. Please enable GPS location services in your browser."));
        exit();
    }

    $distance = calculate_geofence_distance($lat, $lng);
    if ($distance > GEOFENCE_RADIUS_METERS) {
        $dist_text = round($distance, 1) > 1000 ? round($distance / 1000, 2) . ' km' : round($distance, 1) . ' meters';
        header("Location: ../student_dashboard.php?tab=tabAttendance&error=" . urlencode("Check-in Failed: You are $dist_text away from Keshav Library. Attendance is only permitted within 50 meters of the library campus."));
        exit();
    }
    
    // If device time is provided (e.g. 11:42:35), sanitize or fallback to server time
    if (!empty($device_time)) {
        $time = date('H:i:s', strtotime($device_time));
    } else {
        $time = date('H:i:s');
    }

    // Check if already checked in today
    $stmt = $pdo->prepare("SELECT id FROM attendance WHERE user_id = ? AND date = ?");
    $stmt->execute([$user['id'], $today]);
    $att = $stmt->fetch();

    if ($att) {
        header("Location: ../student_dashboard.php?tab=tabAttendance&error=" . urlencode("You have already checked in today."));
    } else {
        $insert = $pdo->prepare("INSERT INTO attendance (user_id, date, check_in_time, status) VALUES (?, ?, ?, 'present')");
        $insert->execute([$user['id'], $today, $time]);
        header("Location: ../student_dashboard.php?tab=tabAttendance&msg=" . urlencode("Check-in recorded at " . date('g:i:s A', strtotime($time)) . " (Verified within 50m Geofence)!"));
    }
    exit();
}

// 2. DAILY ATTENDANCE CHECK-OUT (USES STUDENT DEVICE TIME IF PROVIDED)
if ($action === 'checkout') {
    $today = date('Y-m-d');
    $device_time = trim($_POST['device_time'] ?? '');
    $lat = isset($_POST['latitude']) ? (float)$_POST['latitude'] : 0.0;
    $lng = isset($_POST['longitude']) ? (float)$_POST['longitude'] : 0.0;

    if ($lat == 0.0 || $lng == 0.0) {
        header("Location: ../student_dashboard.php?tab=tabAttendance&error=" . urlencode("Location permission required. Please enable GPS location services in your browser."));
        exit();
    }

    $distance = calculate_geofence_distance($lat, $lng);
    if ($distance > GEOFENCE_RADIUS_METERS) {
        $dist_text = round($distance, 1) > 1000 ? round($distance / 1000, 2) . ' km' : round($distance, 1) . ' meters';
        header("Location: ../student_dashboard.php?tab=tabAttendance&error=" . urlencode("Check-out Warning: You are $dist_text away from Keshav Library campus. Check-out recorded."));
    }

    if (!empty($device_time)) {
        $time = date('H:i:s', strtotime($device_time));
    } else {
        $time = date('H:i:s');
    }

    $stmt = $pdo->prepare("SELECT id FROM attendance WHERE user_id = ? AND date = ?");
    $stmt->execute([$user['id'], $today]);
    $att = $stmt->fetch();

    if ($att) {
        $update = $pdo->prepare("UPDATE attendance SET check_out_time = ? WHERE id = ?");
        $update->execute([$time, $att['id']]);
        header("Location: ../student_dashboard.php?tab=tabAttendance&msg=" . urlencode("Check-out recorded at " . date('g:i:s A', strtotime($time)) . "!"));
    } else {
        header("Location: ../student_dashboard.php?tab=tabAttendance&error=" . urlencode("You need to check-in first."));
    }
    exit();
}

// 3. SUBMIT COMPLAINT / ISSUE TICKET
if ($action === 'submit_complaint') {
    $category = trim($_POST['category'] ?? 'Other');
    $subject = trim($_POST['subject'] ?? '');
    $description = trim($_POST['description'] ?? '');

    if (empty($subject) || empty($description)) {
        header("Location: ../student_dashboard.php?tab=tabSupport&error=" . urlencode("Subject and description are required."));
        exit();
    }

    $stmt = $pdo->prepare("INSERT INTO complaints (user_id, category, subject, description, status) VALUES (?, ?, ?, ?, 'open')");
    $stmt->execute([$user['id'], $category, $subject, $description]);

    // Dispatch instant alert notification to Admin
    try {
        $admin_id = (int)$pdo->query("SELECT id FROM users WHERE role = 'admin' LIMIT 1")->fetchColumn();
        if ($admin_id <= 0) $admin_id = 1;

        $stu_name = $user['name'] ?? ('Student #' . $user['id']);

        $stmt_notif = $pdo->prepare("INSERT INTO notifications (user_id, title, message) VALUES (?, ?, ?)");
        $stmt_notif->execute([
            $admin_id,
            "⚠️ New Complaint: " . $stu_name,
            "[$category] $subject: $description"
        ]);
    } catch (Exception $e) {}

    header("Location: ../student_dashboard.php?tab=tabSupport&msg=" . urlencode("Complaint ticket submitted successfully! Admin will resolve it shortly."));
    exit();
}
?>
