import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/seat_model.dart';
import '../providers/auth_provider.dart';
import '../providers/seat_provider.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.event_seat_rounded, color: AppColors.primaryIndigo),
            const SizedBox(width: 8),
            Text('Desk ${seat.seatNumber} Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Row Label: ${seat.rowLabel}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Status: ', style: TextStyle(fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: seat.status == 'booked' ? AppColors.statusDangerBg : AppColors.statusSuccessBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    seat.status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: seat.status == 'booked' ? AppColors.statusDanger : AppColors.statusSuccess,
                    ),
                  ),
                ),
              ],
            ),
            if (isAdmin && seat.studentName != null) ...[
              const Divider(height: 20),
              Text('Student Name: ${seat.studentName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (seat.studentPhone != null) Text('Phone: ${seat.studentPhone}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ] else if (!isAdmin) ...[
              const SizedBox(height: 8),
              const Text(
                'Note: Student details are kept private for security.',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Visual Seat Matrix Grid'),
      body: SafeArea(
        child: Column(
          children: [
            // Shift Selector Card Header (Matching Screen 6 Dropdown)
            if (!_isLoadingShifts && _shifts.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                color: isDark ? AppColors.darkCard : Colors.white,
                child: Row(
                  children: [
                    const Text(
                      'Select Shift: ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _shifts.map((shift) {
                            final isSelected = seatProvider.selectedShiftId == shift['id'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text('${shift['name']} (${shift['start_time']} - ${shift['end_time']})'),
                                selected: isSelected,
                                selectedColor: AppColors.primaryIndigo,
                                backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade200,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    seatProvider.changeShift(shift['id'], user?.id ?? 0);
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

            // Seat Grid Body (Matching Screen 6)
            Expanded(
              child: seatProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo))
                  : RefreshIndicator(
                      onRefresh: () async => seatProvider.fetchSeatMatrix(user?.id ?? 0),
                      color: AppColors.primaryIndigo,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: SeatGridView(
                          seatRows: seatProvider.seatRows,
                          onSeatTap: (seat) => _showSeatDetailsDialog(seat, isAdmin),
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
