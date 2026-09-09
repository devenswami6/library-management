import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/seat_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_provider.dart';
import '../services/api_service.dart';

class ManageSeatsScreen extends StatefulWidget {
  const ManageSeatsScreen({Key? key}) : super(key: key);

  @override
  _ManageSeatsScreenState createState() => _ManageSeatsScreenState();
}

class _ManageSeatsScreenState extends State<ManageSeatsScreen> {
  final _rowController = TextEditingController(text: 'E');
  final _startController = TextEditingController(text: '1');
  final _endController = TextEditingController(text: '10');
  int _digitsFormat = 2; // 2-digit e.g. 01, 02
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSeats();
  }

  void _loadSeats() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    Provider.of<SeatProvider>(context, listen: false).fetchSeatMatrix(user?.id ?? 0);
  }

  void _handleBulkCreate() async {
    final rowLabel = _rowController.text.trim().toUpperCase();
    final startNum = int.tryParse(_startController.text.trim()) ?? 1;
    final endNum = int.tryParse(_endController.text.trim()) ?? 10;

    if (rowLabel.isEmpty || startNum <= 0 || endNum < startNum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid row letter and range numbers.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final res = await ApiService.bulkCreateSeats(rowLabel, startNum, endNum, formatDigits: _digitsFormat);
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message'] ?? 'Created seats')),
    );

    _loadSeats();
  }

  void _handleDeleteSeat(SeatModel seat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Desk ${seat.seatNumber}?'),
        content: const Text('Are you sure you want to delete this seat desk? Any active student allocation will be freed.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.deleteSeat(seat.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Deleted')),
      );
      _loadSeats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final seatProvider = Provider.of<SeatProvider>(context);
    final allSeatList = <SeatModel>[];
    seatProvider.seatRows.values.forEach((list) => allSeatList.addAll(list));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Study Desks & Range'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bulk Range Creator Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.seatAvailable),
                          SizedBox(width: 8),
                          Text(
                            '1-Click Range Seat Creator',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Generate 10 to 50 desks instantly (e.g. Row E: 01 to 10)',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _rowController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Row Letter',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _startController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Start No.',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _endController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'End No.',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<int>(
                        value: _digitsFormat,
                        decoration: const InputDecoration(labelText: 'Number Format', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('2-Digit (01, 02 ... 10)')),
                          DropdownMenuItem(value: 1, child: Text('1-Digit (1, 2 ... 10)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _digitsFormat = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _handleBulkCreate,
                        icon: const Icon(Icons.flash_on),
                        label: Text('⚡ GENERATE RANGE (${_rowController.text.toUpperCase()}-${_startController.text.padLeft(_digitsFormat, '0')} to ${_rowController.text.toUpperCase()}-${_endController.text.padLeft(_digitsFormat, '0')})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.seatAvailable,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Existing Study Desks (${allSeatList.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              if (seatProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (allSeatList.isEmpty)
                const Center(child: Text('No seats created yet.'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: allSeatList.length,
                  itemBuilder: (context, index) {
                    final seat = allSeatList[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryIndigo.withOpacity(0.15),
                          child: Text(
                            seat.rowLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryIndigo),
                          ),
                        ),
                        title: Text(
                          'Desk ${seat.seatNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Row Label: ${seat.rowLabel}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          onPressed: () => _handleDeleteSeat(seat),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
