import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';

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

  void _showAllotSeatDialog(Map<String, dynamic> student) {
    int selectedShiftId = student['shift_id'] ?? (_shifts.isNotEmpty ? _shifts.first['id'] : 1);

    // Calculate occupied seat IDs for selected shift
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          occupiedSeatIds = getOccupiedSeatIds(selectedShiftId);
          freeSeats = _availableSeats.where((s) => !occupiedSeatIds.contains(s['id'])).toList();

          return AlertDialog(
            title: Text('Allot Seat to ${student['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: ${student['email']}'),
                  Text('Phone: ${student['phone']}'),
                  const SizedBox(height: 12),

                  // Shift selector
                  DropdownButtonFormField<int>(
                    value: selectedShiftId,
                    decoration: const InputDecoration(labelText: 'Shift Timing', border: OutlineInputBorder()),
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
                            'Desk ${seat['seat_number']} (Row ${seat['row_label']}) ${isOccupied ? "- [OCCUPIED IN THIS SHIFT]" : "- [AVAILABLE]"}',
                            style: TextStyle(
                              color: isOccupied ? Colors.grey : AppColors.seatAvailable,
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
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: (selectedSeatId == 0 || freeSeats.isEmpty)
                    ? null
                    : () async {
                        final res = await ApiService.allotSeat(student['id'], selectedSeatId, selectedShiftId);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'] ?? 'Seat allotted')),
                        );
                        _loadPendingList();
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryIndigo),
                child: const Text('ALLOT SEAT NOW', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Seat Allotment Requests'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingStudents.isEmpty
              ? const Center(
                  child: Text('No pending registration requests right now.'),
                )
              : RefreshIndicator(
                  onRefresh: () async => _loadPendingList(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _pendingStudents.length,
                    itemBuilder: (context, index) {
                      final student = _pendingStudents[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.seatPending.withOpacity(0.2),
                            child: const Icon(Icons.person, color: AppColors.seatPending),
                          ),
                          title: Text(
                            student['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${student['email']}'),
                              Text('Phone: ${student['phone']}'),
                              Text('Requested Shift: ${student['shift_name'] ?? "Morning"}'),
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: () => _showAllotSeatDialog(student),
                            icon: const Icon(Icons.chair, size: 18),
                            label: const Text('ALLOT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.seatAvailable,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
