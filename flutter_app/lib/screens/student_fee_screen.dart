import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

class StudentFeeScreen extends StatefulWidget {
  const StudentFeeScreen({Key? key}) : super(key: key);

  @override
  _StudentFeeScreenState createState() => _StudentFeeScreenState();
}

class _StudentFeeScreenState extends State<StudentFeeScreen> {
  bool _isLoading = true;
  List<dynamic> _feeHistory = [];

  @override
  void initState() {
    super.initState();
    _loadFeeHistory();
  }

  void _loadFeeHistory() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final res = await ApiService.getStudentFeeHistory(user.id);
    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _feeHistory = res['fee_history'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPdfUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final String statementPdfUrl = currentUser != null
        ? '${ApiConfig.baseUrl}/receipt_statement.php?user_id=${currentUser.id}'
        : '${ApiConfig.baseUrl}/receipt_statement.php';

    return Scaffold(
      appBar: const CustomAppBar(title: 'My Fee Details & Receipts'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _loadFeeHistory(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Title & PDF Statement Download Button
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: AppColors.primaryIndigo.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fee Receipts & Statement',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Download 12-Month Statement or Receipts',
                                    style: TextStyle(fontSize: 11, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf, size: 14),
                              label: const Text('12-Mo PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _openPdfUrl(statementPdfUrl),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Receipt History (Last 12 Months)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    _feeHistory.isEmpty
                        ? Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'No past payment receipts found.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _feeHistory.length,
                            itemBuilder: (ctx, idx) {
                              final item = _feeHistory[idx];
                              final status = item['payment_status'] ?? 'pending';
                              final bool isPaid = status == 'paid';

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isPaid ? AppColors.seatAvailable : AppColors.seatPending).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isPaid ? Icons.receipt_long : Icons.pending_actions,
                                      color: isPaid ? AppColors.seatAvailable : AppColors.seatPending,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        'Month: ${item['month_year']} • ₹${(item['amount'] as num).toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      if ((item['month_year'] ?? '').toString().compareTo("${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}") > 0) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.blue, width: 0.8),
                                          ),
                                          child: const Text(
                                            'ADVANCE',
                                            style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      if (item['due_date'] != null)
                                        Text(
                                          'Cycle Due Date: ${item['due_date']}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                                        ),
                                      if (isPaid) ...[
                                        Text('Paid On: ${item['paid_date'] ?? 'N/A'} via ${item['payment_mode'] ?? 'Cash'}'),
                                        Text(
                                          'Receipt No: ${item['receipt_no'] ?? 'N/A'}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryIndigo),
                                        ),
                                      ] else ...[
                                        Text(
                                          'Status: ${status.toUpperCase()}',
                                          style: TextStyle(color: status == 'overdue' ? Colors.red : Colors.orange, fontWeight: FontWeight.bold),
                                        ),
                                      ]
                                    ],
                                  ),
                                  trailing: isPaid && (item['receipt_no'] ?? '').toString().isNotEmpty
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
                                          onPressed: () {
                                            final rNo = item['receipt_no'] ?? '';
                                            _openPdfUrl('${ApiConfig.baseUrl}/receipt.php?receipt_no=${Uri.encodeComponent(rNo)}');
                                          },
                                        )
                                      : const Icon(Icons.error_outline, color: AppColors.seatPending),
                                ),
                              );
                            },
                          ),

                    const SizedBox(height: 24),
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
}
