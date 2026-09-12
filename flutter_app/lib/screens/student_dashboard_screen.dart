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

class _StudentDashboardScreenState extends State<StudentDashboardScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  Timer? _timer;
  Timer? _geofenceTimer;
  String _currentTime = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startClock();
    _startGeofenceMonitor();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _geofenceTimer?.cancel();
    _pulseController.dispose();
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

    final String todayDateStr = DateFormat('EEE, d MMM yyyy').format(DateTime.now());

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
                    // 1. Welcome & Date Header Card (Concept B)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDark ? AppColors.darkCard : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primaryIndigo.withOpacity(0.12),
                              child: Text(
                                (user?.name ?? 'S')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.primaryIndigo,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    user?.name ?? "Student",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Let's make it a productive day!",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primaryIndigo),
                                  const SizedBox(width: 6),
                                  Text(
                                    todayDateStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Circular Quick Action Icons Grid (Concept B)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildConceptBQuickAction(
                          context,
                          icon: Icons.event_seat_rounded,
                          label: 'My Seat',
                          color: AppColors.primaryIndigo,
                          onTap: () {},
                        ),
                        _buildConceptBQuickAction(
                          context,
                          icon: Icons.access_time_filled_rounded,
                          label: 'Attendance',
                          color: AppColors.statusSuccess,
                          onTap: () {},
                        ),
                        _buildConceptBQuickAction(
                          context,
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Fee Details',
                          color: AppColors.statusWarning,
                          onTap: () => Navigator.of(context).pushNamed('/student_fee'),
                        ),
                        _buildConceptBQuickAction(
                          context,
                          icon: Icons.headset_mic_rounded,
                          label: 'Support',
                          color: AppColors.accentCyan,
                          onTap: () => Navigator.of(context).pushNamed('/support_tickets'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 3. Assigned Seat Desk Card (Concept B)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isDark ? AppColors.darkCard : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isAllotted
                                    ? AppColors.primaryIndigo.withOpacity(0.12)
                                    : AppColors.statusWarning.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.chair_rounded,
                                size: 32,
                                color: isAllotted ? AppColors.primaryIndigo : AppColors.statusWarning,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Assigned Seat',
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isAllotted ? AppColors.statusSuccessBg : AppColors.statusWarningBg,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: isAllotted ? AppColors.statusSuccess : AppColors.statusWarning,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isAllotted ? 'Active' : 'Pending',
                                              style: TextStyle(
                                                color: isAllotted ? Colors.green.shade800 : Colors.amber.shade900,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAllotted
                                        ? 'DESK ${_dashboardData!['allocation']['seat_number']}'
                                        : 'Pending Allotment by Admin',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: isAllotted ? AppColors.primaryIndigo : AppColors.statusWarning,
                                    ),
                                  ),
                                  if (isAllotted) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Shift: ${_dashboardData!['allocation']['shift_name']} (${_dashboardData!['allocation']['start_time']} - ${_dashboardData!['allocation']['end_time']})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. Attendance Today Logger Card (Concept B)
                    if (isAllotted)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: isDark ? AppColors.darkCard : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryIndigo, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Attendance Today',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                          ? AppColors.statusSuccessBg
                                          : AppColors.statusDangerBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                          ? 'Checked In'
                                          : 'Not Checked In',
                                      style: TextStyle(
                                        color: attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                            ? Colors.green.shade800
                                            : Colors.red.shade800,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mark your presence for today (Live time: $_currentTime)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                        ? ElevatedButton.icon(
                                            onPressed: null,
                                            icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white70),
                                            label: const Text('Checked In', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey.shade700,
                                              disabledBackgroundColor: Colors.grey.shade700,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          )
                                        : AnimatedBuilder(
                                            animation: _pulseController,
                                            builder: (context, child) {
                                              return Transform.scale(
                                                scale: _pulseAnimation.value,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(10),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF10B981).withOpacity(0.5 * _pulseController.value + 0.2),
                                                        blurRadius: 10.0 * _pulseController.value + 4.0,
                                                        spreadRadius: 2.0 * _pulseController.value + 0.5,
                                                      ),
                                                    ],
                                                  ),
                                                  child: ElevatedButton.icon(
                                                    onPressed: _handleCheckIn,
                                                    icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                                                    label: const Text('Check In', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF10B981), // Vibrant Green
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      elevation: 4,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                          ? _handleCheckOut
                                          : null,
                                      icon: const Icon(Icons.logout_rounded, size: 16),
                                      label: const Text('Check Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                            ? Colors.redAccent
                                            : Colors.grey.shade500,
                                        disabledForegroundColor: Colors.grey.shade500,
                                        side: BorderSide(
                                          color: attProvider.todayAttendance?.isCurrentlyCheckedIn == true
                                              ? Colors.redAccent
                                              : Colors.grey.shade400,
                                          width: 1.5,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: AppColors.statusWarningBg,
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(Icons.lock_clock, color: AppColors.statusWarning, size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Daily Attendance Logger will unlock automatically once Admin approves your registration and allots your desk seat.',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // 5. 2x2 Feature Shortcuts Grid (Concept B)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        _buildConceptBGridShortcut(
                          context,
                          icon: Icons.grid_view_rounded,
                          title: 'View Seat Matrix',
                          subtitle: 'Check availability',
                          color: AppColors.primaryIndigo,
                          onTap: () => Navigator.of(context).pushNamed('/seat_matrix'),
                        ),
                        _buildConceptBGridShortcut(
                          context,
                          icon: Icons.receipt_long_rounded,
                          title: 'My Fee Details',
                          subtitle: 'Payment & Receipts',
                          color: AppColors.accentCyan,
                          onTap: () => Navigator.of(context).pushNamed('/student_fee'),
                        ),
                        _buildConceptBGridShortcut(
                          context,
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Chat with Admin',
                          subtitle: 'Instant Support',
                          unreadCount: _dashboardData?['unread_chat_count'] ?? 0,
                          color: AppColors.accentViolet,
                          onTap: () => Navigator.of(context).pushNamed('/student_chat'),
                        ),
                        _buildConceptBGridShortcut(
                          context,
                          icon: Icons.support_agent_rounded,
                          title: 'Support Tickets',
                          subtitle: 'View Help History',
                          color: AppColors.statusWarning,
                          onTap: () => Navigator.of(context).pushNamed('/support_tickets'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 6. Motivation Quote Card (Concept B Banner)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryIndigo.withOpacity(0.08),
                            AppColors.accentCyan.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_stories_rounded, color: AppColors.primaryIndigo, size: 28),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '"Discipline today, Success tomorrow."',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryIndigo,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Keep studying consistently at Keshav Self-Study Hall!',
                                  style: TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildConceptBQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptBGridShortcut(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    int unreadCount = 0,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
