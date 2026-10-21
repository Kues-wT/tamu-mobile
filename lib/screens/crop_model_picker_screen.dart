import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../theme.dart';
import '../api_service.dart';
import '../widgets/crop_photo.dart';

/// FR4: farmer picks a ready-made, life-size 3D crop for AR.
/// Searchable in English or Malay; tapping a crop shows a 3D preview
/// before it is chosen. Returns the chosen model key.
class CropModelPickerScreen extends StatefulWidget {
  final List<ArModel> models;
  final String initialQuery;
  final String? selectedKey;

  const CropModelPickerScreen({
    super.key,
    required this.models,
    this.initialQuery = '',
    this.selectedKey,
  });

  @override
  State<CropModelPickerScreen> createState() => _CropModelPickerScreenState();
}

class _CropModelPickerScreenState extends State<CropModelPickerScreen> {
  late final TextEditingController _search;
  String _category = 'all';

  static const _categories = {
    'all': 'All',
    'fruit': 'Fruits',
    'vegetable': 'Vegetables',
    'herb': 'Herbs & spices',
    'other': 'Rice & other',
  };

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    // If the crop name finds nothing (e.g. a typo), start with the full list.
    if (_filtered.isEmpty) _search.clear();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ArModel> get _filtered {
    final q = _search.text.trim();
    return widget.models.where((m) {
      final inCategory =
          _category == 'all' ||
          m.category == _category ||
          (_category == 'other' &&
              (m.category == 'rice' || m.category == 'other'));
      return inCategory && (q.isEmpty || m.matches(q));
    }).toList();
  }

  Future<void> _preview(ArModel m) async {
    final chosen = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                m.label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: TamuColors.darkGreen,
                ),
              ),
              if (m.malay != null)
                Text(
                  m.malay!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: TamuColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 260,
                  child: ModelViewer(
                    src: m.url,
                    alt: '3D model of ${m.label}',
                    autoRotate: true,
                    cameraControls: true,
                    backgroundColor: const Color(0xFFEEF3EC),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Drag to turn it around. Buyers see it life-size '
                '(about ${m.sizeCm?.round() ?? '?'} cm) in AR.',
                style: const TextStyle(
                  fontSize: 12,
                  color: TamuColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
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
                icon: const Icon(Icons.check),
                label: const Text('Use this model'),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == true && mounted) Navigator.of(context).pop(m.key);
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: TamuColors.warm,
      appBar: AppBar(
        backgroundColor: TamuColors.warm,
        surfaceTintColor: Colors.transparent,
        foregroundColor: TamuColors.darkGreen,
        iconTheme: const IconThemeData(color: TamuColors.darkGreen),
        title: const Text(
          'Choose your crop',
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search, e.g. durian, nangka, ubi',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_search.clear),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final e in _categories.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _category == e.key,
                            showCheckmark: false,
                            selectedColor: TamuColors.darkGreen,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _category == e.key
                                  ? Colors.white
                                  : TamuColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                            side: BorderSide(
                              color: _category == e.key
                                  ? TamuColors.darkGreen
                                  : TamuColors.line,
                            ),
                            onSelected: (_) =>
                                setState(() => _category = e.key),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No crop found. Try another name, or choose '
                              '"Mixed produce basket" under Rice & other.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: TamuColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _tile(list[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(ArModel m) {
    final selected = m.key == widget.selectedKey;
    return Material(
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
        onTap: () => _preview(m),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TamuColors.lightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  CropPhoto.emojiFor(m.category),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: TamuColors.darkGreen,
                      ),
                    ),
                    if (m.malay != null)
                      Text(
                        m.malay!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: TamuColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${m.sizeCm?.round() ?? ''} cm',
                style: const TextStyle(
                  fontSize: 12,
                  color: TamuColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                selected ? Icons.check_circle : Icons.view_in_ar,
                color: TamuColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
