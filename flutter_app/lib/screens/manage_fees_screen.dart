import 'package:flutter/material.dart';
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

  List<dynamic> get _filteredPayments {
    if (_filter == 'all') return _allPayments;
    return _allPayments.where((p) => p['payment_status'] == _filter).toList();
  }

  void _openRecordPaymentModal(Map<String, dynamic> item) {
    final TextEditingController amountController =
        TextEditingController(text: item['fee_amount'].toString());
    String selectedMode = 'UPI';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Record Monthly Fee Payment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Student: ${item['student_name']}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Desk: ${item['seat_number']} (${item['shift_name']})',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // Amount Field
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

                  // Payment Mode Selector
                  const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['UPI', 'Cash', 'Bank Transfer', 'Card'].map((mode) {
                      final isSel = selectedMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: isSel,
                        selectedColor: AppColors.primaryIndigo,
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

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Record Payment & Send Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.seatAvailable,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final double amount = double.tryParse(amountController.text.trim()) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid amount')),
                          );
                          return;
                        }

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
    Color statusColor = AppColors.seatPending;
    String statusLabel = 'Pending';

    if (status == 'paid') {
      statusColor = AppColors.seatAvailable;
      statusLabel = 'Paid';
    } else if (status == 'overdue') {
      statusColor = AppColors.seatOccupied;
      statusLabel = 'Overdue';
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
                    statusLabel.toUpperCase(),
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
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Fee: ₹${(item['fee_amount'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status == 'paid'
                          ? 'Paid Date: ${item['paid_date'] ?? 'N/A'}'
                          : 'Due Date: ${item['due_date'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: status == 'overdue' ? Colors.red : Colors.grey.shade600,
                      ),
                    ),
                    if (item['receipt_no'] != null)
                      Text(
                        'Receipt: ${item['receipt_no']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryIndigo, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),

                if (status != 'paid')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_card, size: 16),
                    label: const Text('Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.seatAvailable,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openRecordPaymentModal(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
