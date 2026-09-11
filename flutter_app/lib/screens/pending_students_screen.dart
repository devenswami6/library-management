import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

class PendingStudentsScreen extends StatefulWidget {
  const PendingStudentsScreen({Key? key}) : super(key: key);

  @override
  _PendingStudentsScreenState createState() => _PendingStudentsScreenState();
}

class _PendingStudentsScreenState extends State<PendingStudentsScreen> {
  bool _isLoading = true;
  List<dynamic> _pendingStudents = [];
  List<dynamic> _availableSeats = [];
  List<dynamic> _shifts = [];
  List<dynamic> _activeAllocations = [];
  String _selectedShiftFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPendingList();
  }

  void _loadPendingList() async {
    try {
      final data = await ApiService.getPendingStudents();
      if (mounted) {
        setState(() {
          _pendingStudents = data['pending_students'] ?? [];
          _availableSeats = data['available_seats'] ?? [];
          _shifts = data['shifts'] ?? [];
          _activeAllocations = data['active_allocations'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredStudents {
    if (_selectedShiftFilter == 'all') return _pendingStudents;
    return _pendingStudents.where((s) {
      final String shift = (s['shift_name'] ?? '').toString().toLowerCase();
      if (_selectedShiftFilter == 'morning') return shift.contains('morning');
      if (_selectedShiftFilter == 'evening') return shift.contains('evening');
      if (_selectedShiftFilter == 'full') return shift.contains('full');
      return true;
    }).toList();
  }

  // Seat Allocation Modal (Matching Screen 5: Student Seat Allocation)
  void _showAllotSeatDialog(Map<String, dynamic> student) {
    int selectedShiftId = student['shift_id'] ?? (_shifts.isNotEmpty ? _shifts.first['id'] : 1);

    Set<int> getOccupiedSeatIds(int shiftId) {
      final Set<int> set = {};
      for (var alloc in _activeAllocations) {
        if (alloc['shift_id'] == shiftId && alloc['user_id'] != student['id']) {
          set.add(alloc['seat_id'] is int ? alloc['seat_id'] : int.parse(alloc['seat_id'].toString()));
        }
      }
      return set;
    }

    Set<int> occupiedSeatIds = getOccupiedSeatIds(selectedShiftId);
    List<dynamic> freeSeats = _availableSeats.where((s) => !occupiedSeatIds.contains(s['id'])).toList();
    int selectedSeatId = freeSeats.isNotEmpty ? freeSeats.first['id'] : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          occupiedSeatIds = getOccupiedSeatIds(selectedShiftId);
          freeSeats = _availableSeats.where((s) => !occupiedSeatIds.contains(s['id'])).toList();

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
                // Header (Matching Screen 5 Header Card)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryIndigo.withOpacity(0.12),
                      child: Text(
                        (student['name'] ?? 'S').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryIndigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student['name'] ?? 'Student Name',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text('Email: ${student['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('Phone: ${student['phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Requested Shift Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryIndigo.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primaryIndigo),
                      const SizedBox(width: 8),
                      Text(
                        'Requested Shift: ${student['shift_name'] ?? "Morning"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryIndigo),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Allocate Seat & Shift:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),

                // Shift Dropdown
                DropdownButtonFormField<int>(
                  value: selectedShiftId,
                  decoration: const InputDecoration(labelText: 'Select Shift Timing', border: OutlineInputBorder()),
                  items: _shifts.map<DropdownMenuItem<int>>((s) {
                    final occCount = _activeAllocations.where((a) => a['shift_id'] == s['id']).length;
                    final isFull = occCount >= _availableSeats.length;
                    return DropdownMenuItem<int>(
                      value: s['id'],
                      child: Text(
                        '${s['name']} (${s['start_time']}-${s['end_time']}) ${isFull ? '[FULL]' : '($occCount/${_availableSeats.length} occupied)'}',
                        style: TextStyle(color: isFull ? Colors.red : null, fontWeight: isFull ? FontWeight.bold : null),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedShiftId = val;
                        final newOccupied = getOccupiedSeatIds(selectedShiftId);
                        final newFree = _availableSeats.where((s) => !newOccupied.contains(s['id'])).toList();
                        selectedSeatId = newFree.isNotEmpty ? newFree.first['id'] : 0;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                if (freeSeats.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ALL DESKS IN THIS SHIFT ARE FULL! Please select another shift timing.',
                            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<int>(
                    value: selectedSeatId == 0 && freeSeats.isNotEmpty ? freeSeats.first['id'] : selectedSeatId,
                    decoration: const InputDecoration(labelText: 'Select Available Desk Seat', border: OutlineInputBorder()),
                    items: _availableSeats.map<DropdownMenuItem<int>>((seat) {
                      final isOccupied = occupiedSeatIds.contains(seat['id']);
                      return DropdownMenuItem<int>(
                        value: seat['id'],
                        enabled: !isOccupied,
                        child: Text(
                          'Desk ${seat['seat_number']} (Row ${seat['row_label']}) ${isOccupied ? "- [OCCUPIED IN SHIFT]" : "- [AVAILABLE]"}',
                          style: TextStyle(
                            color: isOccupied ? Colors.grey : AppColors.statusSuccess,
                            fontWeight: isOccupied ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && !occupiedSeatIds.contains(val)) {
                        setDialogState(() => selectedSeatId = val);
                      }
                    },
                  ),

                const SizedBox(height: 20),

                // Modal Buttons: [Cancel] & [Allocate Seat] (Matching Screen 5)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (selectedSeatId == 0 || freeSeats.isEmpty)
                            ? null
                            : () async {
                                final res = await ApiService.allotSeat(student['id'], selectedSeatId, selectedShiftId);
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['message'] ?? 'Seat allotted successfully!'),
                                    backgroundColor: AppColors.statusSuccess,
                                  ),
                                );
                                _loadPendingList();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryIndigo,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Allocate Seat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int mCount = _pendingStudents.where((s) => (s['shift_name'] ?? '').toString().toLowerCase().contains('morning')).length;
    final int eCount = _pendingStudents.where((s) => (s['shift_name'] ?? '').toString().toLowerCase().contains('evening')).length;
    final int fCount = _pendingStudents.where((s) => (s['shift_name'] ?? '').toString().toLowerCase().contains('full')).length;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Pending Allotments'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo))
          : Column(
              children: [
                // Top Filter Pills Container (Matching Screen 4)
                Container(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All (${_pendingStudents.length})', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Morning ($mCount)', 'morning'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Evening ($eCount)', 'evening'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Full Day ($fCount)', 'full'),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _filteredStudents.isEmpty
                      ? const Center(
                          child: Text('No pending allotment requests found.', style: TextStyle(color: Colors.grey)),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadPendingList(),
                          color: AppColors.primaryIndigo,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(14),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                color: isDark ? AppColors.darkCard : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(14.0),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppColors.primaryIndigo.withOpacity(0.12),
                                        child: Text(
                                          (student['name'] ?? 'S').substring(0, 1).toUpperCase(),
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
                                              student['name'] ?? 'Student',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              student['phone'] ?? 'N/A',
                                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                                            ),
                                            Text(
                                              student['shift_name'] ?? 'Morning Shift',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => _showAllotSeatDialog(student),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryIndigo,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Allot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
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
    final isSelected = _selectedShiftFilter == value;
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
        if (val) setState(() => _selectedShiftFilter = value);
      },
    );
  }
}
