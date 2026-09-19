import 'package:flutter/material.dart';
import '../theme.dart';
import 'buyer_home_screen.dart';

/// TAMU Login screen.
/// UI only for now - no real authentication yet.
/// Rebuilt in Flutter from the Figma LoginScreen.tsx prototype.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _role = 'farmer'; // 'farmer' or 'buyer'
  bool _showPassword = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BuyerHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.darkGreen,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Keeps it phone-shaped even when run in Chrome.
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TamuSizes.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  _buildLogo(),
                  const SizedBox(height: 28),
                  _buildRoleSelector(),
                  const SizedBox(height: 24),
                  _buildForm(),
                  const SizedBox(height: 20),
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
        const Text(
          'Farm Fresh. Direct to You.',
          style: TextStyle(fontSize: 16, color: TamuColors.secondary),
        ),
        const SizedBox(height: 2),
        const Text(
          'Tamparuli, Sabah',
          style: TextStyle(fontSize: 14, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Row(
      children: [
        Expanded(
          child: _roleCard(
            value: 'farmer',
            emoji: '🌾',
            title: 'I am a Farmer',
            subtitle: 'Sell your crops',
          ),
        ),
        const SizedBox(width: TamuSizes.gap),
        Expanded(
          child: _roleCard(
            value: 'buyer',
            emoji: '🛒',
            title: 'I am a Buyer',
            subtitle: 'Buy fresh produce',
          ),
        ),
      ],
    );
  }

  Widget _roleCard({
    required String value,
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    final selected = _role == value;
    return InkWell(
      onTap: () => setState(() => _role = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? TamuColors.primary : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? TamuColors.secondary : Colors.white24,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: selected ? TamuColors.secondary : Colors.white38,
              ),
            ),
          ],
        ),
      ),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'nama@email.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: TamuSizes.gap),
          const Text('Password',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('Forgot password?',
                  style: TextStyle(fontSize: 14, color: TamuColors.secondary)),
            ),
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: _handleLogin,
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? ",
            style: TextStyle(fontSize: 14, color: Colors.white70)),
        GestureDetector(
          onTap: () {},
          child: const Text(
            'Register',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: TamuColors.secondary),
          ),
        ),
      ],
    );
  }
}
