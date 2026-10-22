import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../api_service.dart';
import '../admin/admin_shell.dart';
import '../widgets/auth_widgets.dart';
import 'buyer_home_screen.dart';
import 'farmer_home_screen.dart';
import 'register_screen.dart';

/// TAMU Login screen (Figma "Auth" sign-in) - calls the real /login endpoint.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showPassword = false;
  bool _loading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _snack('Please enter your email and password', TamuColors.danger);
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await ApiService.login(email, password);
      if (!mounted) return;

      // The ROLE comes from the database now, not from a button.
      final Widget destination = user.isAdmin
          ? const AdminShell()
          : user.isFarmer
              ? const FarmerHomeScreen()
              : const BuyerHomeScreen();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  /// Fills the form so you can demo quickly.
  void _fillDemo(String email) {
    _emailController.text = email;
    _passwordController.text = 'tamu1234';
    setState(() {});
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.warm,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
                children: [
                  const AuthBrandRow(),
                  const SizedBox(height: 26),
                  const Text('Welcome back',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: TamuColors.darkGreen)),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in to your farmer or buyer account.',
                    style: TextStyle(
                        fontSize: 13, color: TamuColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  AuthField(
                    label: 'Email',
                    controller: _emailController,
                    hint: 'nama@tamu.my',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_loading,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  AuthField(
                    label: 'Password',
                    controller: _passwordController,
                    hint: 'Enter your password',
                    obscureText: !_showPassword,
                    enabled: !_loading,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _handleLogin(),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(_showPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AuthPrimaryButton(
                    label: 'Sign in',
                    loading: _loading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 6),
                  AuthSwitchLine(
                    prompt: 'New to TAMU?',
                    action: 'Create account',
                    onTap: _loading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            ),
                  ),
                  // Demo shortcuts only in debug builds (flutter run). The
                  // release APK and the public web admin never show them.
                  if (kDebugMode) ...[
                    const SizedBox(height: 14),
                    _buildDemoAccounts(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Demo shortcuts for the FYP demo, clearly labelled as demo data.
  Widget _buildDemoAccounts() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF0EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              border: Border.all(color: const Color(0xFFA7B6A8)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text('DEMO ACCOUNTS',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF526354))),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sample accounts for the project demo. Tap one to fill in its '
            'email and password.',
            style: TextStyle(
                fontSize: 11, height: 1.45, color: TamuColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _demoChip('Puan Siti · farmer', 'siti@tamu.my'),
              _demoChip('En. Jumat · farmer', 'jumat@tamu.my'),
              _demoChip('Cik Aina · buyer', 'aina@tamu.my'),
            ],
          ),
        ],
      ),
    );
  }

  /// Figma ".chips button": white outlined pill.
  Widget _demoChip(String label, String email) {
    return OutlinedButton(
      onPressed: _loading ? null : () => _fillDemo(email),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: TamuColors.darkGreen,
        side: const BorderSide(color: TamuColors.line),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}
