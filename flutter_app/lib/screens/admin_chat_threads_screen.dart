import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import 'admin_chat_conversation_screen.dart';

class AdminChatThreadsScreen extends StatefulWidget {
  const AdminChatThreadsScreen({Key? key}) : super(key: key);

  @override
  _AdminChatThreadsScreenState createState() => _AdminChatThreadsScreenState();
}

class _AdminChatThreadsScreenState extends State<AdminChatThreadsScreen> {
  bool _isLoading = true;
  List<dynamic> _threads = [];
  List<dynamic> _filteredThreads = [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchThreads();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchThreads(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchThreads({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    final res = await ApiService.getAdminChatThreads();
    if (mounted) {
      if (res['success'] == true) {
        final list = res['threads'] as List<dynamic>? ?? [];
        setState(() {
          _threads = list;
          _applySearch();
          _isLoading = false;
        });
      } else {
        if (!silent) setState(() => _isLoading = false);
      }
    }
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredThreads = List.from(_threads);
    } else {
      _filteredThreads = _threads.where((t) {
        final name = (t['student_name'] ?? '').toString().toLowerCase();
        final phone = (t['student_phone'] ?? '').toString().toLowerCase();
        final desk = (t['seat_number'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query) || desk.contains(query);
      }).toList();
    }
  }

  String _formatTime(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return DateFormat('hh:mm a').format(dt);
      }
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Support Chats 💬'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchThreads(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _applySearch()),
              decoration: InputDecoration(
                hintText: 'Search student name, phone or seat desk...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredThreads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mark_chat_unread_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No student conversations found.',
                              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchThreads(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: _filteredThreads.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _filteredThreads[index];
                            final studentId = Convert.toInt(item['student_id']);
                            final studentName = item['student_name'] ?? 'Student';
                            final phone = item['student_phone'] ?? '';
                            final desk = item['seat_number'] ?? '';
                            final lastMsg = item['last_message'] ?? 'Tap to start direct conversation';
                            final lastTime = _formatTime(item['last_message_time'] ?? '');
                            final unread = Convert.toInt(item['unread_count']);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryIndigo.withOpacity(0.15),
                                  child: Text(
                                    studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryIndigo,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        studentName,
                                        style: TextStyle(
                                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (desk.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.seatAvailable.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Desk: $desk',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.seatAvailable,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMsg,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: unread > 0
                                              ? (isDark ? Colors.white : Colors.black87)
                                              : Colors.grey,
                                          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (lastTime.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        lastTime,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: unread > 0
                                    ? CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.redAccent,
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right, color: Colors.grey),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (ctx) => AdminChatConversationScreen(
                                        studentId: studentId,
                                        studentName: studentName,
                                        seatDesk: desk,
                                        studentPhone: phone,
                                      ),
                                    ),
                                  );
                                  _fetchThreads(silent: true);
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class Convert {
  static int toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? 0;
  }
}
