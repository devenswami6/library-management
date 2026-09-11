import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';
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
  String _chatFilter = 'all'; // all, unread

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
    setState(() {
      _filteredThreads = _threads.where((t) {
        final name = (t['student_name'] ?? '').toString().toLowerCase();
        final phone = (t['student_phone'] ?? '').toString().toLowerCase();
        final desk = (t['seat_number'] ?? '').toString().toLowerCase();
        final unread = Convert.toInt(t['unread_count']);

        final matchesSearch = query.isEmpty || name.contains(query) || phone.contains(query) || desk.contains(query);
        final matchesFilter = _chatFilter == 'all' || (_chatFilter == 'unread' && unread > 0);

        return matchesSearch && matchesFilter;
      }).toList();
    });
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
      appBar: const CustomAppBar(title: 'Student Support Chats 💬'),
      body: Column(
        children: [
          // Header Search Bar & Filter Chips
          Container(
            color: isDark ? AppColors.darkCard : Colors.white,
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applySearch(),
                  decoration: InputDecoration(
                    hintText: 'Search student name or phone...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryIndigo),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All (${_threads.length})', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Unread 🔴 (${_threads.where((t) => Convert.toInt(t['unread_count']) > 0).length})', 'unread'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Thread List with Desk Number Badge next to Student Name!
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo))
                : _filteredThreads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.mark_chat_unread_outlined, size: 54, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No student conversations found.',
                              style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchThreads(),
                        color: AppColors.primaryIndigo,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filteredThreads.length,
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
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              color: isDark ? AppColors.darkCard : Colors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primaryIndigo.withOpacity(0.12),
                                  child: Text(
                                    studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppColors.primaryIndigo,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
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
                                          const SizedBox(width: 8),
                                          // Prominent Seat Desk Number Badge next to Student Name!
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.statusSuccessBg,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.statusSuccess.withOpacity(0.4)),
                                            ),
                                            child: Text(
                                              desk.isNotEmpty ? 'Desk $desk' : 'Desk N/A',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.statusSuccess,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (lastTime.isNotEmpty)
                                      Text(
                                        lastTime,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
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
                                trailing: unread > 0
                                    ? Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$unread',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _chatFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryIndigo,
      backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade200,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      onSelected: (val) {
        if (val) {
          setState(() => _chatFilter = value);
          _applySearch();
        }
      },
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
