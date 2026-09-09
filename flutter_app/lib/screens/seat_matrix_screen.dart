import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/seat_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_provider.dart';
import '../services/api_service.dart';
import '../widgets/seat_grid_view.dart';

class SeatMatrixScreen extends StatefulWidget {
  const SeatMatrixScreen({Key? key}) : super(key: key);

  @override
  _SeatMatrixScreenState createState() => _SeatMatrixScreenState();
}

class _SeatMatrixScreenState extends State<SeatMatrixScreen> {
  List<dynamic> _shifts = [];
  bool _isLoadingShifts = true;

  @override
  void initState() {
    super.initState();
    _loadShiftsAndMatrix();
  }

  void _loadShiftsAndMatrix() async {
    final shifts = await ApiService.getShifts();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

    setState(() {
      _shifts = shifts;
      _isLoadingShifts = false;
    });

    if (shifts.isNotEmpty) {
      final seatProvider = Provider.of<SeatProvider>(context, listen: false);
      seatProvider.fetchSeatMatrix(user?.id ?? 0);
    }
  }

  void _showSeatDetailsDialog(SeatModel seat, bool isAdmin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.chair, color: AppColors.primaryIndigo),
            const SizedBox(width: 8),
            Text('Seat Desk ${seat.seatNumber}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Row Label: ${seat.rowLabel}'),
            const SizedBox(height: 6),
            Text('Status: ${seat.status.toUpperCase()}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: seat.status == 'booked'
                        ? AppColors.seatOccupied
                        : AppColors.seatAvailable)),
            if (isAdmin && seat.studentName != null) ...[
              const Divider(),
              Text('Student Name: ${seat.studentName}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (seat.studentPhone != null) Text('Phone: ${seat.studentPhone}'),
            ] else if (!isAdmin) ...[
              const SizedBox(height: 8),
              const Text(
                'Note: Student personal details are hidden for privacy. Only Admin can allot seats.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final seatProvider = Provider.of<SeatProvider>(context);
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Seat Matrix Grid'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Shift Selector Tab Header
            if (!_isLoadingShifts && _shifts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: AppColors.primaryIndigo.withOpacity(0.08),
                child: Row(
                  children: [
                    const Text('Select Shift: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _shifts.map((shift) {
                            final isSelected =
                                seatProvider.selectedShiftId == shift['id'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(
                                    '${shift['name']} (${shift['start_time']} - ${shift['end_time']})'),
                                selected: isSelected,
                                selectedColor: AppColors.primaryIndigo,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    seatProvider.changeShift(
                                        shift['id'], user?.id ?? 0);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Seat Matrix Body
            Expanded(
              child: seatProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async =>
                          seatProvider.fetchSeatMatrix(user?.id ?? 0),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: SeatGridView(
                          seatRows: seatProvider.seatRows,
                          onSeatTap: (seat) =>
                              _showSeatDetailsDialog(seat, isAdmin),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
