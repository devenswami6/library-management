import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

class ManageComplaintsScreen extends StatefulWidget {
  const ManageComplaintsScreen({Key? key}) : super(key: key);

  @override
  _ManageComplaintsScreenState createState() => _ManageComplaintsScreenState();
}

class _ManageComplaintsScreenState extends State<ManageComplaintsScreen> {
  bool _isLoading = true;
  List<dynamic> _allTickets = [];
  String _filter = 'all'; // 'all', 'open', 'in_progress', 'resolved'

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() async {
    final res = await ApiService.getAllComplaints();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _allTickets = res['complaints'] ?? [];
        }
      });
    }
  }

  void _updateStatus(int complaintId, String newStatus) async {
    final res = await ApiService.updateComplaintStatus(complaintId, newStatus);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message'] ?? 'Status updated')),
    );
    _loadTickets();
  }

  List<dynamic> get _filteredTickets {
    if (_filter == 'all') return _allTickets;
    return _allTickets.where((t) => t['status'] == _filter).toList();
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
      label = 'OPEN';
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
    final tickets = _filteredTickets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Support Tickets Desk'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Header Tabs
            Container(
              color: AppColors.primaryIndigo.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All (${_allTickets.length})'),
                      selected: _filter == 'all',
                      onSelected: (val) {
                        if (val) setState(() => _filter = 'all');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Open (${_allTickets.where((t) => t['status'] == 'open').length})'),
                      selected: _filter == 'open',
                      selectedColor: Colors.red.shade400,
                      labelStyle: TextStyle(color: _filter == 'open' ? Colors.white : Colors.black),
                      onSelected: (val) {
                        if (val) setState(() => _filter = 'open');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('In Progress (${_allTickets.where((t) => t['status'] == 'in_progress').length})'),
                      selected: _filter == 'in_progress',
                      selectedColor: Colors.amber.shade700,
                      labelStyle: TextStyle(color: _filter == 'in_progress' ? Colors.white : Colors.black),
                      onSelected: (val) {
                        if (val) setState(() => _filter = 'in_progress');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Resolved (${_allTickets.where((t) => t['status'] == 'resolved').length})'),
                      selected: _filter == 'resolved',
                      selectedColor: Colors.green.shade600,
                      labelStyle: TextStyle(color: _filter == 'resolved' ? Colors.white : Colors.black),
                      onSelected: (val) {
                        if (val) setState(() => _filter = 'resolved');
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Tickets List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async => _loadTickets(),
                      child: tickets.isEmpty
                          ? const Center(child: Text('No support tickets found for this filter.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: tickets.length + 1,
                              itemBuilder: (ctx, idx) {
                                if (idx == tickets.length) {
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

                                final t = tickets[idx];
                                final int id = t['id'] is int ? t['id'] : int.parse(t['id'].toString());
                                final String name = t['student_name'] ?? 'Student';
                                final String phone = t['student_phone'] ?? '';
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
                                              '#TKT-${id.toString().padLeft(4, '0')} • $name',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            _buildStatusBadge(status),
                                          ],
                                        ),
                                        if (phone.isNotEmpty)
                                          Text('Phone: $phone', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(height: 8),
                                        Text(subj, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text(desc, style: const TextStyle(fontSize: 13)),
                                        const SizedBox(height: 10),
                                        Text('Submitted: $date', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        const Divider(),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            const Text('Mark Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 4),
                                            OutlinedButton(
                                              onPressed: status == 'open' ? null : () => _updateStatus(id, 'open'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                              child: const Text('Open', style: TextStyle(fontSize: 11)),
                                            ),
                                            const SizedBox(width: 4),
                                            OutlinedButton(
                                              onPressed: status == 'in_progress' ? null : () => _updateStatus(id, 'in_progress'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.amber.shade900,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                              child: const Text('In Progress', style: TextStyle(fontSize: 11)),
                                            ),
                                            const SizedBox(width: 4),
                                            ElevatedButton(
                                              onPressed: status == 'resolved' ? null : () => _updateStatus(id, 'resolved'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              ),
                                              child: const Text('Resolved', style: TextStyle(fontSize: 11)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
