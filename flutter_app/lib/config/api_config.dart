import 'package:flutter/material.dart';

class ApiConfig {
  // Render.com Live 24/7 HTTPS Server URL:
  static String baseUrl = 'https://library-management-hmwx.onrender.com';

  static String get jsonAuth => '$baseUrl/api/json_auth.php';
  static String get jsonStudent => '$baseUrl/api/json_student_actions.php';
  static String get jsonAdmin => '$baseUrl/api/json_admin_actions.php';
  static String get seatMatrix => '$baseUrl/api/seat_matrix.php';
}

class AppColors {
  // Primary Palette
  static const Color primaryBlue = Color(0xFF1E3A8A); // Slate/Navy
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color accentCyan = Color(0xFF06B6D4);
  
  // Status Colors
  static const Color seatAvailable = Color(0xFF10B981); // Emerald Green
  static const Color seatOccupied = Color(0xFFEF4444);  // Rose Red
  static const Color seatMyBooked = Color(0xFF3B82F6);  // Blue
  static const Color seatPending = Color(0xFFF59E0B);   // Amber

  // Light Mode Colors
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightSubtext = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkSubtext = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
}
