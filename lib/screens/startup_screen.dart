import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import '../theme.dart';
import '../api_service.dart';
import '../admin/admin_shell.dart';
import 'buyer_home_screen.dart';
import 'farmer_home_screen.dart';
import 'login_screen.dart';

/// FR1: first screen of the app. Reopens a saved login (checked against
/// the backend) and sends the user to the home screen for their real role.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _offline = false;
  bool _slow = false; // still waiting after a few seconds
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    // Not on the first call: setState is not allowed inside initState.
    if (_offline) setState(() => _offline = false);
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _slow = true);
    });
    final result = await ApiService.restoreSession();
    _slowTimer?.cancel();
    if (!mounted) return;
    _slow = false;

    switch (result) {
      case SessionRestore.restored:
        final user = ApiService.currentUser!;
        _replaceWith(user.isAdmin
            ? const AdminShell()
            : user.isFarmer
                ? const FarmerHomeScreen()
                : const BuyerHomeScreen());
      case SessionRestore.offline:
        setState(() => _offline = true);
      case SessionRestore.expired:
      case SessionRestore.none:
        _replaceWith(const LoginScreen());
    }
  }

  void _replaceWith(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.darkGreen,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: TamuColors.primary,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: const Icon(Icons.eco_outlined,
                      size: 34, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text('TAMU',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: Colors.white)),
                const SizedBox(height: 28),
                if (!_offline) ...[
                  const CircularProgressIndicator(color: TamuColors.secondary),
                  if (_slow) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Starting the TAMU server.\n'
                      'This can take up to a minute.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, height: 1.5, color: Color(0xFFB8D0BA)),
                    ),
                  ],
                ] else ...[
                  const Icon(Icons.wifi_off,
                      size: 36, color: Color(0xFFB8D0BA)),
                  const SizedBox(height: 10),
                  const Text("Can't reach the TAMU server",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    kCloudBackend
                        ? 'Check your internet connection and try again.'
                        : 'Check that the backend is running and that your '
                            'phone is on the same Wi-Fi as the laptop.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, height: 1.5, color: Color(0xFFB8D0BA)),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: _restore,
                      child: const Text('Try again'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _replaceWith(const LoginScreen()),
                    child: const Text('Go to sign in',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
