import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({Key? key}) : super(key: key);

  @override
  _SupportTicketsScreenState createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  bool _isLoading = true;
  List<dynamic> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final res = await ApiService.getStudentComplaints(user.id);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _tickets = res['complaints'] ?? [];
        }
      });
    }
  }

  void _showNewTicketDialog() {
    final catController = TextEditingController(text: 'AC/Cooling');
    final subjController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.headset_mic, color: AppColors.primaryIndigo),
            SizedBox(width: 8),
            Text('Submit Help Request'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: 'AC/Cooling',
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'AC/Cooling', child: Text('AC / Cooling Issue')),
                  DropdownMenuItem(value: 'WiFi', child: Text('Wi-Fi / Internet Slow')),
                  DropdownMenuItem(value: 'Desk/Chair', child: Text('Desk Light / Chair Damage')),
                  DropdownMenuItem(value: 'Cleanliness', child: Text('Washroom / Cleanliness')),
                  DropdownMenuItem(value: 'Noise', child: Text('Noise Disturbance')),
                  DropdownMenuItem(value: 'General', child: Text('General Query / Other')),
                ],
                onChanged: (val) {
                  if (val != null) catController.text = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjController,
                decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Detailed Description', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
              if (user != null && subjController.text.isNotEmpty && descController.text.isNotEmpty) {
                final res = await ApiService.submitComplaint(
                  user.id,
                  catController.text,
                  subjController.text,
                  descController.text,
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(res['message'] ?? 'Ticket submitted successfully!')),
                );
                _loadTickets();
              }
            },
            child: const Text('Submit Ticket'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;

    if (status == 'resolved') {
      bg = Colors.green.shade100;
      text = Colors.green.shade800;
      label = 'RESOLVED';
    } else if (status == 'in_progress') {
      bg = Colors.amber.shade100;
      text = Colors.amber.shade900;
      label = 'IN PROGRESS';
    } else {
      bg = Colors.red.shade100;
      text = Colors.red.shade800;
      label = 'OPEN / SUBMITTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Support Tickets & History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadTickets(),
              child: _tickets.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.support_agent, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No support tickets submitted yet.',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showNewTicketDialog,
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Submit New Ticket'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _tickets.length + 1,
                      itemBuilder: (ctx, idx) {
                        if (idx == _tickets.length) {
                          return Column(
                            children: const [
                              SizedBox(height: 20),
                              Center(
                                child: Text(
                                  'Powered by Ramxonwebwork',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryIndigo,
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                            ],
                          );
                        }

                        final t = _tickets[idx];
                        final int id = t['id'] is int ? t['id'] : int.parse(t['id'].toString());
                        final String cat = t['category'] ?? 'General';
                        final String subj = t['subject'] ?? '';
                        final String desc = t['description'] ?? '';
                        final String status = t['status'] ?? 'open';
                        final String date = t['created_at'] ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '#TKT-${id.toString().padLeft(4, '0')}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                    _buildStatusBadge(status),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subj,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryIndigo.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    cat,
                                    style: const TextStyle(fontSize: 11, color: AppColors.primaryIndigo, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  desc,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Submitted: $date',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewTicketDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
        backgroundColor: AppColors.primaryIndigo,
      ),
    );
  }
}
