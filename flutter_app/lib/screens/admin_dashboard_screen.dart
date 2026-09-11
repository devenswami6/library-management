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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminUser = authProvider.currentUser;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Admin Command Center',
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryIndigo),
            )
          : RefreshIndicator(
              onRefresh: () async => _loadStats(),
              color: AppColors.primaryIndigo,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Concept B Admin Header Banner Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                              : [AppColors.primaryIndigo, const Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryIndigo.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome, ${adminUser?.name ?? 'Admin'} 👋',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      'Library Control Panel • Full Permissions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFE0E7FF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.shield_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Desks: ${_stats?['total_seats'] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 12,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                Text(
                                  'Students: ${_stats?['total_students'] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 12,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                Text(
                                  'Pending: ${_stats?['pending_students'] ?? 0}',
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Real-time Quick Metrics Grid
                    const Text(
                      'Real-Time Metrics',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

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
                          icon: Icons.people_alt_rounded,
                          color: AppColors.primaryIndigo,
                        ),
                        StatBadge(
                          title: 'Pending Requests',
                          value: '${_stats?['pending_students'] ?? 0}',
                          icon: Icons.pending_actions_rounded,
                          color: AppColors.statusWarning,
                        ),
                        StatBadge(
                          title: 'Total Desks',
                          value: '${_stats?['total_seats'] ?? 0}',
                          icon: Icons.chair_rounded,
                          color: AppColors.accentCyan,
                        ),
                        StatBadge(
                          title: 'Present Inside',
                          value: '${_stats?['currently_inside'] ?? 0}',
                          icon: Icons.how_to_reg_rounded,
                          color: AppColors.statusSuccess,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 3. Operations & Seat Control Section
                    const Text(
                      'Desk & Attendance Operations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Visual Seat Matrix Grid',
                      subtitle: 'View desk allocations across morning, evening & full-day shifts',
                      icon: Icons.grid_view_rounded,
                      color: AppColors.primaryIndigo,
                      onTap: () {
                        Navigator.of(context).pushNamed('/seat_matrix');
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Pending Student Allotments',
                      subtitle: 'Review student registration requests & assign desk numbers',
                      icon: Icons.assignment_ind_rounded,
                      color: AppColors.statusWarning,
                      badgeCount: _stats?['pending_students'] ?? 0,
                      onTap: () {
                        Navigator.of(context).pushNamed('/pending_students');
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Live Attendance Logger',
                      subtitle: 'Monitor student check-ins, manual entry & force check-out',
                      icon: Icons.fact_check_rounded,
                      color: AppColors.statusSuccess,
                      onTap: () {
                        Navigator.of(context).pushNamed('/live_attendance');
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Manage Desks & 1-Click Range',
                      subtitle: 'Generate desk ranges (e.g. E-01 to E-10) or delete rows',
                      icon: Icons.chair_alt_rounded,
                      color: AppColors.accentCyan,
                      onTap: () {
                        Navigator.of(context).pushNamed('/manage_seats');
                      },
                    ),
                    const SizedBox(height: 22),

                    // 4. Student & Support Communications Section
                    const Text(
                      'Students & Communications',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Manage Student Directory 👥',
                      subtitle: 'View complete student profiles, father name, device ID & delete',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFFF97316),
                      onTap: () {
                        Navigator.of(context).pushNamed('/manage_students');
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Direct Student Support Chats 💬',
                      subtitle: 'Chat 1-on-1 directly with registered library students',
                      icon: Icons.chat_bubble_rounded,
                      color: const Color(0xFF0EA5E9),
                      onTap: () {
                        Navigator.of(context).pushNamed('/admin_chat_threads');
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Notification Hub 📢',
                      subtitle: 'Broadcast notices to all students or direct message student',
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.primaryIndigo,
                      onTap: () {
                        Navigator.of(context).pushNamed('/notification_hub');
                      },
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Support Tickets Desk 🎧',
                      subtitle: 'Review & resolve student support requests (48h auto purge)',
                      icon: Icons.support_agent_rounded,
                      color: const Color(0xFFEAB308),
                      onTap: () {
                        Navigator.of(context).pushNamed('/manage_complaints');
                      },
                    ),
                    const SizedBox(height: 22),

                    // 5. Finance Section
                    const Text(
                      'Financial & Billing Center',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    _buildAdminMenuCard(
                      title: 'Fee Management Center 💳',
                      subtitle: 'Track collections, record cash/UPI payments & generate receipts',
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.of(context).pushNamed('/manage_fees');
                      },
                    ),
                    const SizedBox(height: 24),

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
                    const SizedBox(height: 12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
