class SeatModel {
  final int id;
  final String seatNumber;
  final String rowLabel;
  final String status; // 'available', 'booked', 'hold'
  final String? studentName;
  final String? studentPhone;
  final bool isMySeat;

  SeatModel({
    required this.id,
    required this.seatNumber,
    required this.rowLabel,
    required this.status,
    this.studentName,
    this.studentPhone,
    this.isMySeat = false,
  });

  factory SeatModel.fromJson(Map<String, dynamic> json) {
    return SeatModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      seatNumber: json['seat_number'] ?? '',
      rowLabel: json['row_label'] ?? 'A',
      status: json['status'] ?? 'available',
      studentName: json['student_name'],
      studentPhone: json['student_phone'],
      isMySeat: json['is_my_seat'] ?? false,
    );
  }
}
