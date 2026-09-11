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
  String _sendTarget = 'all'; // all or specific

  List<dynamic> _historyNotifs = [
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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

    setState(() => _isSending = true);
    final res = await ApiService.sendNotification(
      title.isEmpty ? 'Notice' : title,
      content,
    );
    setState(() => _isSending = false);

    if (mounted) {
      if (res['success'] == true) {
        _historyNotifs.insert(0, {
          'title': title.isEmpty ? 'Notice' : title,
          'content': content,
          'target': _sendTarget == 'all' ? 'To: All Students' : 'To: Specific Student',
          'created_at': 'Just Now',
        });
        _titleController.clear();
        _contentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Notification broadcast sent successfully!'),
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
                // TAB 1: Broadcast Form (Matching Screen 13)
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
                                  hintText: 'Enter message for all students...',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              const Text('Send To:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'all',
                                    groupValue: _sendTarget,
                                    activeColor: AppColors.primaryIndigo,
                                    onChanged: (val) => setState(() => _sendTarget = val!),
                                  ),
                                  const Text('All Students'),
                                  const SizedBox(width: 16),
                                  Radio<String>(
                                    value: 'specific',
                                    groupValue: _sendTarget,
                                    activeColor: AppColors.primaryIndigo,
                                    onChanged: (val) => setState(() => _sendTarget = val!),
                                  ),
                                  const Text('Specific Student'),
                                ],
                              ),
                              const SizedBox(height: 20),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
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

                // TAB 2: History List (Matching Screen 14)
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
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
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
