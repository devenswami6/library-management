class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'student' or 'admin'
  final String status; // 'active' or 'pending'
  final String? seatNumber;
  final String? shiftName;
  final String? preparationFor;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.seatNumber,
    this.shiftName,
    this.preparationFor,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? shift;
    if (json['shift'] != null && json['shift']['name'] != null) {
      shift = json['shift']['name'];
    }

    return UserModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'student',
      status: json['status'] ?? 'pending',
      seatNumber: json['seat_number'],
      shiftName: shift,
      preparationFor: json['preparation_for'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'seat_number': seatNumber,
      'shift_name': shiftName,
      'preparation_for': preparationFor,
    };
  }
}
