import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Password Login Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // OTP Login Controllers
  final _phoneOrEmailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isOtpSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneOrEmailController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() => _resendCountdown--);
        } else {
          timer.cancel();
        }
      }
    });
  }

  void _handlePasswordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password.')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(email, password);

    if (mounted) {
      if (success) {
        final user = authProvider.currentUser;
        if (user?.role == 'admin') {
          Navigator.of(context).pushReplacementNamed('/admin_dashboard');
        } else {
          Navigator.of(context).pushReplacementNamed('/student_dashboard');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Login failed')),
        );
      }
    }
  }

  void _handleSendOtp() async {
    final phoneOrEmail = _phoneOrEmailController.text.trim();
    if (phoneOrEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your registered Mobile Phone or Email.')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final res = await authProvider.sendLoginOtp(phoneOrEmail);

    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _isOtpSent = true;
          _otpController.clear();
        });
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'OTP sent to registered phone notification bar!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Show prominent Alert Dialog for Security Lockout
        final msg = res['message'] ?? 'Failed to send OTP';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.shield, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Security Lockout', style: TextStyle(color: Colors.redAccent, fontSize: 16)),
              ],
            ),
            content: Text(msg, style: const TextStyle(fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _handleVerifyOtp() async {
    final phoneOrEmail = _phoneOrEmailController.text.trim();
    final otpCode = _otpController.text.trim();

    if (phoneOrEmail.isEmpty || otpCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP code.')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyLoginOtp(phoneOrEmail, otpCode);

    if (mounted) {
      if (success) {
        final user = authProvider.currentUser;
        if (user?.role == 'admin') {
          Navigator.of(context).pushReplacementNamed('/admin_dashboard');
        } else {
          Navigator.of(context).pushReplacementNamed('/student_dashboard');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'OTP Verification failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo / Icon
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryIndigo.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 54,
                    color: AppColors.primaryIndigo,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Self-Study Library',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Management Portal & Mobile App',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Form Card with Tabs
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Clean Tab Bar Toggle (Password vs OTP)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: AppColors.primaryIndigo,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            tabs: const [
                              Tab(text: 'OTP LOGIN 📲'),
                              Tab(text: 'PASSWORD 🔒'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tab Bar View Container
                        SizedBox(
                          height: _isOtpSent && _tabController.index == 0 ? 320 : 250,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // TAB 1: OTP LOGIN (Phone/Email)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _phoneOrEmailController,
                                    keyboardType: TextInputType.emailAddress,
                                    enabled: !_isOtpSent,
                                    decoration: InputDecoration(
                                      labelText: 'Registered Student Mobile Phone / Email',
                                      hintText: 'e.g. 7727880903 or rahul@gmail.com',
                                      prefixIcon: const Icon(Icons.phone_android_rounded),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: _isOtpSent
                                          ? IconButton(
                                              icon: const Icon(Icons.edit, color: AppColors.primaryIndigo),
                                              onPressed: () {
                                                setState(() {
                                                  _isOtpSent = false;
                                                  _otpController.clear();
                                                });
                                              },
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  if (!_isOtpSent)
                                    ElevatedButton.icon(
                                      onPressed: authProvider.isLoading ? null : _handleSendOtp,
                                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                                      label: const Text(
                                        'GET OTP CODE',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryIndigo,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    )
                                  else ...[
                                    // Hardware Device Binding Security Banner
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.4)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.shield_outlined, color: AppColors.primaryIndigo, size: 20),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'OTP sent to registered phone notification bar. Enter the 6-digit code below 📲',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primaryIndigo,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    TextField(
                                      controller: _otpController,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                                      textAlign: TextAlign.center,
                                      decoration: const InputDecoration(
                                        labelText: 'Enter 6-Digit OTP',
                                        hintText: '• • • • • •',
                                        prefixIcon: Icon(Icons.shield_outlined),
                                        border: OutlineInputBorder(),
                                        counterText: '',
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    ElevatedButton.icon(
                                      onPressed: authProvider.isLoading ? null : _handleVerifyOtp,
                                      icon: const Icon(Icons.verified_user_rounded, color: Colors.white),
                                      label: authProvider.isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                            )
                                          : const Text(
                                              'VERIFY OTP & LOGIN',
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade700,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Resend OTP Link
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text("Didn't receive code? ", style: TextStyle(fontSize: 12)),
                                        TextButton(
                                          onPressed: (_resendCountdown == 0 && !authProvider.isLoading) ? _handleSendOtp : null,
                                          child: Text(
                                            _resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend OTP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: _resendCountdown > 0 ? Colors.grey : AppColors.primaryIndigo,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),

                              // TAB 2: PASSWORD LOGIN
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Email Address',
                                      prefixIcon: Icon(Icons.email_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: authProvider.isLoading ? null : _handlePasswordLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryIndigo,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text(
                                            'LOGIN WITH PASSWORD',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have a library seat account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushNamed('/register');
                      },
                      child: const Text(
                        'Register Here',
                        style: TextStyle(
                          color: AppColors.primaryIndigo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Powered by Ramxonwebwork',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryIndigo,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
