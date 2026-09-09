import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({Key? key}) : super(key: key);

  @override
  _ManageStudentsScreenState createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingActive = true;
  bool _isLoadingRecycleBin = true;

  List<dynamic> _allStudents = [];
  List<dynamic> _filteredStudents = [];
  List<dynamic> _recycleBinStudents = [];

  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchActiveStudents();
    _fetchRecycleBinStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveStudents() async {
    setState(() => _isLoadingActive = true);
    final res = await ApiService.getAllStudents();
    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _allStudents = res['students'] ?? [];
          _isLoadingActive = false;
        });
        _applyFilters();
      } else {
        setState(() => _isLoadingActive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to load students directory.')),
        );
      }
    }
  }

  Future<void> _fetchRecycleBinStudents() async {
    setState(() => _isLoadingRecycleBin = true);
    final res = await ApiService.getRecycleBinStudents();
    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _recycleBinStudents = res['students'] ?? [];
          _isLoadingRecycleBin = false;
        });
      } else {
        setState(() => _isLoadingRecycleBin = false);
      }
    }
  }

  void _applyFilters() {
    final query = _searchQuery.toLowerCase().trim();
    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        final desk = (s['seat_number'] ?? '').toString().toLowerCase();
        final status = (s['status'] ?? '').toString().toLowerCase();

        final matchesSearch = query.isEmpty ||
            name.contains(query) ||
            phone.contains(query) ||
            email.contains(query) ||
            desk.contains(query);

        final matchesStatus = _selectedStatusFilter == 'all' ||
            (_selectedStatusFilter == 'approved' && (status == 'approved' || status == 'active')) ||
            (_selectedStatusFilter == 'pending' && status == 'pending') ||
            (_selectedStatusFilter == 'hold' && status == 'hold') ||
            (_selectedStatusFilter == 'cancelled' && status == 'cancelled');

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _confirmSoftDeleteStudent(Map<String, dynamic> student) {
    final int studentId = student['id'] is int ? student['id'] : int.tryParse(student['id'].toString()) ?? 0;
    final String studentName = student['name'] ?? 'Student';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.delete_sweep, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Move to Recycle Bin', style: TextStyle(color: Colors.orangeAccent, fontSize: 16)),
          ],
        ),
        content: Text(
          'Move "$studentName" to Recycle Bin?\n\n'
          'The student record will be safely stored in the Recycle Bin for 30 DAYS before permanent deletion. You can restore it anytime.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              _performSoftDeleteStudent(studentId, studentName);
            },
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('MOVE TO RECYCLE BIN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _performSoftDeleteStudent(int studentId, String studentName) async {
    final res = await ApiService.deleteStudent(studentId);
    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Student "$studentName" moved to Recycle Bin (Kept for 30 days).'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        _fetchActiveStudents();
        _fetchRecycleBinStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to move student to Recycle Bin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _restoreStudent(Map<String, dynamic> student) async {
    final int studentId = student['id'] is int ? student['id'] : int.tryParse(student['id'].toString()) ?? 0;
    final String studentName = student['name'] ?? 'Student';

    final res = await ApiService.restoreStudent(studentId);
    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Student "$studentName" restored to active list.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchActiveStudents();
        _fetchRecycleBinStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to restore student.')),
        );
      }
    }
  }

  void _confirmPermanentDeleteStudent(Map<String, dynamic> student) {
    final int studentId = student['id'] is int ? student['id'] : int.tryParse(student['id'].toString()) ?? 0;
    final String studentName = student['name'] ?? 'Student';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Permanently Delete', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
          ],
        ),
        content: Text(
          '⚠️ PERMANENT PURGE WARNING:\n\n'
          'Are you sure you want to PERMANENTLY ERASE "$studentName" from the database?\n\n'
          'This will erase all attendance, fees, and chat records permanently. This CANNOT be undone.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final res = await ApiService.permanentDeleteStudent(studentId);
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Student record permanently erased.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  _fetchRecycleBinStudents();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'] ?? 'Failed to permanently erase record.')),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text('PERMANENTLY ERASE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStudentDetailsModal(Map<String, dynamic> s) {
    final String status = s['status'] ?? 'pending';
    Color statusColor = Colors.orange;
    String statusLabel = 'Pending';
    if (status == 'approved' || status == 'active') {
      statusColor = Colors.green;
      statusLabel = 'Approved';
    } else if (status == 'hold') {
      statusColor = Colors.amber;
      statusLabel = 'On Hold';
    } else if (status == 'cancelled') {
      statusColor = Colors.red;
      statusLabel = 'Cancelled';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryIndigo,
                      child: Text(
                        (s['name'] ?? 'S').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['name'] ?? 'No Name',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),

                _buildDetailRow(Icons.phone, 'Mobile Phone', s['phone'] ?? 'N/A'),
                _buildDetailRow(Icons.email, 'Email Address', s['email'] ?? 'N/A'),
                _buildDetailRow(Icons.person, 'Father Name', s['father_name'] ?? 'N/A'),
                _buildDetailRow(Icons.phone_paused, 'Emergency Contact', s['emergency_contact'] ?? 'N/A'),
                _buildDetailRow(Icons.badge, 'ID Proof', '${s['id_proof_type'] ?? 'ID'}: ${s['id_proof_no'] ?? 'N/A'}'),
                _buildDetailRow(Icons.chair, 'Allotted Desk', s['seat_number'] != null ? 'Desk ${s['seat_number']}' : 'Not Allotted'),
                _buildDetailRow(Icons.schedule, 'Shift Timing', s['shift_name'] ?? 'N/A'),
                _buildDetailRow(Icons.calendar_month, 'Joining Date', s['start_date'] ?? s['created_at'] ?? 'N/A'),
                _buildDetailRow(Icons.phone_android, 'Hardware Device ID', s['registered_device_id'] ?? 'Not Bound Yet'),
                _buildDetailRow(Icons.home, 'Residential Address', s['address'] ?? 'N/A'),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('CLOSE'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _confirmSoftDeleteStudent(s);
                        },
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text('MOVE TO RECYCLE BIN', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryIndigo),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Student Directory & Recycle Bin',
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'Active Directory 👥'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Recycle Bin 🗑️'),
                  if (_recycleBinStudents.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_recycleBinStudents.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: ACTIVE STUDENTS DIRECTORY
          _buildActiveStudentsTab(),

          // TAB 2: RECYCLE BIN DELETED STUDENTS
          _buildRecycleBinTab(),
        ],
      ),
    );
  }

  Widget _buildActiveStudentsTab() {
    return Column(
      children: [
        // Search & Filter Header Container
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              TextField(
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: 'Search student name, phone, desk...',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All Students', 'all'),
                    _buildFilterChip('Approved', 'approved'),
                    _buildFilterChip('Pending', 'pending'),
                    _buildFilterChip('On Hold', 'hold'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Active Student Cards List
        Expanded(
          child: _isLoadingActive
              ? const Center(child: CircularProgressIndicator())
              : _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No active student records found.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchActiveStudents,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (ctx, idx) {
                          final s = _filteredStudents[idx];
                          final String status = s['status'] ?? 'pending';

                          Color badgeColor = Colors.orange;
                          String statusText = 'Pending';
                          if (status == 'approved' || status == 'active') {
                            badgeColor = Colors.green;
                            statusText = 'Approved';
                          } else if (status == 'hold') {
                            badgeColor = Colors.amber;
                            statusText = 'On Hold';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: InkWell(
                              onTap: () => _showStudentDetailsModal(s),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.primaryIndigo.withOpacity(0.15),
                                          child: Text(
                                            (s['name'] ?? 'S').substring(0, 1).toUpperCase(),
                                            style: const TextStyle(color: AppColors.primaryIndigo, fontWeight: FontWeight.bold),
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
                                                      s['name'] ?? 'No Name',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: badgeColor.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      statusText,
                                                      style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '📞 ${s['phone'] ?? 'N/A'}',
                                                style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                                          child: Text(
                                            '🪑 Desk: ${s['seat_number'] != null ? 'Desk ' + s['seat_number'].toString() : 'Unassigned'} • Shift: ${s['shift_name'] ?? 'N/A'}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              icon: const Icon(Icons.info_outline, color: AppColors.primaryIndigo, size: 20),
                                              onPressed: () => _showStudentDetailsModal(s),
                                              tooltip: 'View Profile',
                                            ),
                                            IconButton(
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              icon: const Icon(Icons.delete_outline, color: Colors.orangeAccent, size: 20),
                                              onPressed: () => _confirmSoftDeleteStudent(s),
                                              tooltip: 'Move to Recycle Bin',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildRecycleBinTab() {
    return _isLoadingRecycleBin
        ? const Center(child: CircularProgressIndicator())
        : _recycleBinStudents.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.delete_sweep_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Recycle Bin is currently empty.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    SizedBox(height: 6),
                    Text('Deleted students will remain here for 30 days.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchRecycleBinStudents,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _recycleBinStudents.length,
                  itemBuilder: (ctx, idx) {
                    final s = _recycleBinStudents[idx];
                    final int daysLeft = s['days_left'] is int ? s['days_left'] : int.tryParse(s['days_left'].toString()) ?? 30;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Colors.redAccent,
                                  child: Icon(Icons.delete_outline, color: Colors.white),
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
                                              s['name'] ?? 'No Name',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '⏰ $daysLeft Days Left',
                                              style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('📞 Phone: ${s['phone'] ?? 'N/A'}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                                  child: Text(
                                    '🗓️ Deleted: ${s['deleted_at'] ?? 'Recently'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () => _restoreStudent(s),
                                      icon: const Icon(Icons.restore, color: Colors.white, size: 14),
                                      label: const Text('Restore', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                                      onPressed: () => _confirmPermanentDeleteStudent(s),
                                      tooltip: 'Delete Permanently',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
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
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primaryIndigo.withOpacity(0.25),
        onSelected: (val) {
          setState(() => _selectedStatusFilter = value);
          _applyFilters();
        },
      ),
    );
  }
}
