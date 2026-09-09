class AttendanceModel {
  final int id;
  final int userId;
  final String date;
  final String? checkInTime;
  final String? checkOutTime;
  final String status;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString()),
      date: json['date'] ?? '',
      checkInTime: json['check_in_time'],
      checkOutTime: json['check_out_time'],
      status: json['status'] ?? 'present',
    );
  }

  bool get isCurrentlyCheckedIn => checkInTime != null && (checkOutTime == null || checkOutTime!.isEmpty);
}
