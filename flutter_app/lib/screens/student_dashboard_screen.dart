import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/attendance_model.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/native_notification_service.dart';
import '../widgets/custom_app_bar.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  @override
  _StudentDashboardScreenState createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  Timer? _timer;
  Timer? _geofenceTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _startClock();
    _startGeofenceMonitor();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _geofenceTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
        });
      }
    });
  }

  void _startGeofenceMonitor() {
    _geofenceTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (!mounted) return;
      final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

      if (user == null || attProvider.todayAttendance?.isCurrentlyCheckedIn != true) {
        return;
      }

      // Anti-Cheat Check: Check if GPS is turned OFF while checked in
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final success = await attProvider.checkOut(user.id, isAuto: true);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto Checked-Out: GPS Location was turned OFF on your device while checked in.'),
              backgroundColor: Colors.orangeAccent,
              duration: Duration(seconds: 6),
            ),
          );
          _loadData();
        }
        return;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          28.0087395,
          73.2924508,
        );

        if (distance > 50.0) {
          final success = await attProvider.checkOut(user.id, isAuto: true);
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Auto Checked-Out: You moved ${distance.toStringAsFixed(1)}m away from Keshav Library (50m limit).'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 6),
              ),
            );
            _loadData();
          }
        }
      } catch (e) {
        final success = await attProvider.checkOut(user.id, isAuto: true);
        if (success && mounted) {
          _loadData();
        }
      }
    });
  }

  void _loadData() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    NativeNotificationService.startNativeService(user.id);

    try {
      final data = await ApiService.getStudentDashboard(user.id);
      if (mounted) {
        if (data['success'] == true && data['user'] != null) {
          final updatedUser = UserModel.fromJson(data['user']);
          Provider.of<AuthProvider>(context, listen: false).updateCurrentUser(updatedUser);
        }

        setState(() {
          _dashboardData = data;
          _isLoading = false;
        });

        if (data['success'] == true) {
          final attModel = data['today_attendance'] != null
              ? AttendanceModel.fromJson(data['today_attendance'])
              : null;
          Provider.of<AttendanceProvider>(context, listen: false)
              .setTodayAttendance(attModel);
        }

        if (data['success'] == true && data['notifications'] != null) {
          NotificationService().processNotifications(data['notifications'] as List<dynamic>);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleCheckIn() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final success = await attProvider.checkIn(user.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(attProvider.message ?? 'Check-in response')),
    );
    _loadData();
  }

  void _handleCheckOut() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final success = await attProvider.checkOut(user.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(attProvider.message ?? 'Check-out response')),
    );
    _loadData();
  }

  void _showComplaintDialog() {
    final catController = TextEditingController(text: 'General');
    final subjController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Complaint / Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjController,
              decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
              if (user != null && subjController.text.isNotEmpty) {
                final res = await ApiService.submitComplaint(
                  user.id,
                  catController.text,
                  subjController.text,
                  descController.text,
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'Submitted')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final attProvider = Provider.of<AttendanceProvider>(context);
    final notifications = _dashboardData?['notifications'] as List<dynamic>? ?? [];
    final bool isAllotted = _dashboardData?['allocation'] != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Student Dashboard',
        unreadNotifications: notifications.where((n) => n['is_read'] == 0 || n['is_read'] == false).length,
        onNotificationTap: () {
          Navigator.of(context).pushNamed('/notifications', arguments: notifications);
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadData(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome & Time Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryBlue, AppColors.primaryIndigo],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${user?.name ?? "Student"}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Live Device Time: $_currentTime',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 1: My Desk Allotment Card
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isAllotted
                                    ? AppColors.seatAvailable.withOpacity(0.15)
                                    : AppColors.seatPending.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.event_seat,
                                size: 36,
                                color: isAllotted ? AppColors.seatAvailable : AppColors.seatPending,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Assigned Seat Desk',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    isAllotted
                                        ? 'DESK ${_dashboardData!['allocation']['seat_number']}'
                                        : 'Pending Allotment by Admin',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isAllotted ? AppColors.seatAvailable : AppColors.seatPending,
                                    ),
                                  ),
                                  if (isAllotted)
                                    Text(
                                      'Shift: ${_dashboardData!['allocation']['shift_name']} (${_dashboardData!['allocation']['start_time']} - ${_dashboardData!['allocation']['end_time']})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card 2: Attendance Logger (ONLY SHOW IF SEAT IS ALLOTTED!)
                    if (isAllotted)
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.access_time_filled, color: AppColors.primaryIndigo),
                                  SizedBox(width: 8),
                                  Text(
                                    'Daily Attendance Logger',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (attProvider.todayAttendance != null) ...[
                                Text(
                                  'Check-in Time: ${attProvider.todayAttendance!.checkInTime ?? "N/A"}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                if (attProvider.todayAttendance!.checkOutTime != null)
                                  Text(
                                    'Check-out Time: ${attProvider.todayAttendance!.checkOutTime}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                          ? null
                                          : _handleCheckIn,
                                      icon: const Icon(Icons.login),
                                      label: const Text('Check In'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.seatAvailable,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                          ? _handleCheckOut
                                          : null,
                                      icon: const Icon(Icons.logout),
                                      label: const Text('Check Out'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.seatOccupied,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.amber.withOpacity(0.1),
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.lock_clock, color: Colors.amber, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Daily Attendance Logger will unlock automatically once Admin approves your registration and allots your desk seat.',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.amber),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // View Seat Matrix Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/seat_matrix');
                      },
                      icon: const Icon(Icons.grid_on),
                      label: const Text('VIEW LIBRARY SEAT MATRIX GRID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card 3: Monthly Fee Ledger
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_wallet, color: AppColors.seatPending),
                                SizedBox(width: 8),
                                Text(
                                  'Monthly Fee Overview',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Monthly Fee Amount: ₹${_dashboardData?['fee_details']?['amount'] ?? 0}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Due Date: ${_dashboardData?['fee_details']?['due_date'] ?? "N/A"}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: const Text('View Payment Receipts & History'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryIndigo,
                                  side: const BorderSide(color: AppColors.primaryIndigo),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pushNamed('/student_fee');
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Premium Direct Personal Chat Card with Admin
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pushNamed('/student_chat');
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryIndigo, Color(0xFF0EA5E9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryIndigo.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mark_chat_unread_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Direct Chat with Admin 💬',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if ((_dashboardData?['unread_chat_count'] ?? 0) > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${_dashboardData!['unread_chat_count']} NEW',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Instant 1-on-1 support & desk help • Clears in 48h',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Support / Complaint Button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/support_tickets');
                      },
                      icon: const Icon(Icons.help_outline),
                      label: const Text('My Support Tickets & Need Help History'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Powered by Ramxonwebwork',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryIndigo,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
    );
  }
}
