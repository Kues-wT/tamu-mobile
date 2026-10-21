import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';

/// The four photos and real height the farmer chose. Uploaded when the
/// crop is saved, so this also works for a brand-new listing.
class PhotoModelDraft {
  final List<Uint8List> photos; // front, right, back, left
  final List<String> names;
  final double heightCm;

  const PhotoModelDraft(this.photos, this.names, this.heightCm);
}

/// FR4: guided capture of 4 photos for a photo-based 3D / AR view.
/// Written for farmers who are new to smartphones: one step at a time,
/// big targets, plain words.
class PhotoModelScreen extends StatefulWidget {
  final double? suggestedHeightCm;

  const PhotoModelScreen({super.key, this.suggestedHeightCm});

  @override
  State<PhotoModelScreen> createState() => _PhotoModelScreenState();
}

class _PhotoModelScreenState extends State<PhotoModelScreen> {
  static const _steps = [
    ('Front', 'Stand in front of the crop.'),
    ('Right side', 'Walk a quarter of the way around to your right.'),
    ('Back', 'Keep walking right until you are behind it.'),
    ('Left side', 'Walk one more quarter to your right.'),
  ];

  static const _sizes = [
    (10.0, 'Small', 'like a lime or chili'),
    (25.0, 'Medium', 'like a papaya or pak choy'),
    (45.0, 'Large', 'like a jackfruit'),
  ];

  final _photos = List<Uint8List?>.filled(4, null);
  final _names = List<String>.filled(4, '');
  late double _heightCm;

  @override
  void initState() {
    super.initState();
    // Start from the chosen catalogue crop's real size when there is one.
    final s = widget.suggestedHeightCm;
    _heightCm = s == null
        ? 25
        : _sizes
              .reduce((a, b) => (a.$1 - s).abs() < (b.$1 - s).abs() ? a : b)
              .$1;
  }

  int get _nextStep => _photos.indexWhere((p) => p == null);
  bool get _done => _nextStep == -1;

  Future<void> _take(int step) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      // 1024 px is plenty for a phone screen and keeps all four photos
      // small enough to load quickly in AR.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photos[step] = bytes;
        _names[step] = picked.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: TamuColors.danger,
          content: Text('Could not open that photo. Please try again.'),
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
        foregroundColor: TamuColors.darkGreen,
        iconTheme: const IconThemeData(color: TamuColors.darkGreen),
        title: const Text(
          '3D view from photos',
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _tips(),
                const SizedBox(height: 14),
                for (var i = 0; i < 4; i++) _stepTile(i),
                const SizedBox(height: 14),
                const Text(
                  'How big is the crop?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: TamuColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Buyers will see it at this size in AR.',
                  style: TextStyle(
                    fontSize: 12,
                    color: TamuColors.textSecondary,
                  ),
                ),
                for (final s in _sizes) _sizeTile(s.$1, s.$2, s.$3),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _done
                      ? () => Navigator.of(context).pop(
                          PhotoModelDraft(
                            _photos.cast<Uint8List>(),
                            _names,
                            _heightCm,
                          ),
                        )
                      : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    _done
                        ? 'Use these photos'
                        : 'Take ${4 - _photos.where((p) => p != null).length} more photo(s)',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'TAMU joins the 4 photos into a simple 3D view when you save '
                  'the crop. It is a photo preview, not an exact 3D scan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: TamuColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tips() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: TamuColors.lightGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: TamuColors.forestDark),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Put the crop on a plain table. Keep it in the middle of the '
              'photo, and stand the same distance away each time.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: TamuColors.forestDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTile(int i) {
    final photo = _photos[i];
    final isNext = i == _nextStep;
    final (title, hint) = _steps[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: isNext ? TamuColors.primary : TamuColors.line,
            width: isNext ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _take(i),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: photo == null
                      ? Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          color: isNext
                              ? TamuColors.primary
                              : TamuColors.lightGreen,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isNext ? Colors.white : TamuColors.primary,
                            ),
                          ),
                        )
                      : Image.memory(
                          photo,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}. $title',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: TamuColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        photo == null ? hint : 'Done. Tap to retake.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: TamuColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  photo == null
                      ? Icons.photo_camera_outlined
                      : Icons.check_circle,
                  color: TamuColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeTile(double cm, String label, String example) {
    final selected = _heightCm == cm;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: selected ? const Color(0xFFFBFFFB) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? TamuColors.primary : TamuColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _heightCm = cm),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$label · about ${cm.round()} cm\n',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: TamuColors.darkGreen,
                          ),
                        ),
                        TextSpan(
                          text: example,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? TamuColors.primary
                      : const Color(0xFFBBC4BA),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
