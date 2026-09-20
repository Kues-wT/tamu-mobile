import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';
import 'buyer_home_screen.dart';
import 'farmer_home_screen.dart';

/// Create a new TAMU account (farmer or buyer).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _role = 'farmer';
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = await ApiService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        role: _role,
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;

      // register() logs you in automatically.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              user.isFarmer ? const FarmerHomeScreen() : const BuyerHomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TamuColors.danger,
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(fontSize: 16)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(TamuSizes.pagePadding),
                children: [
                  const Text('I want to join as',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _roleCard('farmer', '🌾', 'Farmer',
                              'Sell your crops')),
                      const SizedBox(width: TamuSizes.gap),
                      Expanded(
                          child: _roleCard('buyer', '🛒', 'Buyer',
                              'Buy fresh produce')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _label('Full Name'),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Puan Rosnah',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your name'
                        : null,
                  ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Email'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'nama@tamu.my',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'That does not look like an email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Phone (optional)'),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 012-8801122',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'At least 6 characters',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Confirm Password'),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Type it again',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v != _passwordController.text)
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create Account'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Back to Login',
                        style: TextStyle(
                            fontSize: 16, color: TamuColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _roleCard(String value, String emoji, String title, String subtitle) {
    final selected = _role == value;
    return InkWell(
      onTap: () => setState(() => _role = value),
      borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? TamuColors.lightGreen : Colors.white,
          borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
          border: Border.all(
            color: selected ? TamuColors.primary : TamuColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? TamuColors.primary
                        : TamuColors.textPrimary)),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: TamuColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
