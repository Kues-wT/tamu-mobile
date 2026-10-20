import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';

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
  String? _uploadedName;      // set once a scan exists on the server
  double? _uploadedSizeKb;

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
      options[existingUnit] = '${existingUnit[0].toUpperCase()}${existingUnit.substring(1)} (existing)';
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
    _priceController =
        TextEditingController(text: e?.pricePerUnit.toStringAsFixed(2) ?? '');
    _stockController =
        TextEditingController(text: e?.stockQuantity.toString() ?? '');
    _category = e?.category ?? 'vegetable';
    _unit = e?.unit ?? 'kg';
    _availableFrom = e?.availableFrom;
    _availableUntil = e?.availableUntil;
    _modelKey = e?.modelKey;
    _uploadedName = e?.modelFile;
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

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Text(msg,
            style: const TextStyle(fontSize: 15, color: Colors.white)),
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
      helpText: isFrom ? 'When will this crop be available?' : 'Last day this crop is available',
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

  Widget _availabilityButton({required bool isFrom}) {
    final value = isFrom ? _availableFrom : _availableUntil;
    final label = isFrom ? 'Available from' : 'Available until';
    return OutlinedButton.icon(
      onPressed: () => _chooseAvailabilityDate(isFrom: isFrom),
      icon: const Icon(Icons.calendar_today_outlined, size: 18),
      label: Text(
        value == null ? label : '$label: ${_formatDate(value)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_availableFrom != null &&
        _availableUntil != null &&
        _availableUntil!.isBefore(_availableFrom!)) {
      _snack('Available until must be on or after available from.',
          TamuColors.danger);
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
      if (_isEditing) {
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
        await ApiService.createProduct(
          name: name,
          pricePerUnit: price,
          stockQuantity: stock,
          unit: _unit,
          category: _category,
          availableFrom: _availableFrom,
          availableUntil: _availableUntil,
          modelKey: _modelKey,
        );
      }

      debugPrint('SAVE: request finished OK, popping screen');

      if (!mounted) return;
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
          content: Text(e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(fontSize: 14, color: Colors.white)),
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
                  _buildScanUploader(),
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
                        fontSize: 16, color: TamuColors.textPrimary),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _categories.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  style: const TextStyle(fontSize: 16)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Sale unit'),
                  DropdownButtonFormField<String>(
                    initialValue: _unit,
                    style: const TextStyle(
                        fontSize: 16, color: TamuColors.textPrimary),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    items: _unitOptions.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  style: const TextStyle(fontSize: 16)),
                            ))
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
                            fontSize: 12, color: TamuColors.textSecondary),
                      ),
                    ),
                  const SizedBox(height: TamuSizes.gap),

                  _label('Price per $_unit (RM)'),
                  TextFormField(
                    controller: _priceController,
                    style: const TextStyle(fontSize: 16),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  Row(
                    children: [
                      Expanded(child: _availabilityButton(isFrom: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _availabilityButton(isFrom: false)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Leave dates blank for crops available immediately with no planned end date.',
                    style: TextStyle(
                        fontSize: 12, color: TamuColors.textSecondary),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: (_availableFrom == null && _availableUntil == null)
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
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isEditing ? 'Save Changes' : 'Save Crop'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel',
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
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: TamuColors.textPrimary)),
      );

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
              Icon(has ? Icons.check_circle : Icons.camera_alt_outlined,
                  size: 20,
                  color: has ? TamuColors.primary : TamuColors.textSecondary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('My Own 3D Scan',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (has)
                TextButton(
                  onPressed: _uploading ? null : _removeScan,
                  child: const Text('Remove',
                      style: TextStyle(
                          fontSize: 14, color: TamuColors.danger)),
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
                  color: TamuColors.textSecondary),
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
              label: Text(_uploading
                  ? 'Uploading...'
                  : (has ? 'Replace scan' : 'Upload .glb scan')),
            ),
        ],
      ),
    );
  }

  /// FR4: gallery of pre-loaded 3D models the farmer can attach.
  Widget _buildModelPicker() {
    return Container(
      padding: const EdgeInsets.all(TamuSizes.cardPadding),
      decoration: BoxDecoration(
        color: TamuColors.surface,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(color: TamuColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_in_ar, size: 20, color: TamuColors.primary),
              const SizedBox(width: 8),
              const Text('3D Model for AR',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_modelKey != null)
                TextButton(
                  onPressed: () => setState(() {
                    _modelKey = null;
                  }),
                  child: const Text('Clear',
                      style: TextStyle(fontSize: 14)),
                ),
            ],
          ),
          const Text(
            'Buyers can inspect this crop in 3D and place it in their room '
            'using AR. Optional.',
            style: TextStyle(fontSize: 13, color: TamuColors.textSecondary),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<ArModel>>(
            future: _modelsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const Text('Could not load the 3D model gallery.',
                    style:
                        TextStyle(fontSize: 13, color: TamuColors.danger));
              }
              final all = snapshot.data ?? [];
              // Show models for the chosen category first.
              final models = [
                ...all.where((m) => m.category == _category),
                ...all.where((m) => m.category != _category),
              ];

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: models.map((m) {
                  final selected = _modelKey == m.key;
                  return InkWell(
                    onTap: () => setState(() {
                      _modelKey = m.key;
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? TamuColors.lightGreen
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? TamuColors.primary
                              : TamuColors.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.check_circle,
                                  size: 16, color: TamuColors.primary),
                            ),
                          Text(m.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected
                                    ? TamuColors.primary
                                    : TamuColors.textPrimary,
                              )),
                          const SizedBox(width: 6),
                          Text('${m.sizeKb.toStringAsFixed(0)} KB',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: TamuColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (_modelKey == null) ...[
            const SizedBox(height: 8),
            const Text('No model selected - this crop will have no AR view.',
                style: TextStyle(
                    fontSize: 12, color: TamuColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
