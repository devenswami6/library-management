import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

class ManageFeesScreen extends StatefulWidget {
  const ManageFeesScreen({Key? key}) : super(key: key);

  @override
  _ManageFeesScreenState createState() => _ManageFeesScreenState();
}

class _ManageFeesScreenState extends State<ManageFeesScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _allPayments = [];
  String _filter = 'all'; // all, paid, pending, overdue

  @override
  void initState() {
    super.initState();
    _loadFeeData();
  }

  void _loadFeeData() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getAdminFeePayments();
    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _stats = res['stats'];
          _allPayments = res['payments'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to load fee data')),
        );
      }
    }
  }

  Future<void> _openPdfUrl(String url) async {
    try {
      const channel = MethodChannel('com.example.flutter_app/notifications');
      await channel.invokeMethod('launchUrl', {'url': url});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $url')),
        );
      }
    }
  }

  List<dynamic> get _filteredPayments {
    if (_filter == 'all') return _allPayments;
    return _allPayments.where((p) => (p['payment_status'] ?? '') == _filter).toList();
  }

  void _openRecordPaymentModal(Map<String, dynamic> item) {
    final double defaultAmount = (item['fee_amount'] as num?)?.toDouble() ?? 600.0;
    final TextEditingController amountController = TextEditingController(text: defaultAmount.toStringAsFixed(0));
    String selectedMode = 'UPI';
    final bool isAdvance = item['is_advance'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAdvance ? 'Record Advance Fee Collection' : 'Record Monthly Fee Collection',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Student: ${item['student_name']} • Desk ${item['seat_number']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Paid (₹)',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Select Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['UPI', 'Cash', 'Bank Transfer'].map((mode) {
                      final bool isSel = selectedMode == mode;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(mode),
                          selected: isSel,
                          selectedColor: AppColors.primaryIndigo,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : Colors.black87,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedMode = mode);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long, color: Colors.white),
                      label: Text(
                        isAdvance ? 'Record Advance Payment' : 'Record Payment & Send Receipt',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusSuccess,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final double amount = double.tryParse(amountController.text.trim()) ?? 0;
                        if (amount <= 0) return;

                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);

                        final res = await ApiService.recordFeePayment(
                          allocationId: item['allocation_id'],
                          userId: item['user_id'],
                          amount: amount,
                          paymentMode: selectedMode,
                          monthYear: item['month_year'],
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Payment recorded!'),
                              backgroundColor: res['success'] == true ? AppColors.statusSuccess : Colors.red,
                            ),
                          );
                          _loadFeeData();
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openStudentHistoryModal(Map<String, dynamic> item) {
    final String statementPdfUrl = '${ApiConfig.baseUrl}/receipt_statement.php?user_id=${item['user_id']}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiService.getStudentFeeHistory(item['user_id']),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo)),
              );
            }
            final res = snapshot.data ?? {};
            final List history = res['fee_history'] ?? [];
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '12-Month History: ${item['student_name']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
                      label: const Text(
                        'Download 12-Month Statement (PDF)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _openPdfUrl(statementPdfUrl),
                    ),
                  ),
                  const Divider(height: 20),

                  history.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('No payment history found.')),
                        )
                      : Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: history.length,
                            itemBuilder: (c, i) {
                              final h = history[i];
                              final bool isPaid = h['payment_status'] == 'paid';
                              final String rNo = h['receipt_no'] ?? '';
                              final String receiptPdfUrl = '${ApiConfig.baseUrl}/receipt.php?receipt_no=${Uri.encodeComponent(rNo)}';

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  isPaid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                  color: isPaid ? AppColors.statusSuccess : AppColors.statusDanger,
                                ),
                                title: Text(
                                  'Cycle: ${h['month_year']} • ₹${(h['amount'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                subtitle: Text(
                                  isPaid
                                      ? 'Paid: ${h['paid_date']} (${h['payment_mode'] ?? 'Cash'}) • Receipt: ${h['receipt_no'] ?? 'N/A'}'
                                      : 'Due Date: ${h['due_date']}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: isPaid && rNo.isNotEmpty
                                    ? OutlinedButton.icon(
                                        icon: const Icon(Icons.download_rounded, size: 14),
                                        label: const Text('Receipt'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: AppColors.statusSuccess,
                                          side: const BorderSide(color: AppColors.statusSuccess),
                                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () => _openPdfUrl(receiptPdfUrl),
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double totalCollected = (_stats?['total_collected'] as num?)?.toDouble() ?? 0.0;
    final int pendingCount = _stats?['pending_count'] ?? 0;
    final int overdueCount = _stats?['overdue_count'] ?? 0;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Fee Management Center'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo))
          : RefreshIndicator(
              onRefresh: () async => _loadFeeData(),
              color: AppColors.primaryIndigo,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Stats Card - Concept B Gradient Banner
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
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Monthly Fee Collection Summary',
                            style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${totalCollected.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatSubItem(
                                label: 'Pending',
                                value: '$pendingCount',
                                color: const Color(0xFFFDE68A),
                              ),
                              Container(width: 1, height: 25, color: Colors.white.withOpacity(0.3)),
                              _buildStatSubItem(
                                label: 'Overdue',
                                value: '$overdueCount',
                                color: const Color(0xFFFECDD3),
                              ),
                              Container(width: 1, height: 25, color: Colors.white.withOpacity(0.3)),
                              _buildStatSubItem(
                                label: 'Total Active',
                                value: '${_stats?['total_active'] ?? 0}',
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Filter Chips Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All Students', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Paid 🟢', 'paid'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pending 🟡', 'pending'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Overdue 🔴', 'overdue'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Fee List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fee Records (${_filteredPayments.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 22, color: AppColors.primaryIndigo),
                          onPressed: _loadFeeData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Fee List Cards
                    _filteredPayments.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No fee records found for selected filter.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredPayments.length,
                            itemBuilder: (ctx, idx) {
                              final item = _filteredPayments[idx];
                              return _buildFeeCard(item);
                            },
                          ),

                    const SizedBox(height: 20),
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
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatSubItem({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 11)),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
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
        if (val) setState(() => _filter = value);
      },
    );
  }

  Widget _buildFeeCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = item['payment_status'] ?? 'pending';
    final bool isAdvance = item['is_advance'] == true;
    final String displayLabel = item['label'] ?? (status == 'paid' ? 'Paid' : status.toUpperCase());

    Color statusBg = AppColors.statusWarningBg;
    Color statusTextColor = const Color(0xFFB45309);
    if (status == 'paid') {
      statusBg = AppColors.statusSuccessBg;
      statusTextColor = AppColors.statusSuccess;
    } else if (status == 'overdue') {
      statusBg = AppColors.statusDangerBg;
      statusTextColor = AppColors.statusDanger;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item['student_name'] ?? 'Student',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      color: statusTextColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_seat_rounded, size: 16, color: AppColors.primaryIndigo),
                const SizedBox(width: 4),
                Text(
                  'Desk ${item['seat_number']}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Shift: ${item['shift_name']} (${item['start_time']} - ${item['end_time']})',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'Cycle: ${item['month_year']} • ₹${(double.tryParse((item['fee_amount'] ?? 600).toString()) ?? 600).toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryIndigo),
                ),
                const Spacer(),
                if (item['due_date'] != null)
                  Text(
                    'Due: ${item['due_date']}',
                    style: TextStyle(fontSize: 11, color: status == 'overdue' ? AppColors.statusDanger : Colors.grey),
                  ),
              ],
            ),
            const Divider(height: 20),

            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: const Text('12-Mo Statement'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryIndigo,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => _openStudentHistoryModal(item),
                ),
                if (status != 'paid')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payments_rounded, size: 16, color: Colors.white),
                    label: Text(
                      isAdvance ? 'Record Advance' : 'Record Fee',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusSuccess,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openRecordPaymentModal(item),
                  )
                else if (item['receipt_no'] != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Receipt PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusSuccess,
                      side: const BorderSide(color: AppColors.statusSuccess),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final url = '${ApiConfig.baseUrl}/receipt.php?receipt_no=${Uri.encodeComponent(item['receipt_no'])}';
                      _openPdfUrl(url);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
