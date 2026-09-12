import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

class NotificationHubScreen extends StatefulWidget {
  const NotificationHubScreen({Key? key}) : super(key: key);

  @override
  _NotificationHubScreenState createState() => _NotificationHubScreenState();
}

class _NotificationHubScreenState extends State<NotificationHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSending = false;
  String _sendTarget = 'all'; // 'all' or 'specific'

  List<dynamic> _studentsList = [];
  int? _selectedStudentId;
  bool _isLoadingStudents = false;

  List<dynamic> _historyNotifs = [];
  bool _isLoadingNotifs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStudents();
      _fetchNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user?.role != 'admin') return;

    setState(() => _isLoadingStudents = true);
    final res = await ApiService.getAllStudents();
    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _studentsList = res['students'] ?? [];
          if (_studentsList.isNotEmpty) {
            _selectedStudentId = _studentsList.first['id'] is int
                ? _studentsList.first['id']
                : int.tryParse(_studentsList.first['id'].toString());
          }
          _isLoadingStudents = false;
        });
      } else {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  Future<void> _fetchNotifications() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isLoadingNotifs = true);
    if (user.role == 'admin') {
      final res = await ApiService.getAdminNotifications(user.id);
      if (mounted) {
        if (res['success'] == true && res['admin_notifications'] != null) {
          final list = List<dynamic>.from(res['admin_notifications']);
          list.sort((a, b) {
            final aTime = (a['created_at'] ?? '').toString();
            final bTime = (b['created_at'] ?? '').toString();
            return bTime.compareTo(aTime);
          });
          setState(() {
            _historyNotifs = list;
            _isLoadingNotifs = false;
          });
        } else {
          setState(() => _isLoadingNotifs = false);
        }
      }
    } else {
      final res = await ApiService.getStudentDashboard(user.id);
      if (mounted) {
        if (res['success'] == true && res['notifications'] != null) {
          final list = List<dynamic>.from(res['notifications']);
          list.sort((a, b) {
            final aTime = (a['created_at'] ?? '').toString();
            final bTime = (b['created_at'] ?? '').toString();
            return bTime.compareTo(aTime);
          });
          setState(() {
            _historyNotifs = list;
            _isLoadingNotifs = false;
          });
        } else {
          setState(() => _isLoadingNotifs = false);
        }
      }
    }
  }

  void _handleSendNotification() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification message content is required.')),
      );
      return;
    }

    if (_sendTarget == 'specific' && _selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a specific student from the dropdown.')),
      );
      return;
    }

    setState(() => _isSending = true);
    final res = await ApiService.sendNotification(
      title.isEmpty ? 'Notice' : title,
      content,
      targetUserId: _sendTarget == 'specific' ? _selectedStudentId : null,
    );
    setState(() => _isSending = false);

    if (mounted) {
      if (res['success'] == true) {
        _titleController.clear();
        _contentController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Notification announcement sent!'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
        _fetchNotifications();
        _tabController.animateTo(1); // Switch to History tab
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to send notification')),
        );
      }
    }
  }

  Widget _buildNotificationList(bool isDark, bool isAdmin) {
    if (_isLoadingNotifs) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo));
    }

    if (_historyNotifs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: AppColors.primaryIndigo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(height: 12),
                const Text(
                  'No notifications found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pull down to refresh',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      color: AppColors.primaryIndigo,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _historyNotifs.length,
        itemBuilder: (ctx, idx) {
          final item = _historyNotifs[idx];
          final title = item['title'] ?? 'Notice';
          final message = item['message'] ?? item['content'] ?? '';
          final createdAt = item['created_at'] ?? '';
          final type = item['type'] ?? 'notice';

          IconData iconData = Icons.notifications_active_rounded;
          Color iconBg = Colors.amber;

          if (type == 'registration') {
            iconData = Icons.person_add_rounded;
            iconBg = AppColors.primaryIndigo;
          } else if (type == 'complaint') {
            iconData = Icons.warning_amber_rounded;
            iconBg = AppColors.statusDanger;
          } else if (type == 'chat') {
            iconData = Icons.chat_rounded;
            iconBg = Colors.teal;
          }

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? AppColors.darkCard : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: iconBg.withOpacity(0.15),
                    child: Icon(iconData, color: iconBg, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        if (createdAt.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              createdAt,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthProvider>(context).currentUser;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Notification Hub',
        bottom: isAdmin
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(text: 'Broadcast 📢'),
                  Tab(text: 'History 📜'),
                ],
              )
            : null,
      ),
      body: isAdmin
          ? TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Broadcast Form
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: isDark ? AppColors.darkCard : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Send Announcement',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 14),

                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Notice Title',
                                  hintText: 'Enter notice title...',
                                  prefixIcon: Icon(Icons.title_rounded, color: AppColors.primaryIndigo),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),

                              TextField(
                                controller: _contentController,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Message Content *',
                                  hintText: 'Enter message for students...',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              const Text('Send To:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 6),

                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => setState(() => _sendTarget = 'all'),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'all',
                                          groupValue: _sendTarget,
                                          activeColor: AppColors.primaryIndigo,
                                          onChanged: (val) => setState(() => _sendTarget = val!),
                                        ),
                                        const Text('All Students', style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => setState(() => _sendTarget = 'specific'),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'specific',
                                          groupValue: _sendTarget,
                                          activeColor: AppColors.primaryIndigo,
                                          onChanged: (val) => setState(() => _sendTarget = val!),
                                        ),
                                        const Text('Specific Student', style: TextStyle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (_sendTarget == 'specific') ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryIndigo.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Select Target Student:',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryIndigo),
                                      ),
                                      const SizedBox(height: 8),
                                      _isLoadingStudents
                                          ? const SizedBox(
                                              height: 40,
                                              child: Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo, strokeWidth: 2)),
                                            )
                                          : _studentsList.isEmpty
                                              ? const Text('No students found in directory.', style: TextStyle(color: Colors.grey))
                                              : DropdownButtonFormField<int>(
                                                  value: _selectedStudentId,
                                                  isExpanded: true,
                                                  decoration: const InputDecoration(
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    border: OutlineInputBorder(),
                                                    fillColor: Colors.white,
                                                    filled: true,
                                                  ),
                                                  items: _studentsList.map<DropdownMenuItem<int>>((s) {
                                                    final int id = s['id'] is int ? s['id'] : int.tryParse(s['id'].toString()) ?? 0;
                                                    return DropdownMenuItem<int>(
                                                      value: id,
                                                      child: Text(
                                                        '${s['name']} (Desk ${s['seat_number'] ?? "N/A"} • ${s['phone'] ?? ""})',
                                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    if (val != null) setState(() => _selectedStudentId = val);
                                                  },
                                                ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _isSending ? null : _handleSendNotification,
                                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                                  label: _isSending
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text(
                                          'Send Announcement',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryIndigo,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // TAB 2: History List
                _buildNotificationList(isDark, isAdmin),
              ],
            )
          : _buildNotificationList(isDark, isAdmin),
    );
  }
}

