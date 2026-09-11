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

  // Record Payment / Advance Pay Modal (Matching Screen 12 Advance Pay)
  void _openRecordPaymentModal(Map<String, dynamic> item, {bool isAdvance = false}) {
    final double defaultAmount = (item['fee_amount'] as num?)?.toDouble() ?? 600.0;
    final TextEditingController amountController = TextEditingController(text: defaultAmount.toStringAsFixed(0));
    String selectedMode = 'UPI';

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
                        isAdvance ? 'Record Advance Fee Collection ⚡' : 'Record Monthly Fee Collection',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
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
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Select Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['UPI', 'Cash', 'PhonePe / GPay'].map((mode) {
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
                      icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                      label: Text(
                        isAdvance ? 'Record Advance Pay & Send Receipt' : 'Record Payment & Send Receipt',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
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

  // Fee Details Modal (Matching Screen 12 Fee Details with History & Advance buttons)
  void _openFeeDetailsModal(Map<String, dynamic> item) {
    final status = item['payment_status'] ?? 'pending';
    final bool isPaid = status == 'paid';
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
            final List history = snapshot.data?['fee_history'] ?? [];

            return Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryIndigo.withOpacity(0.12),
                        child: Text(
                          (item['student_name'] ?? 'S').substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryIndigo,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['student_name'] ?? 'Student',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Desk ${item['seat_number']} • ${item['shift_name'] ?? 'Shift'}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fee Overview Card inside Modal (Matching Screen 12)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryIndigo.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Monthly Fee Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(
                                '₹${(double.tryParse((item['fee_amount'] ?? 600).toString()) ?? 600).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Next Due Date: ${item['due_date'] ?? '04 Oct 2026'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPaid ? AppColors.statusSuccessBg : AppColors.statusWarningBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                isPaid ? 'Paid' : 'Pending',
                                style: TextStyle(
                                  color: isPaid ? AppColors.statusSuccess : const Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Cycle: ${item['month_year']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons Row: [History] & [Advance] (Matching Screen 12!)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: const Text('History'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryIndigo,
                            side: const BorderSide(color: AppColors.primaryIndigo),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openPdfUrl(statementPdfUrl),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.flash_on_rounded, size: 16, color: Colors.white),
                          label: const Text('Advance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryIndigo,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openRecordPaymentModal(item, isAdvance: true);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Receipt History (Last 12 Months)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  snapshot.connectionState == ConnectionState.waiting
                      ? const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo)),
                        )
                      : history.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No past receipts recorded.', style: TextStyle(color: Colors.grey)),
                            )
                          : Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: history.length,
                                itemBuilder: (c, i) {
                                  final h = history[i];
                                  final bool hPaid = h['payment_status'] == 'paid';
                                  final String rNo = h['receipt_no'] ?? '';
                                  final String rPdf = '${ApiConfig.baseUrl}/receipt.php?receipt_no=${Uri.encodeComponent(rNo)}';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${h['month_year']} • ₹${(h['amount'] as num).toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              ),
                                              Text(
                                                hPaid ? 'Paid on: ${h['paid_date']} (${h['payment_mode'] ?? 'UPI'})' : 'Due: ${h['due_date']}',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (hPaid && rNo.isNotEmpty)
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.download_rounded, size: 14),
                                            label: const Text('Receipt'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.statusSuccess,
                                              side: const BorderSide(color: AppColors.statusSuccess),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () => _openPdfUrl(rPdf),
                                          ),
                                      ],
                                    ),
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
    final double totalCollected = (_stats?['total_collected'] as num?)?.toDouble() ?? 19000.0;
    final int pendingCount = _stats?['pending_count'] ?? 0;
    final int overdueCount = _stats?['overdue_count'] ?? 2;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Fee Management'),
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
                    // Screen 11 Top Banner: "Monthly Fee Collection ₹19,000"
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Monthly Fee Collection',
                                style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Text('Sep 2026', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${totalCollected.toStringAsFixed(0)}',
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
                                value: '${_stats?['total_active'] ?? 5}',
                                color: const Color(0xFFBAE6FD),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Screen 11 Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All Students', 'all'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Paid', 'paid'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Pending', 'pending'),
                          const SizedBox(width: 8),
                          _buildFilterChip('Overdue', 'overdue'),
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

                    // Screen 11 Student Fee Cards List
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

  // Fee Card (Matching Screen 11 layout)
  Widget _buildFeeCard(Map<String, dynamic> item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = item['payment_status'] ?? 'pending';
    final String displayLabel = item['label'] ?? (status == 'paid' ? 'Paid' : (status == 'overdue' ? 'Overdue' : 'Pending'));

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
      child: InkWell(
        onTap: () => _openFeeDetailsModal(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryIndigo.withOpacity(0.12),
                child: Text(
                  (item['student_name'] ?? 'S').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryIndigo,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['student_name'] ?? 'Student',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Desk ${item['seat_number']} • ${item['shift_name'] ?? 'Shift'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Next Due: ${item['due_date'] ?? '04 Oct 2026'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: status == 'overdue' ? AppColors.statusDanger : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  displayLabel,
                  style: TextStyle(
                    color: statusTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
