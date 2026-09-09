import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

class LiveAttendanceScreen extends StatefulWidget {
  const LiveAttendanceScreen({Key? key}) : super(key: key);

  @override
  _LiveAttendanceScreenState createState() => _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends State<LiveAttendanceScreen> {
  bool _isLoading = true;
  List<dynamic> _allAttendance = [];
  List<dynamic> _filteredAttendance = [];
  String _todayDate = '';
  int _totalStudents = 0;
  int _currentlyInside = 0;
  int _absentOutside = 0;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, inside, outside

  @override
  void initState() {
    super.initState();
    _loadLiveAttendance();
  }

  Future<void> _loadLiveAttendance() async {
    try {
      final res = await ApiService.getLiveAttendance();
      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _allAttendance = res['attendance_list'] ?? [];
            _todayDate = res['date'] ?? '';
            _totalStudents = res['total_students'] is int
                ? res['total_students']
                : int.tryParse(res['total_students']?.toString() ?? '0') ?? _allAttendance.length;
            _currentlyInside = res['currently_inside'] is int
                ? res['currently_inside']
                : int.tryParse(res['currently_inside']?.toString() ?? '0') ?? 0;
            _absentOutside = res['absent_outside'] is int
                ? res['absent_outside']
                : int.tryParse(res['absent_outside']?.toString() ?? '0') ?? (_totalStudents - _currentlyInside);
            _isLoading = false;
          });
          _applyFilters();
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchQuery.toLowerCase().trim();
    setState(() {
      _filteredAttendance = _allAttendance.where((item) {
        final name = (item['student_name'] ?? '').toString().toLowerCase();
        final phone = (item['phone'] ?? '').toString().toLowerCase();
        final desk = (item['seat_number'] ?? '').toString().toLowerCase();
        final shift = (item['shift_name'] ?? '').toString().toLowerCase();

        final bool isPresent = item['check_in_time'] != null &&
            (item['check_out_time'] == null || item['check_out_time'].toString().isEmpty);

        final matchesSearch = query.isEmpty ||
            name.contains(query) ||
            phone.contains(query) ||
            desk.contains(query) ||
            shift.contains(query);

        final matchesStatus = _statusFilter == 'all' ||
            (_statusFilter == 'inside' && isPresent) ||
            (_statusFilter == 'outside' && !isPresent);

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _toggleAttendance(int studentId, String type) async {
    final res = await ApiService.adminAttendanceToggle(studentId, type);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Attendance status updated.'),
          backgroundColor: type == 'checkin' ? Colors.green : Colors.orangeAccent,
        ),
      );
      _loadLiveAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Live Attendance Logger ${_todayDate.isNotEmpty ? "($_todayDate)" : ""}',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLiveAttendance,
              child: Column(
                children: [
                  // Top Metrics Bar
                  Container(
                    color: Theme.of(context).cardColor,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Total Allotted',
                                value: '$_totalStudents',
                                icon: Icons.people_outline,
                                color: AppColors.primaryIndigo,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Inside Hall',
                                value: '$_currentlyInside',
                                icon: Icons.how_to_reg,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Outside / Exited',
                                value: '$_absentOutside',
                                icon: Icons.person_off_outlined,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Search Input
                        TextField(
                          onChanged: (val) {
                            _searchQuery = val;
                            _applyFilters();
                          },
                          decoration: InputDecoration(
                            hintText: 'Search student name, phone, desk (e.g. A-01)...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() => _searchQuery = '');
                                      _applyFilters();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Status Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All Students ($_totalStudents)', 'all'),
                              _buildFilterChip('🟢 Inside Hall ($_currentlyInside)', 'inside'),
                              _buildFilterChip('🔴 Outside / Exited ($_absentOutside)', 'outside'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Student Attendance Cards List
                  Expanded(
                    child: _filteredAttendance.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.fact_check_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No student records match filter criteria.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filteredAttendance.length,
                            itemBuilder: (ctx, index) {
                              final item = _filteredAttendance[index];
                              final bool isPresent = item['check_in_time'] != null &&
                                  (item['check_out_time'] == null || item['check_out_time'].toString().isEmpty);

                              final int studentId = item['user_id'] is int
                                  ? item['user_id']
                                  : int.tryParse(item['user_id']?.toString() ?? '0') ?? 0;

                              final String checkIn = item['check_in_time'] ?? 'Not Checked In Today';
                              final String checkOut = item['check_out_time'] ?? '';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isPresent
                                        ? Colors.green.withOpacity(0.4)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: isPresent ? 1.5 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isPresent
                                                ? Colors.green.withOpacity(0.15)
                                                : Colors.grey.withOpacity(0.15),
                                            child: Icon(
                                              isPresent ? Icons.how_to_reg : Icons.person_off_outlined,
                                              color: isPresent ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item['student_name'] ?? 'Student',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: isPresent
                                                            ? Colors.green.withOpacity(0.15)
                                                            : Colors.orange.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        isPresent ? '🟢 INSIDE HALL' : '🔴 OUTSIDE',
                                                        style: TextStyle(
                                                          color: isPresent ? Colors.green : Colors.orange.shade800,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '📞 ${item['phone'] ?? 'N/A'} • 🪑 Desk ${item['seat_number'] ?? 'N/A'} (${item['shift_name'] ?? 'N/A'})',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '🕒 In: $checkIn',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                ),
                                                if (checkOut.isNotEmpty)
                                                  Text(
                                                    '🚪 Out: $checkOut',
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          isPresent
                                              ? ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.redAccent,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: () => _toggleAttendance(studentId, 'checkout'),
                                                  icon: const Icon(Icons.logout, color: Colors.white, size: 14),
                                                  label: const Text('FORCE EXIT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                )
                                              : ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: () => _toggleAttendance(studentId, 'checkin'),
                                                  icon: const Icon(Icons.login, color: Colors.white, size: 14),
                                                  label: const Text('CHECK IN', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? Colors.white : AppColors.primaryIndigo)
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primaryIndigo.withOpacity(0.25),
        onSelected: (val) {
          setState(() => _statusFilter = value);
          _applyFilters();
        },
      ),
    );
  }
}
