import 'package:flutter/material.dart';
import '../models/seat_model.dart';
import '../services/api_service.dart';

class SeatProvider extends ChangeNotifier {
  int _selectedShiftId = 1;
  Map<String, List<SeatModel>> _seatRows = {};
  bool _isLoading = false;
  String? _errorMessage;

  int get selectedShiftId => _selectedShiftId;
  Map<String, List<SeatModel>> get seatRows => _seatRows;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void changeShift(int shiftId, int currentUserId) {
    _selectedShiftId = shiftId;
    fetchSeatMatrix(currentUserId);
  }

  Future<void> fetchSeatMatrix(int currentUserId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await ApiService.getSeatMatrix(_selectedShiftId, currentUserId);

    _isLoading = false;
    if (result['success'] == true && result['rows'] != null) {
      final Map<String, dynamic> rowsRaw = result['rows'];
      final Map<String, List<SeatModel>> parsedRows = {};

      rowsRaw.forEach((rowKey, seatsList) {
        final List<SeatModel> seats = [];
        for (var seatJson in seatsList) {
          seats.add(SeatModel.fromJson(seatJson));
        }
        parsedRows[rowKey] = seats;
      });

      _seatRows = parsedRows;
    } else {
      _errorMessage = result['message'] ?? 'Failed to load seat matrix';
    }
    notifyListeners();
  }
}
