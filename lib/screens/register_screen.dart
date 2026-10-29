import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import '../theme.dart';
import '../api_service.dart';
import '../widgets/auth_widgets.dart';
import 'buyer_home_screen.dart';
import 'farmer_home_screen.dart';

/// Create a new TAMU account (farmer or buyer) - Figma "Auth" register.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _farmController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _role = 'farmer';
  bool _loading = false;

  bool get _isFarmer => _role == 'farmer';

  @override
  void dispose() {
    _nameController.dispose();
    _farmController.dispose();
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
        farmName: _isFarmer ? _farmController.text.trim() : null,
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
      backgroundColor: TamuColors.warm,
      appBar: AppBar(
        backgroundColor: TamuColors.warm,
        surfaceTintColor: Colors.transparent,
        // Light bar, so the back arrow must be dark (theme default is white).
        foregroundColor: TamuColors.darkGreen,
        iconTheme: const IconThemeData(color: TamuColors.darkGreen),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create account',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: TamuColors.darkGreen)),
            Text('Join TAMU as a farmer or buyer',
                style:
                    TextStyle(fontSize: 12, color: TamuColors.textSecondary)),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: AutofillGroup(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  children: [
                    const Text('How will you use TAMU?',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: TamuColors.darkGreen)),
                    const SizedBox(height: 3),
                    const Text('Your role cannot be changed later.',
                        style: TextStyle(
                            fontSize: 12, color: TamuColors.textSecondary)),
                    _roleCard('farmer', Icons.eco_outlined, 'I want to sell',
                        'List crops and manage orders'),
                    _roleCard('buyer', Icons.search, 'I want to buy',
                        'Find crops, farms and place orders'),
                    const SizedBox(height: 8),
                    AuthField(
                      label: 'Full name',
                      controller: _nameController,
                      hint: 'e.g. Puan Rosnah',
                      enabled: !_loading,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      validator: trValidator((v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter your name'
                          : null),
                    ),
                    if (_isFarmer)
                      AuthField(
                        label: 'Farm or stall name (optional)',
                        controller: _farmController,
                        hint: 'e.g. Kebun Bukit Sayap',
                        enabled: !_loading,
                        textCapitalization: TextCapitalization.words,
                        helper: 'Shown to buyers. You can set your public '
                            'pickup point on the map later in Profile.',
                        validator: trValidator((v) => (v != null && v.trim().length > 120)
                            ? 'Keep it under 120 characters'
                            : null),
                      ),
                    AuthField(
                      label: 'Email',
                      controller: _emailController,
                      hint: 'nama@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_loading,
                      autofillHints: const [AutofillHints.email],
                      validator: trValidator((v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'That does not look like an email';
                        }
                        return null;
                      }),
                    ),
                    AuthField(
                      label: 'Phone number (optional)',
                      controller: _phoneController,
                      hint: 'e.g. 012-8801122',
                      keyboardType: TextInputType.phone,
                      enabled: !_loading,
                      autofillHints: const [AutofillHints.telephoneNumber],
                    ),
                    AuthField(
                      label: 'Password',
                      controller: _passwordController,
                      hint: 'At least 6 characters',
                      obscureText: true,
                      enabled: !_loading,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: trValidator((v) => (v == null || v.length < 6)
                          ? 'Password must be at least 6 characters'
                          : null),
                    ),
                    AuthField(
                      label: 'Confirm password',
                      controller: _confirmController,
                      hint: 'Type it again',
                      obscureText: true,
                      enabled: !_loading,
                      validator: trValidator((v) => (v != _passwordController.text)
                          ? 'Passwords do not match'
                          : null),
                    ),
                    const SizedBox(height: 12),
                    AuthPrimaryButton(
                      label: 'Create account',
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 6),
                    AuthSwitchLine(
                      prompt: 'Already have an account?',
                      action: 'Sign in',
                      onTap:
                          _loading ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Figma ".role-card": icon tile, title, subtitle, selected state.
  Widget _roleCard(
      String value, IconData icon, String title, String subtitle) {
    final selected = _role == value;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: selected ? const Color(0xFFFBFFFB) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: BorderSide(
            color: selected ? TamuColors.primary : TamuColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: _loading ? null : () => setState(() => _role = value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: TamuColors.lightGreen,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: TamuColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: TamuColors.darkGreen)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: TamuColors.textSecondary)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? TamuColors.primary : const Color(0xFFBBC4BA),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
