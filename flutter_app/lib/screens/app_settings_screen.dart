import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_service.dart';
import '../widgets/custom_app_bar.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _logoUrlController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  final List<Map<String, String>> _presetLogos = [
    {
      'name': 'Default Royal Blue Shield 🛡️',
      'url': '',
    },
    {
      'name': 'Gold Book Logo 📖',
      'url': 'https://img.icons8.com/color/96/open-book.png',
    },
    {
      'name': 'Graduation Cap 🎓',
      'url': 'https://img.icons8.com/color/96/graduation-cap.png',
    },
    {
      'name': 'Modern Library Badge 🏛️',
      'url': 'https://img.icons8.com/color/96/library.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchAppSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppSettings() async {
    setState(() => _isLoading = true);
    final res = await ApiService.getAppSettings();
    if (mounted) {
      if (res['success'] == true && res['settings'] != null) {
        final settings = res['settings'];
        _nameController.text = settings['app_name'] ?? 'Self Study Library';
        _taglineController.text = settings['app_tagline'] ?? 'Quiet Environment & High-Speed Wi-Fi';
        _logoUrlController.text = settings['app_logo_url'] ?? '';
      }
      setState(() => _isLoading = false);
    }
  }

  void _handleSaveSettings() async {
    final appName = _nameController.text.trim();
    final tagline = _taglineController.text.trim();
    final logoUrl = _logoUrlController.text.trim();

    if (appName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App Name cannot be empty.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final res = await ApiService.updateAppSettings(
      appName: appName,
      appLogoUrl: logoUrl,
      appTagline: tagline,
    );
    setState(() => _isSaving = false);

    if (mounted) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'App Name & Logo updated successfully!'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to save app settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(title: 'App Branding & Settings ⚙️'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryIndigo))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Live Branding Preview Header Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: isDark ? AppColors.darkCard : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        children: [
                          const Text(
                            'Live App Preview',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _logoUrlController.text.isNotEmpty
                                  ? Image.network(
                                      _logoUrlController.text,
                                      width: 44,
                                      height: 44,
                                      errorBuilder: (_, __, ___) => const CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppColors.primaryIndigo,
                                        child: Icon(Icons.school_rounded, color: Colors.white, size: 24),
                                      ),
                                    )
                                  : const CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AppColors.primaryIndigo,
                                      child: Icon(Icons.school_rounded, color: Colors.white, size: 24),
                                    ),
                              const SizedBox(width: 14),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nameController.text.isEmpty ? 'Self Study Library' : _nameController.text,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _taglineController.text.isEmpty
                                          ? 'Quiet Environment & High-Speed Wi-Fi'
                                          : _taglineController.text,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Settings Form Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: isDark ? AppColors.darkCard : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customize App Name & Logo',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),

                          // App Name Field
                          TextField(
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Library / App Name *',
                              hintText: 'e.g. Keshav Self-Study Space',
                              prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.primaryIndigo),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // App Tagline Field
                          TextField(
                            controller: _taglineController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'App Tagline / Subtitle',
                              hintText: 'e.g. AC Study Hall & 24/7 Wi-Fi',
                              prefixIcon: Icon(Icons.subtitles_rounded, color: AppColors.primaryIndigo),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Custom Logo URL Field
                          TextField(
                            controller: _logoUrlController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Custom App Logo URL (Optional)',
                              hintText: 'https://example.com/logo.png',
                              prefixIcon: Icon(Icons.link_rounded, color: AppColors.primaryIndigo),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Preset Logo Picker Chips
                          const Text(
                            'Or Choose Preset Logo Preset:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _presetLogos.map((preset) {
                              final isSelected = _logoUrlController.text == preset['url'];
                              return ChoiceChip(
                                label: Text(preset['name']!),
                                selected: isSelected,
                                selectedColor: AppColors.primaryIndigo,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 12,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _logoUrlController.text = preset['url']!;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Save Settings Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _handleSaveSettings,
                              icon: const Icon(Icons.save_rounded, color: Colors.white),
                              label: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Save App Settings',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryIndigo,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
