import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/ocr_engine.dart'; // Apna naya engine path check kar lena

class UnknownItemDialog extends StatefulWidget {
  final String barcode;
  const UnknownItemDialog({Key? key, required this.barcode}) : super(key: key);

  @override
  State<UnknownItemDialog> createState() => _UnknownItemDialogState();
}

class _UnknownItemDialogState extends State<UnknownItemDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  // 🚀 Naye Controllers
  final TextEditingController _unitCostController = TextEditingController();
  final TextEditingController _physicalStockController =
      TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _hsnController = TextEditingController();

  String _selectedGst = "18"; // 🚀 Premium Dropdown Default
  final List<String> _gstSlabs = ["0", "5", "12", "18", "28"];

  bool _isScanningText = false; // Loading animation ke liye

  // 🚀 YE RAHA AAPKA OCR WALA CODE
  Future<void> _scanPacketForDetails() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() => _isScanningText = true); // Loading chalu

      try {
        final extractedData = await OcrEngine.scanPacketText(photo.path);

        // Form controllers me text daal do
        setState(() {
          if (extractedData['mrp']!.isNotEmpty) {
            _priceController.text = extractedData['mrp']!;
          }
          if (extractedData['expiryDate']!.isNotEmpty) {
            _expiryController.text = extractedData['expiryDate']!;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Auto-filled from packet! ✅"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint(e.toString());
      } finally {
        setState(() => _isScanningText = false); // Loading band
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _expiryController.dispose();
    _unitCostController.dispose();
    _physicalStockController.dispose();
    _weightController.dispose();
    _hsnController.dispose();
    super.dispose();
  }

  // 🚀 Helper for Premium Fields
  Widget _buildPremiumField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: Colors.grey, size: 18),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A), // Dark Theme
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("New Item Found", style: TextStyle(color: Colors.white)),
          Text(
            "Barcode: ${widget.barcode}",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🤖 AI SCAN BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                ),
                onPressed: _isScanningText ? null : _scanPacketForDetails,
                icon: _isScanningText
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner),
                label: Text(
                  _isScanningText
                      ? "Scanning Packet..."
                      : "AI Auto-Fill (Scan Packet)",
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 🚀 PREMIUM FORM FIELDS
            _buildPremiumField(
              _nameController,
              'Product Name *',
              Icons.inventory_2_outlined,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildPremiumField(
                    _priceController,
                    'MRP (₹)',
                    Icons.currency_rupee,
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPremiumField(
                    _unitCostController,
                    'Unit Cost (₹)',
                    Icons.account_balance_wallet_outlined,
                    isNumber: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildPremiumField(
                    _physicalStockController,
                    'Physical Stock',
                    Icons.layers_outlined,
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPremiumField(
                    _weightController,
                    'Weight/Vol',
                    Icons.scale_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildPremiumField(
                    _hsnController,
                    'HSN Code',
                    Icons.tag,
                  ),
                ),
                const SizedBox(width: 10),
                // 🚀 PREMIUM GST DROPDOWN
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGst,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'GST Slab (%)',
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      filled: true,
                      fillColor: Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.percent,
                        color: Colors.grey,
                        size: 18,
                      ),
                      isDense: true,
                    ),
                    items: _gstSlabs
                        .map(
                          (String slab) => DropdownMenuItem<String>(
                            value: slab,
                            child: Text("$slab% GST"),
                          ),
                        )
                        .toList(),
                    onChanged: (String? newValue) =>
                        setState(() => _selectedGst = newValue!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 🚀 PREMIUM AUTO-SLASH EXPIRY FIELD
            TextField(
              controller: _expiryController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
                _ExpiryDateFormatter(),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Expiry Date (MM/YYYY)',
                hintText: 'MM/YYYY',
                hintStyle: TextStyle(color: Colors.white24),
                labelStyle: TextStyle(color: Colors.grey, fontSize: 13),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.calendar_month,
                  color: Colors.grey,
                  size: 18,
                ),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            final newItemData = {
              'barcode': widget.barcode,
              'name': _nameController.text.isNotEmpty
                  ? _nameController.text
                  : 'UNKNOWN ITEM',
              'price': _priceController.text,
              'unitCost': _unitCostController.text,
              'physicalStock': _physicalStockController.text,
              'weight': _weightController.text,
              'expiryDate': _expiryController.text,
              'hsn': _hsnController.text,
              'gst': _selectedGst, // 🚀 Fixed Dropdown Value
            };
            Navigator.pop(context, newItemData);
          },
          child: const Text(
            "SAVE TO CART",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// 🚀 CUSTOM FORMATTER: Auto add "/" after MM
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length >= 3 && !text.contains('/')) {
      final newText = '${text.substring(0, 2)}/${text.substring(2)}';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    return newValue;
  }
}
