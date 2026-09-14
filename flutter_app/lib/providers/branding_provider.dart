import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class BrandingProvider with ChangeNotifier {
  String _appName = 'Self Study Library';
  String _appLogoUrl = '';
  String _appTagline = 'Quiet Environment & High-Speed Wi-Fi';

  String get appName => _appName;
  String get appLogoUrl => _appLogoUrl;
  String get appTagline => _appTagline;

  BrandingProvider() {
    _loadCachedSettings();
    fetchAppSettings();
  }

  Future<void> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _appName = prefs.getString('cached_app_name') ?? 'Self Study Library';
      _appLogoUrl = prefs.getString('cached_app_logo_url') ?? '';
      _appTagline = prefs.getString('cached_app_tagline') ?? 'Quiet Environment & High-Speed Wi-Fi';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchAppSettings() async {
    try {
      final res = await ApiService.getAppSettings();
      if (res['success'] == true && res['settings'] != null) {
        final settings = res['settings'];
        final newName = (settings['app_name'] ?? '').toString().trim();
        final newLogo = (settings['app_logo_url'] ?? '').toString().trim();
        final newTagline = (settings['app_tagline'] ?? '').toString().trim();

        _appName = newName.isNotEmpty ? newName : 'Self Study Library';
        _appLogoUrl = newLogo;
        _appTagline = newTagline.isNotEmpty ? newTagline : 'Quiet Environment & High-Speed Wi-Fi';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_app_name', _appName);
        await prefs.setString('cached_app_logo_url', _appLogoUrl);
        await prefs.setString('cached_app_tagline', _appTagline);

        notifyListeners();
      }
    } catch (_) {}
  }

  void updateLocalBranding({required String name, required String logoUrl, required String tagline}) {
    if (name.isNotEmpty) _appName = name;
    _appLogoUrl = logoUrl;
    if (tagline.isNotEmpty) _appTagline = tagline;
    notifyListeners();
  }
}
