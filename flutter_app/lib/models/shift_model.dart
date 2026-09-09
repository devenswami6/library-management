class ShiftModel {
  final int id;
  final String name;
  final String startTime;
  final String endTime;
  final double feeAmount;
  final bool isActive;

  ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.feeAmount,
    this.isActive = true,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      feeAmount: json['fee_amount'] is double
          ? json['fee_amount']
          : double.parse(json['fee_amount'].toString()),
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}
