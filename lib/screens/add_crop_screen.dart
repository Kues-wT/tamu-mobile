import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import '../api_service.dart';
import '../widgets/crop_photo.dart';
import 'crop_model_picker_screen.dart';
import 'photo_model_screen.dart';

/// Add a new crop, or edit an existing one.
/// Pass `existing` to switch the form into edit mode.
class AddCropScreen extends StatefulWidget {
  final Product? existing;
  const AddCropScreen({super.key, this.existing});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  late String _category;
  late String _unit;
  DateTime? _availableFrom;
  DateTime? _availableUntil;
  bool _saving = false;

  // FR4: chosen 3D model, and the catalogue loaded from the backend.
  String? _modelKey;
  late Future<List<ArModel>> _modelsFuture;

  // FR4: the farmer's own photogrammetry scan.
  bool _uploading = false;
  String? _uploadedName; // set once a scan exists on the server
  double? _uploadedSizeKb;

  // FR2: crop photo. A new pick is held here and uploaded on Save.
  Uint8List? _newPhotoBytes;
  String? _newPhotoName;
  bool _removePhoto = false;

  // FR4: 4-photo 3D view. A new draft uploads on Save.
  PhotoModelDraft? _photoModelDraft;
  bool _hasPhotoModel = false; // already on the server

  String? get _existingPhotoUrl =>
      _removePhoto ? null : widget.existing?.photoUrl;
  bool get _hasPhoto => _newPhotoBytes != null || _existingPhotoUrl != null;

  bool get _isEditing => widget.existing != null;
  String get _unitPlural => formatUnitQuantity(2, _unit).split(' ').last;

  static const _units = {
    'kg': 'Kilogram (kg)',
    'bunch': 'Bunch',
    'piece': 'Pieces',
  };

  Map<String, String> get _unitOptions {
    final options = Map<String, String>.from(_units);
    final existingUnit = widget.existing?.unit;
    if (existingUnit != null &&
        existingUnit.isNotEmpty &&
        !options.containsKey(existingUnit)) {
      options[existingUnit] =
          '${existingUnit[0].toUpperCase()}${existingUnit.substring(1)} (existing)';
    }
    return options;
  }

