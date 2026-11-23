import 'package:flutter/material.dart' hide Text;

import '../i18n.dart';

import '../theme.dart';

/// Big - and + buttons around a number field, so a farmer can change a
/// price or stock by tapping instead of typing (examiner feedback, 4 Nov).
class NumberStepperField extends StatelessWidget {
  final TextEditingController controller;
  final Widget field;
  final double step;
  final double min;

  /// 0 for whole numbers (stock), 2 for ringgit (price).
  final int decimals;

  const NumberStepperField({
    super.key,
    required this.controller,
    required this.field,
    required this.step,
    this.min = 0,
    this.decimals = 0,
  });

  void _bump(double delta) {
    final current = double.tryParse(controller.text.trim()) ?? 0;
    var next = current + delta;
    if (next < min) next = min;
    controller.text = decimals == 0
        ? next.round().toString()
        : next.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StepButton(
          icon: Icons.remove,
          tooltip: 'Decrease',
          onPressed: () => _bump(-step),
        ),
        const SizedBox(width: 8),
        Expanded(child: field),
        const SizedBox(width: 8),
        StepButton(
          icon: Icons.add,
          tooltip: 'Increase',
          onPressed: () => _bump(step),
        ),
      ],
    );
  }
}

/// A large round - or + button, easy to hit for older users.
class StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  const StepButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton.filledTonal(
        tooltip: tr(tooltip),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: TamuColors.lightGreen,
          foregroundColor: TamuColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 26),
      ),
    );
  }
}
