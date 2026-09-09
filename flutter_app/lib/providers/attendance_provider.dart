import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_model.dart';
import '../services/api_service.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceModel? _todayAttendance;
  bool _isLoading = false;
  String? _message;

  AttendanceModel? get todayAttendance => _todayAttendance;
  bool get isLoading => _isLoading;
  String? get message => _message;

  void setTodayAttendance(AttendanceModel? att) {
    _todayAttendance = att;
    notifyListeners();
  }

  // Helper method to fetch GPS location with permissions
  Future<Position?> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _message = "Location services (GPS) are disabled on your device. Please turn on GPS.";
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _message = "Location permissions are denied. Geofence check-in requires location permission.";
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _message = "Location permissions are permanently denied in settings. Please allow location in App Info.";
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      _message = "Could not fetch current GPS location: $e";
      return null;
    }
  }

  Future<bool> checkIn(int userId) async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    final position = await determinePosition();
    if (position == null) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final deviceTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final result = await ApiService.studentCheckIn(
      userId,
      deviceTime,
      lat: position.latitude,
      lng: position.longitude,
    );

    _isLoading = false;
    if (result['success'] == true) {
      _todayAttendance = AttendanceModel(
        id: 0,
        userId: userId,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        checkInTime: deviceTime,
        status: 'present',
      );
      _message = result['message'];
      notifyListeners();
      return true;
    } else {
      _message = result['message'] ?? 'Check-in failed';
      notifyListeners();
      return false;
    }
  }

  Future<bool> checkOut(int userId, {bool isAuto = false}) async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    double? lat;
    double? lng;

    if (!isAuto) {
      final position = await determinePosition();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
      }
    }

    final deviceTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final result = await ApiService.studentCheckOut(
      userId,
      deviceTime,
      lat: lat,
      lng: lng,
      autoCheckout: isAuto,
    );

    _isLoading = false;
    if (result['success'] == true) {
      if (_todayAttendance != null) {
        _todayAttendance = AttendanceModel(
          id: _todayAttendance!.id,
          userId: userId,
          date: _todayAttendance!.date,
          checkInTime: _todayAttendance!.checkInTime,
          checkOutTime: deviceTime,
          status: 'present',
        );
      }
      _message = result['message'];
      notifyListeners();
      return true;
    } else {
      _message = result['message'] ?? 'Check-out failed';
      notifyListeners();
      return false;
    }
  }
}
