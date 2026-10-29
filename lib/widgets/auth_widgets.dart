import 'package:flutter/material.dart' hide Text;
import '../i18n.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Shared pieces for the Figma-style Login and Register screens
/// (Figma "Auth": light warm page, label above a rounded white field).

/// Small TAMU logo row (Figma ".brand-row").
class AuthBrandRow extends StatelessWidget {
  const AuthBrandRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: TamuColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.eco_outlined, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 9),
        const Text('TAMU',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: TamuColors.darkGreen)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Tamparuli, Sabah',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: TamuColors.textSecondary)),
        ),
        // English / Bahasa Melayu, shown before signing in.
        const LanguageSwitch(),
      ],
    );
  }
}

/// Figma ".field": bold label, then a 50px-tall rounded white input.
class AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String? helper;

  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: color, width: width),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: TamuColors.darkGreen)),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            enabled: enabled,
            validator: trValidator(validator),
            textCapitalization: textCapitalization,
            autofillHints: autofillHints,
            onFieldSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 15, color: TamuColors.darkGreen),
            decoration: InputDecoration(
              hintText: tr(hint),
              helperText: tr(helper),
              helperMaxLines: 2,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              suffixIcon: suffixIcon,
              border: border(const Color(0xFFCCD4CB)),
              enabledBorder: border(const Color(0xFFCCD4CB)),
              disabledBorder: border(TamuColors.line),
              focusedBorder: border(TamuColors.primary, 2),
              errorBorder: border(TamuColors.danger),
              focusedErrorBorder: border(TamuColors.danger, 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Figma ".btn-primary": full width, 52px, 15px radius.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: TamuColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}

/// Figma ".auth-switch": "New to TAMU? Create account". A Wrap, so the
/// link moves to the next line instead of overflowing with large text.
class AuthSwitchLine extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback? onTap;

  const AuthSwitchLine({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt,
            style:
                const TextStyle(fontSize: 13, color: TamuColors.textSecondary)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: TamuColors.primary,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}
