import 'package:flutter/material.dart';
import '../theme.dart';
import '../api_service.dart';

/// Add New Crop form.
/// Sends a real POST /products request to the FastAPI backend.
class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key});

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _farmerController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  String _category = 'vegetable';
  bool _saving = false;

  static const _categories = {
    'vegetable': '🥬 Vegetable',
    'fruit': '🍌 Fruit',
    'rice': '🌾 Rice / Grain',
    'herb': '🌿 Herb',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _farmerController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Runs every validator in the form.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final created = await ApiService.createProduct(
        name: _nameController.text.trim(),
        farmerName: _farmerController.text.trim(),
        pricePerKg: double.parse(_priceController.text.trim()),
        stockKg: int.parse(_stockController.text.trim()),
        category: _category,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TamuColors.primary,
          content: Text('${created.name} added successfully!',
              style: const TextStyle(fontSize: 16)),
        ),
      );
      // true = tell the previous screen to refresh its list.
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TamuColors.danger,
          content: Text('Could not save: $e',
              style: const TextStyle(fontSize: 14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TamuColors.background,
      appBar: AppBar(
        title: const Text('Add New Crop'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(TamuSizes.pagePadding),
                children: [
                  _buildPhotoPlaceholder(),
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

                  _label('Farmer Name'),
                  TextFormField(
                    controller: _farmerController,
                    style: const TextStyle(fontSize: 16),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Puan Siti',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter the farmer name'
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

                  _label('Price per kg (RM)'),
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

                  _label('Stock Available (kg)'),
                  TextFormField(
                    controller: _stockController,
                    style: const TextStyle(fontSize: 16),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 20',
                      suffixText: 'kg',
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
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Crop'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(false),
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

  /// Photo / AR model upload is future work - placeholder only for now.
  Widget _buildPhotoPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: TamuColors.lightGreen,
        borderRadius: BorderRadius.circular(TamuSizes.cardRadius),
        border: Border.all(
            color: TamuColors.secondary, width: 2, style: BorderStyle.solid),
      ),
      child: const Column(
        children: [
          Icon(Icons.add_a_photo_outlined, size: 36, color: TamuColors.primary),
          SizedBox(height: 8),
          Text('Photo / 3D AR Model',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 2),
          Text('Coming in a later iteration',
              style: TextStyle(fontSize: 13, color: TamuColors.textSecondary)),
        ],
      ),
    );
  }
}
