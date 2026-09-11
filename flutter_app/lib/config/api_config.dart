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
  // Concept B Primary SaaS Indigo Palette
  static const Color primaryIndigo = Color(0xFF6366F1); // Royal Indigo / Violet
  static const Color primaryBlue = Color(0xFF4F46E5);   // Deep Indigo Accent
  static const Color accentCyan = Color(0xFF0EA5E9);    // Sky Blue Accent
  static const Color accentViolet = Color(0xFF8B5CF6);  // Electric Violet
  
  // Status Colors (Concept B SaaS Chips)
  static const Color statusSuccess = Color(0xFF22C55E); // Mint Emerald Green
  static const Color statusSuccessBg = Color(0xFFDCFCE7);
  static const Color statusWarning = Color(0xFFF59E0B); // Amber Gold
  static const Color statusWarningBg = Color(0xFFFEF3C7);
  static const Color statusDanger = Color(0xFFEF4444);  // Soft Rose Red
  static const Color statusDangerBg = Color(0xFFFEE2E2);
  static const Color statusInfo = Color(0xFF0EA5E9);    // Sky Blue Info
  static const Color statusInfoBg = Color(0xFFE0F2FE);

  // Seat Matrix Specific
  static const Color seatAvailable = Color(0xFF22C55E); 
  static const Color seatOccupied = Color(0xFFEF4444);  
  static const Color seatMyBooked = Color(0xFF6366F1);  
  static const Color seatPending = Color(0xFFF59E0B);   

  // Light Mode Colors (Concept B Clean Surface)
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
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
