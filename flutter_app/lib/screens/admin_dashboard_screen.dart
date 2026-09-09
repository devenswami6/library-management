import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/stat_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() async {
    try {
      final res = await ApiService.getAdminStats();
      if (mounted) {
        setState(() {
          _stats = res['stats'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Admin Command Center',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadStats(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Overview & Real-time Stats',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.1,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        StatBadge(
                          title: 'Active Students',
                          value: '${_stats?['total_students'] ?? 0}',
                          icon: Icons.people_alt,
                          color: AppColors.primaryIndigo,
                        ),
                        StatBadge(
                          title: 'Pending Requests',
                          value: '${_stats?['pending_students'] ?? 0}',
                          icon: Icons.pending_actions,
                          color: AppColors.seatPending,
                        ),
                        StatBadge(
                          title: 'Total Desks',
                          value: '${_stats?['total_seats'] ?? 0}',
                          icon: Icons.chair,
                          color: AppColors.accentCyan,
                        ),
                        StatBadge(
                          title: 'Present Inside',
                          value: '${_stats?['currently_inside'] ?? 0}',
                          icon: Icons.how_to_reg,
                          color: AppColors.seatAvailable,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Management Actions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Action 1: Interactive Seat Map
                    _buildAdminMenuCard(
                      title: 'Visual Seat Matrix Grid',
                      subtitle: 'View desk allocations across morning, evening & full-day shifts',
                      icon: Icons.grid_on,
                      color: AppColors.primaryBlue,
                      onTap: () {
                        Navigator.of(context).pushNamed('/seat_matrix');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action 2: Student Registration Approval & Seat Allotment
                    _buildAdminMenuCard(
                      title: 'Pending Student Allotments',
                      subtitle: 'Review student requests and assign specific seat desks',
                      icon: Icons.assignment_ind,
                      color: AppColors.seatPending,
                      badgeCount: _stats?['pending_students'] ?? 0,
                      onTap: () {
                        Navigator.of(context).pushNamed('/pending_students');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action 2.5: Manage Student Directory & Delete Records
                    _buildAdminMenuCard(
                      title: 'Manage Student Directory & Delete 👥',
                      subtitle: 'View complete student profile details, father name, device ID & delete records',
                      icon: Icons.people_alt,
                      color: Colors.deepOrange,
                      onTap: () {
                        Navigator.of(context).pushNamed('/manage_students');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action 3: Live Attendance Manager
                    _buildAdminMenuCard(
                      title: 'Live Attendance Logger',
                      subtitle: 'Monitor present students, manual check-in & force check-out',
                      icon: Icons.fact_check,
                      color: AppColors.seatAvailable,
                      onTap: () {
                        Navigator.of(context).pushNamed('/live_attendance');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action 4: Broadcast Notifications
                    _buildAdminMenuCard(
                      title: 'Notification Hub',
                      subtitle: 'Broadcast notices to all students or direct message individual student',
                      icon: Icons.notifications_active,
                      color: AppColors.primaryIndigo,
                      onTap: () {
                        Navigator.of(context).pushNamed('/notification_hub');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action 4.5: Direct Personal Student Chats
                    _buildAdminMenuCard(
                      title: 'Direct Student Support Chats 💬',
                      subtitle: 'Chat 1-on-1 directly with registered library students',
                      icon: Icons.chat_bubble_outline,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.of(context).pushNamed('/admin_chat_threads');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action 5: Bulk Seat Range & Delete Manager
                    _buildAdminMenuCard(
                      title: 'Manage Desks & 1-Click Range',
                      subtitle: 'Generate ranges (e.g. E-01 to E-10) or delete desks/rows',
                      icon: Icons.auto_awesome,
                      color: AppColors.accentCyan,
                      onTap: () {
                        Navigator.of(context).pushNamed('/manage_seats');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action 6: Support Tickets Desk
                    _buildAdminMenuCard(
                      title: 'Support Tickets Desk',
                      subtitle: 'Review & solve student help requests (Open, In Progress, Resolved)',
                      icon: Icons.headset_mic,
                      color: Colors.amber.shade800,
                      onTap: () {
                        Navigator.of(context).pushNamed('/manage_complaints');
                      },
                    ),
                    const SizedBox(height: 12),

                    // Action 7: Fee Management Center
                    _buildAdminMenuCard(
                      title: 'Fee Management Center',
                      subtitle: 'Track collections, due fees, record cash/UPI payments & receipts',
                      icon: Icons.payments,
                      color: Colors.teal.shade700,
                      onTap: () {
                        Navigator.of(context).pushNamed('/manage_fees');
                      },
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

  Widget _buildAdminMenuCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
