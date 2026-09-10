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
                  const Divider(),
                  const SizedBox(height: 8),

                  Text('Student: ${item['student_name'] ?? 'N/A'} (Desk ${item['seat_number']})', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Shift: ${item['shift_name'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAdvance ? Colors.blue.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isAdvance ? Colors.blue.shade300 : Colors.amber.shade300),
                    ),
                    child: Text(
                      'Collection Cycle: ${item['month_year_label'] ?? item['month_year']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isAdvance ? Colors.blue.shade800 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Fee Amount (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['UPI', 'Cash', 'Bank Transfer', 'Card'].map((mode) {
                      final isSel = selectedMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: isSel,
                        selectedColor: Colors.indigo,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.black,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedMode = mode);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: Text(isAdvance ? 'Record Advance Payment' : 'Record Payment & Send Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                              backgroundColor: res['success'] == true ? Colors.green : Colors.red,
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
                child: Center(child: CircularProgressIndicator()),
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
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('Download 12-Month Statement (PDF)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                                  isPaid ? Icons.check_circle : Icons.error_outline,
                                  color: isPaid ? Colors.green : Colors.red,
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
                                        icon: const Icon(Icons.download, size: 12),
                                        label: const Text('Receipt'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: Colors.green.shade800,
                                          side: BorderSide(color: Colors.green.shade600),
                                          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
    final double totalCollected = (_stats?['total_collected'] as num?)?.toDouble() ?? 0.0;
    final int pendingCount = _stats?['pending_count'] ?? 0;
    final int overdueCount = _stats?['overdue_count'] ?? 0;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Fee Management Center'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadFeeData(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Stats Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      color: AppColors.primaryBlue,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Monthly Fee Collection Summary',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${totalCollected.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatSubItem(
                                  label: 'Pending',
                                  value: '$pendingCount',
                                  color: Colors.amberAccent,
                                ),
                                Container(width: 1, height: 25, color: Colors.white30),
                                _buildStatSubItem(
                                  label: 'Overdue',
                                  value: '$overdueCount',
                                  color: Colors.redAccent,
                                ),
                                Container(width: 1, height: 25, color: Colors.white30),
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
                    ),
                    const SizedBox(height: 16),

                    // Filter Chips
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
                    const SizedBox(height: 16),

                    // Fee List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fee Records (${_filteredPayments.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _loadFeeData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Fee List
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
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryIndigo,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) setState(() => _filter = value);
      },
    );
  }

  Widget _buildFeeCard(Map<String, dynamic> item) {
    final status = item['payment_status'] ?? 'pending';
    final bool isAdvance = item['is_advance'] == true;
    final String displayLabel = item['label'] ?? (status == 'paid' ? 'Paid' : status.toUpperCase());

    Color statusColor = AppColors.seatPending;
    if (status == 'paid') {
      statusColor = AppColors.seatAvailable;
    } else if (status == 'overdue') {
      statusColor = AppColors.seatOccupied;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
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
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    displayLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.chair, size: 16, color: Colors.indigo.shade400),
                const SizedBox(width: 4),
                Text(
                  'Desk ${item['seat_number']}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  item['shift_name'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Fee: ₹${(item['fee_amount'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Next Due: ${item['due_date'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: status == 'overdue' ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                      if (item['month_year_label'] != null)
                        Text(
                          'Cycle: ${item['month_year_label']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.primaryIndigo, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),

                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.history, size: 12),
                      label: const Text('History'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      onPressed: () => _openStudentHistoryModal(item),
                    ),
                    ElevatedButton.icon(
                      icon: Icon(isAdvance ? Icons.forward_5 : Icons.add_card, size: 12),
                      label: Text(isAdvance ? 'Advance' : 'Collect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAdvance ? Colors.blue.shade700 : AppColors.seatAvailable,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _openRecordPaymentModal(item),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
