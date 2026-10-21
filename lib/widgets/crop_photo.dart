import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme.dart';

/// FR2: a crop's photo, or the category emoji tile when there is none
/// (older listings, or the photo failed to load). Used everywhere a crop
/// is shown so there is never a broken image.
class CropPhoto extends StatelessWidget {
  final String? photoUrl;
  final String? category;
  final double? width;
  final double height;
  final double radius;
  final double emojiSize;
  // cover = fill the box (thumbnails); contain = whole photo visible.
  final BoxFit fit;

  const CropPhoto({
    super.key,
    required this.photoUrl,
    this.category,
    this.width,
    required this.height,
    this.radius = 11,
    this.emojiSize = 30,
    this.fit = BoxFit.cover,
  });

  static String emojiFor(String? category) => switch (category) {
        'vegetable' => '🥬',
        'fruit' => '🍌',
        'rice' => '🌾',
        'herb' => '🌿',
        _ => '🌱',
      };

  @override
  Widget build(BuildContext context) {
    final url = resolveServerUrl(photoUrl);
    final placeholder = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: TamuColors.lightGreen,
      child: Text(emojiFor(category), style: TextStyle(fontSize: emojiSize)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url,
              width: width,
              height: height,
              fit: fit,
              semanticLabel: 'Crop photo',
              // Decode at display size, not full camera size, to save memory.
              cacheWidth: width == null
                  ? null
                  : (width! * MediaQuery.devicePixelRatioOf(context)).round(),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      width: width,
                      height: height,
                      color: TamuColors.lightGreen,
                    ),
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
