import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

class AdminChatConversationScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final String seatDesk;
  final String studentPhone;

  const AdminChatConversationScreen({
    Key? key,
    required this.studentId,
    required this.studentName,
    this.seatDesk = '',
    this.studentPhone = '',
  }) : super(key: key);

  @override
  _AdminChatConversationScreenState createState() => _AdminChatConversationScreenState();
}

class _AdminChatConversationScreenState extends State<AdminChatConversationScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  List<dynamic> _messages = [];
  int _adminId = 1;
  Timer? _pollingTimer;

  final List<String> _quickReplies = [
    "Your seat desk is confirmed. 👍",
    "Monthly fee payment received, thank you! 💳",
    "Please check your library shift timing.",
    "Support ticket acknowledged. We will fix this shortly.",
  ];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isLoading = true);
    }

    final res = await ApiService.getAdminChatMessages(widget.studentId);
    if (mounted) {
      if (res['success'] == true) {
        final newMsgs = res['messages'] as List<dynamic>? ?? [];
        final adminId = (res['admin_id'] as int?) ?? 1;

        if (newMsgs.length != _messages.length || !silent) {
          setState(() {
            _messages = newMsgs;
            _adminId = adminId;
            _isLoading = false;
          });
          _scrollToBottom();
        }
      } else {
        if (!silent) setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = (quickText ?? _msgController.text).trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    if (quickText == null) _msgController.clear();

    final res = await ApiService.sendAdminChatMessage(widget.studentId, text);
    if (mounted) {
      setState(() => _isSending = false);
      if (res['success'] == true) {
        _fetchMessages(silent: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to send message')),
        );
      }
    }
  }

  String _formatTime(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.studentName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.seatDesk.isNotEmpty ? "Desk: ${widget.seatDesk} • " : ""}${widget.studentPhone}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Replies Chips Horizontal List
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _quickReplies.length,
              itemBuilder: (ctx, i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(_quickReplies[i], style: const TextStyle(fontSize: 12)),
                    backgroundColor: isDark ? AppColors.primaryIndigo.withOpacity(0.3) : Colors.blue.shade50,
                    onPressed: () => _sendMessage(_quickReplies[i]),
                  ),
                );
              },
            ),
          ),

          // Message List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'Start conversation with ${widget.studentName}',
                              style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final senderId = Convert.toInt(msg['sender_id']);
                          final isAdminSender = (senderId == _adminId);
                          final timeStr = _formatTime(msg['created_at'] ?? '');

                          return Align(
                            alignment: isAdminSender ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isAdminSender
                                    ? AppColors.primaryIndigo
                                    : (isDark ? Colors.grey.shade800 : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isAdminSender ? 16 : 2),
                                  bottomRight: Radius.circular(isAdminSender ? 2 : 16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: isAdminSender
                                    ? null
                                    : Border.all(
                                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                                      ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isAdminSender)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        widget.studentName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.amberAccent : AppColors.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    msg['message'] ?? '',
                                    style: TextStyle(
                                      color: isAdminSender
                                          ? Colors.white
                                          : (isDark ? Colors.white : Colors.black87),
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isAdminSender
                                            ? Colors.white70
                                            : (isDark ? Colors.white54 : Colors.grey.shade600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Message Input Field
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Type reply to ${widget.studentName}...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primaryIndigo,
                    radius: 22,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            onPressed: () => _sendMessage(),
                          ),
                  ),
                ],
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
