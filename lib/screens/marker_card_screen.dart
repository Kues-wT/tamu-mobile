import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ar_support.dart';
import '../theme.dart';

/// FR4: the TAMU card that marker AR stands the crop on. Shows the card
/// and explains how to print it at its true size.
class MarkerCardScreen extends StatelessWidget {
  const MarkerCardScreen({super.key});

  Future<void> _openPrintable(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(ArSupport.printableCardUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: TamuColors.danger,
          content: Text('Could not open the printable card.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cm = ArSupport.markerCm.round();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: TamuColors.darkGreen,
        iconTheme: const IconThemeData(color: TamuColors.darkGreen),
        title: const Text(
          'TAMU AR card',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: TamuColors.darkGreen,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // White margin around the black frame is part of the card.
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Image.asset(
                    'assets/ar/tamu_marker.png',
                    semanticLabel: 'TAMU AR card',
                    filterQuality: FilterQuality.none,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Print it on A4 paper at "Actual size" (100%). The black '
                  'square must measure $cm cm, so crops appear at their real '
                  'size.',
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lay the card flat on a table with good light. You can also '
                  'show it on another screen, but then the size is only '
                  'approximate.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: TamuColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _openPrintable(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Open printable A4 card'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
