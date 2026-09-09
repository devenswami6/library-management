import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class NotificationHubScreen extends StatefulWidget {
  const NotificationHubScreen({Key? key}) : super(key: key);

  @override
  _NotificationHubScreenState createState() => _NotificationHubScreenState();
}

class _NotificationHubScreenState extends State<NotificationHubScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSending = false;

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

    if (res['success'] == true) {
      _titleController.clear();
      _contentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Notification broadcast sent!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Failed to send')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final isAdmin = user?.role == 'admin';

    // If navigated from student dashboard with notifications list argument
    final studentNotifs = ModalRoute.of(context)?.settings.arguments as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Admin Notification Hub' : 'Library Notifications'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isAdmin) ...[
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
                            Icon(Icons.campaign, color: AppColors.primaryIndigo),
                            SizedBox(width: 8),
                            Text(
                              'Broadcast Announcement',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Notice Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contentController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Message Content *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isSending ? null : _handleSendNotification,
                          icon: const Icon(Icons.send),
                          label: const Text('BROADCAST TO ALL STUDENTS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryIndigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              const Text(
                'Recent Notifications & Alerts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (!isAdmin && studentNotifs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No notifications received yet.'),
                  ),
                ),

              if (!isAdmin && studentNotifs.isNotEmpty)
                ...studentNotifs.map((n) {
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryIndigo,
                        child: Icon(Icons.notifications, color: Colors.white),
                      ),
                      title: Text(
                        n['title'] ?? 'Notice',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(n['content'] ?? ''),
                          const SizedBox(height: 4),
                          Text(
                            n['created_at'] ?? '',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
