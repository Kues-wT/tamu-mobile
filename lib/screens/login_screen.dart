import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'buyer_home_screen.dart';
import 'farmer_home_screen.dart';
import 'register_screen.dart';

/// TAMU Login screen - now calls the real /login endpoint.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showPassword = false;
  bool _loading = false;
  bool _registerHovered = false;

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
      final Widget destination =
          user.isFarmer ? const FarmerHomeScreen() : const BuyerHomeScreen();

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
      backgroundColor: TamuColors.darkGreen,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TamuSizes.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  _buildLogo(),
                  const SizedBox(height: 28),
                  _buildForm(),
                  const SizedBox(height: 16),
                  _buildDemoAccounts(),
                  const SizedBox(height: 16),
                  _buildRegisterLink(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: TamuColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: TamuColors.primary.withValues(alpha: 0.5),
                blurRadius: 30,
              ),
            ],
          ),
          child: const Center(child: Text('🌿', style: TextStyle(fontSize: 34))),
        ),
        const SizedBox(height: 12),
        const Text(
          'TAMU',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Farm Fresh. Direct to You.',
            style: TextStyle(fontSize: 16, color: TamuColors.secondary)),
        const Text('Tamparuli, Sabah',
            style: TextStyle(fontSize: 14, color: Colors.white54)),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Email',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_loading,
            style: const TextStyle(fontSize: 16),
            onSubmitted: (_) => _handleLogin(),
            decoration: const InputDecoration(
              hintText: 'nama@tamu.my',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: TamuSizes.gap),
          const Text('Password',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            enabled: !_loading,
            style: const TextStyle(fontSize: 16),
            onSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _handleLogin,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Login'),
          ),
        ],
      ),
    );
  }

  /// Demo shortcut buttons - handy during development and your FYP demo.
  Widget _buildDemoAccounts() {
    return Column(
      children: [
        const Text('Demo accounts (password: tamu1234)',
            style: TextStyle(fontSize: 13, color: Colors.white38)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _demoChip('🌾 Puan Siti', 'siti@tamu.my'),
            _demoChip('🌾 En. Jumat', 'jumat@tamu.my'),
            _demoChip('🛒 Cik Aina', 'aina@tamu.my'),
          ],
        ),
      ],
    );
  }

  Widget _demoChip(String label, String email) {
    // A plain button, not an ActionChip - the global chipTheme was
    // forcing a white background behind white text.
    return OutlinedButton(
      onPressed: _loading ? null : () => _fillDemo(email),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        side: const BorderSide(color: Colors.white54),
        minimumSize: const Size(0, 44), // keeps the 44px tap target
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? ",
            style: TextStyle(fontSize: 14, color: Colors.white70)),
        // MouseRegion gives a pointing-hand cursor on the web,
        // and the hover state underlines the word.
        MouseRegion(
          cursor: _loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _registerHovered = true),
          onExit: (_) => setState(() => _registerHovered = false),
          child: GestureDetector(
            onTap: _loading
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
            child: Text(
              'Register',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _registerHovered ? Colors.white : TamuColors.secondary,
                decoration:
                    _registerHovered ? TextDecoration.underline : null,
                decorationColor: Colors.white,
                decorationThickness: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