  static const _categories = {
    'vegetable': '🥬 Vegetable',
    'fruit': '🍌 Fruit',
    'rice': '🌾 Rice / Grain',
    'herb': '🌿 Herb',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _priceController = TextEditingController(
      text: e?.pricePerUnit.toStringAsFixed(2) ?? '',
    );
    _stockController = TextEditingController(
      text: e?.stockQuantity.toString() ?? '',
    );
    _category = e?.category ?? 'vegetable';
    _unit = e?.unit ?? 'kg';
    _availableFrom = e?.availableFrom;
    _availableUntil = e?.availableUntil;
    _modelKey = e?.modelKey;
    // A photo-built model shares the model file slot with an uploaded
    // .glb, so only treat it as a "scan" when it is not photo-built.
    _hasPhotoModel = e?.hasPhotoModel ?? false;
    _uploadedName = _hasPhotoModel ? null : e?.modelFile;
    _modelsFuture = ApiService.fetchArModels();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  /// Picks a .glb exported from a photogrammetry app and uploads it.
  /// Only possible once the crop exists, because the file is attached
  /// to a product id.
  Future<void> _pickAndUploadScan() async {
    if (!_isEditing) {
      _snack(
        'Save the crop first, then you can upload your 3D scan.',
        TamuColors.warning,
      );
      return;
    }

    // file_picker v12+ uses static methods and returns PlatformFile
    // directly. Bytes are read with readAsBytes(), which also works on web.
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['glb'],
    );
    if (picked == null) return;

    final List<int> bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      _snack('Could not read that file.', TamuColors.danger);
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final res = await ApiService.uploadProductModel(
        productId: widget.existing!.id,
        filename: picked.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadedName = res.filename;
        _uploadedSizeKb = res.sizeKb;
      });
      _snack(
        res.warning ?? 'Your 3D scan was uploaded successfully!',
        res.warning == null ? TamuColors.primary : TamuColors.warning,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
      });
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  Future<void> _removeScan() async {
    if (!_isEditing || _uploadedName == null) return;
    try {
      await ApiService.deleteProductModel(widget.existing!.id);
      if (!mounted) return;
      setState(() {
        _uploadedName = null;
        _uploadedSizeKb = null;
      });
      _snack('3D scan removed.', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  /// FR2: camera or gallery. The picker shrinks the photo first so the
  /// upload stays small on mobile data (well under the 5 MB limit).
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
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
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newPhotoBytes = bytes;
        _newPhotoName = picked.name;
        _removePhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      _snack('Could not open that photo. Try another one.', TamuColors.danger);
    }
  }

  void _clearPhoto() {
    setState(() {
      _newPhotoBytes = null;
      _newPhotoName = null;
      _removePhoto = widget.existing?.photoUrl != null;
    });
  }

  /// Uploads or removes the photo after the crop itself is saved.
  /// Returns an error message, or null when everything went fine.
  Future<String?> _syncPhoto(int productId) async {
    try {
      if (_newPhotoBytes != null) {
        await ApiService.uploadProductPhoto(
          productId: productId,
          filename: _newPhotoName ?? 'crop.jpg',
          bytes: _newPhotoBytes!,
        );
      } else if (_removePhoto) {
        await ApiService.deleteProductPhoto(productId);
      }
      final draft = _photoModelDraft;
      if (draft != null) {
        await ApiService.createPhotoModel(
          productId: productId,
          photos: draft.photos,
          names: draft.names,
          heightCm: draft.heightCm,
        );
      }
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(
          msg,
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) =>
      MaterialLocalizations.of(context).formatMediumDate(value);

  Future<void> _chooseAvailabilityDate({required bool isFrom}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final current = isFrom ? _availableFrom : _availableUntil;
    var initial = current ?? today;
    if (initial.isBefore(today)) initial = today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
      helpText: isFrom
          ? 'When will this crop be available?'
          : 'Last day this crop is available',
    );
    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _availableFrom = DateUtils.dateOnly(picked);
      } else {
        _availableUntil = DateUtils.dateOnly(picked);
      }
    });
  }

  /// Full-width date box: label on top, the chosen date underneath, so
  /// the whole date is readable on a narrow phone.
  Widget _availabilityButton({required bool isFrom}) {
    final value = isFrom ? _availableFrom : _availableUntil;
    final label = isFrom ? 'Available from' : 'Available until';
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: value == null ? TamuColors.border : TamuColors.primary,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _chooseAvailabilityDate(isFrom: isFrom),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: TamuColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TamuColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value == null
                          ? 'Tap to choose a date'
                          : _formatDate(value),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: value == null
                            ? FontWeight.w400
                            : FontWeight.w700,
                        color: value == null
                            ? TamuColors.hint
                            : TamuColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: TamuColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_availableFrom != null &&
        _availableUntil != null &&
        _availableUntil!.isBefore(_availableFrom!)) {
      _snack(
        'Available until must be on or after available from.',
        TamuColors.danger,
      );
      return;
    }

    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final price = double.parse(_priceController.text.trim());
    final stock = int.parse(_stockController.text.trim());

    // These prints show up in the Flutter terminal / DevTools console
    // so we can see exactly how far the save gets.
    debugPrint('SAVE: starting request for "$name"');

    try {
      final int productId;
      if (_isEditing) {
        productId = widget.existing!.id;
        await ApiService.updateProduct(
          id: widget.existing!.id,
          name: name,
          pricePerUnit: price,
          stockQuantity: stock,
          unit: _unit,
          category: _category,
          availableFrom: _availableFrom,
          availableUntil: _availableUntil,
          modelKey: _modelKey,
        );
      } else {
        final created = await ApiService.createProduct(
          name: name,
          pricePerUnit: price,
          stockQuantity: stock,
          unit: _unit,
          category: _category,
          availableFrom: _availableFrom,
          availableUntil: _availableUntil,
          modelKey: _modelKey,
        );
        productId = created.id;
      }

      // The crop is saved either way; a photo problem must not make the
      // farmer save again (which would create a duplicate listing).
      final photoError = await _syncPhoto(productId);

      debugPrint('SAVE: request finished OK, popping screen');

      if (!mounted) return;
      if (photoError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TamuColors.warning,
            content: Text(
              'Crop saved, but the photos were not uploaded: $photoError',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        );
      }
      // Hand the result back. The dashboard shows the success message,
      // so nothing is attached to this screen while it is closing.
      Navigator.of(context).pop(name);
    } catch (e) {
      debugPrint('SAVE: FAILED -> $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TamuColors.danger,
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(title: Text(_isEditing ? 'Edit Crop' : 'Add New Crop')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(TamuSizes.pagePadding),
                children: [
                  _buildPhotoPicker(),
                  const SizedBox(height: 20),
                  Theme(
                    // No divider lines around the collapsed section.
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      initiallyExpanded: _uploadedName != null,
                      title: const Text(
                        'Advanced (optional): upload your own 3D file',
                        style: TextStyle(
                          fontSize: 14,
                          color: TamuColors.textSecondary,
                        ),
                      ),
                      children: [_buildScanUploader()],
                    ),
                  ),
                  const SizedBox(height: TamuSizes.gap),
                  _buildModelPicker(),
                  const SizedBox(height: 20),

                  _label('Crop Name'),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 16),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Pak Choy',
                      prefixIcon: Icon(Icons.eco_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter the crop name'
                        : null,
                  ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Category'),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    style: const TextStyle(
                      fontSize: 16,
                      color: TamuColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _categories.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Sale unit'),
                  DropdownButtonFormField<String>(
                    initialValue: _unit,
                    style: const TextStyle(
                      fontSize: 16,
                      color: TamuColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    items: _unitOptions.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _unit = v);
                    },
                  ),
                  if (_isEditing)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        'Changing the unit changes how the existing price and stock count are interpreted.',
                        style: TextStyle(
                          fontSize: 12,
                          color: TamuColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Price per $_unit (RM)'),
                  TextFormField(
                    controller: _priceController,
                    style: const TextStyle(fontSize: 16),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 3.50',
                      prefixText: 'RM ',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a price';
                      }
                      final n = double.tryParse(v.trim());
                      if (n == null) return 'Numbers only, e.g. 3.50';
                      if (n <= 0) return 'Price must be more than 0';
                      return null;
                    },
                  ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Stock available ($_unitPlural)'),
                  TextFormField(
                    controller: _stockController,
                    style: const TextStyle(fontSize: 16),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g. 20',
                      suffixText: _unitPlural,
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter the stock quantity';
                      }
                      final n = int.tryParse(v.trim());
                      if (n == null) return 'Whole numbers only, e.g. 20';
                      if (n < 0) return 'Stock cannot be negative';
                      return null;
                    },
                  ),
                  const SizedBox(height: TamuSizes.gap),
                  _label('Crop Availability (optional)'),
                  _availabilityButton(isFrom: true),
                  const SizedBox(height: 8),
                  _availabilityButton(isFrom: false),
                  const SizedBox(height: 4),
                  const Text(
                    'Leave dates blank for crops available immediately with no planned end date.',
                    style: TextStyle(
                      fontSize: 12,
                      color: TamuColors.textSecondary,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed:
                          (_availableFrom == null && _availableUntil == null)
                          ? null
                          : () => setState(() {
                              _availableFrom = null;
                              _availableUntil = null;
                            }),
                      child: const Text('Clear dates'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Save Crop'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: TamuColors.textSecondary,
                      ),
                    ),
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
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: TamuColors.textPrimary,
      ),
    ),
  );

  /// FR2: Figma ".photo-upload" box, or a preview with Change / Remove.
  Widget _buildPhotoPicker() {
    if (!_hasPhoto) {
      return Material(
        color: TamuColors.lightGreen,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _saving ? null : _pickPhoto,
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA8B8A7), width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  size: 28,
                  color: TamuColors.primary,
                ),
                SizedBox(width: 10),
                // Flexible lets the text wrap instead of overflowing.
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add crop photo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: TamuColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Optional · helps buyers trust your listing',
                        style: TextStyle(
                          fontSize: 12,
                          color: TamuColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _newPhotoBytes != null
              ? Image.memory(
                  _newPhotoBytes!,
                  height: 180,
                  fit: BoxFit.cover,
                  semanticLabel: 'New crop photo',
                )
              : CropPhoto(
                  photoUrl: _existingPhotoUrl,
                  category: _category,
                  height: 180,
                  radius: 0,
                  emojiSize: 60,
                ),
        ),
        if (_newPhotoBytes != null)
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text(
              'New photo · uploads when you save',
              style: TextStyle(fontSize: 12, color: TamuColors.textSecondary),
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: _saving ? null : _pickPhoto,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Change photo'),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _saving ? null : _clearPhoto,
              style: TextButton.styleFrom(foregroundColor: TamuColors.danger),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }

  /// FR4: upload a real photogrammetry scan of this crop.
  Widget _buildScanUploader() {
    final has = _uploadedName != null;

    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: has ? TamuColors.lightGreen : TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(
          color: has ? TamuColors.primary : TamuColors.border,
          width: has ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                has ? Icons.check_circle : Icons.camera_alt_outlined,
                size: 20,
                color: has ? TamuColors.primary : TamuColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'My Own 3D Scan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (has)
                TextButton(
                  onPressed: _uploading ? null : _removeScan,
                  child: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 14, color: TamuColors.danger),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (has) ...[
            Text(
              _uploadedSizeKb == null
                  ? 'A scan of your real crop is attached. Buyers will see '
                        'this instead of the gallery model.'
                  : 'Scan attached (${_uploadedSizeKb!.toStringAsFixed(0)} KB). '
                        'Buyers will see this instead of the gallery model.',
              style: const TextStyle(fontSize: 13),
            ),
          ] else ...[
            const Text(
              'Photograph your actual crop with a free scanning app, then '
              'upload the .glb file here.',
              style: TextStyle(fontSize: 13, color: TamuColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'How to make a scan:\n'
                '1. Install KIRI Engine or RealityScan (both free)\n'
                '2. Walk around your crop taking photos from all sides\n'
                '3. Wait for processing, then export as GLB\n'
                '4. Come back here and upload the file (max 10 MB)',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!_isEditing)
            const Text(
              'Save this crop first, then reopen it to upload a scan.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: TamuColors.textSecondary,
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickAndUploadScan,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(
                _uploading
                    ? 'Uploading...'
                    : (has ? 'Replace scan' : 'Upload .glb scan'),
              ),
            ),
        ],
      ),
    );
  }

  /// FR4: gallery of pre-loaded 3D models the farmer can attach.
  Future<void> _takeModelPhotos(double? suggestedHeightCm) async {
    final draft = await Navigator.of(context).push<PhotoModelDraft>(
      MaterialPageRoute(
        builder: (_) => PhotoModelScreen(suggestedHeightCm: suggestedHeightCm),
      ),
    );
    if (draft != null && mounted) setState(() => _photoModelDraft = draft);
  }

  Future<void> _removePhotoModel() async {
    try {
      await ApiService.deleteProductModel(widget.existing!.id);
      if (!mounted) return;
      setState(() => _hasPhotoModel = false);
      _snack('Photo 3D view removed.', TamuColors.primary);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), TamuColors.danger);
    }
  }

  /// "Your real crop" option at the top of the 3D / AR card.
  Widget _buildPhotoModelOption(double? suggestedHeightCm) {
    final draft = _photoModelDraft;
    final String title;
    final String detail;
    if (draft != null) {
      title = '4 photos ready';
      detail =
          'About ${draft.heightCm.round()} cm. The 3D view is made '
          'when you save.';
    } else if (_hasPhotoModel) {
      title = 'Your photo 3D view is on';
      detail = 'Buyers see your own crop in AR.';
    } else {
      title = 'Take 4 photos of your crop';
      detail = 'Best: buyers see your real crop in AR.';
    }
    final has = draft != null || _hasPhotoModel;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: has ? TamuColors.lightGreen : const Color(0xFFFBFFFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TamuColors.paleBorder),
      ),
      child: Row(
        children: [
          Icon(
            has ? Icons.check_circle : Icons.photo_camera_outlined,
            color: TamuColors.primary,
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TamuColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (draft != null)
            IconButton(
              tooltip: 'Remove these photos',
              onPressed: () => setState(() => _photoModelDraft = null),
              icon: const Icon(Icons.close, color: TamuColors.textSecondary),
            )
          else if (_hasPhotoModel)
            IconButton(
              tooltip: 'Remove photo 3D view',
              onPressed: _removePhotoModel,
              icon: const Icon(Icons.delete_outline, color: TamuColors.danger),
            ),
          TextButton(
            onPressed: () => _takeModelPhotos(suggestedHeightCm),
            child: Text(has ? 'Retake' : 'Start'),
          ),
        ],
      ),
    );
  }

  /// FR4: opens the searchable life-size crop list, starting from the
  /// crop name the farmer typed.
  Future<void> _chooseModel(List<ArModel> models) async {
    final key = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CropModelPickerScreen(
          models: models,
          initialQuery: _nameController.text.trim(),
          selectedKey: _modelKey,
        ),
      ),
    );
    if (key != null && mounted) setState(() => _modelKey = key);
  }

  Widget _buildModelPicker() {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: FutureBuilder<List<ArModel>>(
        future: _modelsFuture,
        builder: (context, snapshot) {
          final models = snapshot.data ?? const <ArModel>[];
          ArModel? chosen;
          for (final m in models) {
            if (m.key == _modelKey) chosen = m;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.view_in_ar, size: 20, color: TamuColors.primary),
                  SizedBox(width: 8),
                  Text(
                    '3D / AR view',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Let buyers see your crop life-size on their table with AR. '
                'Optional.',
                style: TextStyle(fontSize: 13, color: TamuColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _buildPhotoModelOption(chosen?.sizeCm),
              const SizedBox(height: 10),
              Text(
                _photoModelDraft != null || _hasPhotoModel
                    ? 'Ready-made model (used if your photos are removed):'
                    : 'Or pick a ready-made 3D crop:',
                style: const TextStyle(
                  fontSize: 13,
                  color: TamuColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                const Text(
                  'Could not load the crop list. Check your connection.',
                  style: TextStyle(fontSize: 13, color: TamuColors.danger),
                )
              else ...[
                if (chosen != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TamuColors.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          CropPhoto.emojiFor(chosen.category),
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chosen.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Life-size in AR · about '
                                '${chosen.sizeCm?.round() ?? '?'} cm',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: TamuColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove 3D model',
                          onPressed: () => setState(() => _modelKey = null),
                          icon: const Icon(
                            Icons.close,
                            color: TamuColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: models.isEmpty ? null : () => _chooseModel(models),
                  icon: Icon(chosen == null ? Icons.search : Icons.swap_horiz),
                  label: Text(
                    chosen == null
                        ? 'Choose crop 3D model'
                        : 'Change crop model',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
