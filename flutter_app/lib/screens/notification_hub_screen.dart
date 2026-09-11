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

  final List<dynamic> _historyNotifs = [
    {
      'title': 'Library Closed on 2 Oct',
      'content': 'The self-study hall will remain closed on 2nd October for Gandhi Jayanti holiday.',
      'target': 'To: All Students',
      'created_at': 'Today, 09:30 AM',
    },
    {
      'title': 'Maintain Silence in Hall',
      'content': 'Please keep mobile phones on silent mode while inside the study hall.',
      'target': 'To: All Students',
      'created_at': 'Yesterday',
    },
    {
      'title': 'Monthly Fee Reminder',
      'content': 'Monthly seat fees for October 2026 are due. Kindly clear your dues.',
      'target': 'To: All Students',
      'created_at': '3 days ago',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
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
        String targetText = 'To: All Students';
        if (_sendTarget == 'specific' && _selectedStudentId != null) {
          final targetStudent = _studentsList.firstWhere(
            (s) => s['id'] == _selectedStudentId || s['id'].toString() == _selectedStudentId.toString(),
            orElse: () => {'name': 'Student'},
          );
          targetText = 'To: ${targetStudent['name']}';
        }

        _historyNotifs.insert(0, {
          'title': title.isEmpty ? 'Notice' : title,
          'content': content,
          'target': targetText,
          'created_at': 'Just Now',
        });
        _titleController.clear();
        _contentController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Notification announcement sent!'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
        _tabController.animateTo(1); // Switch to History tab
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to send notification')),
        );
      }
    }
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
                // TAB 1: Broadcast Form (Fixing Radio Overflow & Adding Student Dropdown Selector!)
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

                              // Responsive Radio Target Selection (Fixing Point 5 Overflow!)
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

                              // Student Dropdown Picker (Fixing Point 5 Specific Student Selection!)
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
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _historyNotifs.length,
                  itemBuilder: (ctx, idx) {
                    final item = _historyNotifs[idx];
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
                              backgroundColor: Colors.amber.withOpacity(0.15),
                              child: const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? 'Notice',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['content'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item['target'] ?? 'To: All Students',
                                        style: const TextStyle(fontSize: 11, color: AppColors.primaryIndigo, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        item['created_at'] ?? '',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _historyNotifs.map((n) {
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryIndigo,
                        child: Icon(Icons.notifications_rounded, color: Colors.white),
                      ),
                      title: Text(n['title'] ?? 'Notice', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(n['content'] ?? ''),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
