class IdtCartItem {
  final String barcode;
  final String name;
  final int quantity;
  final bool isUnknown;

  // 🚀 Naye Optional Fields
  final String price;
  final String unitCost;
  final String physicalStock;
  final String weight;
  final String expiryDate;
  final String hsn;
  final String gst;

  IdtCartItem({
    required this.barcode,
    required this.name,
    this.quantity = 1,
    this.isUnknown = false,
    this.price = '',
    this.unitCost = '',
    this.physicalStock = '',
    this.weight = '',
    this.expiryDate = '',
    this.hsn = '',
    this.gst = '',
  });

  IdtCartItem copyWith({
    String? barcode,
    String? name,
    int? quantity,
    bool? isUnknown,
    String? price,
    String? unitCost,
    String? physicalStock,
    String? weight,
    String? expiryDate,
    String? hsn,
    String? gst,
  }) {
    return IdtCartItem(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      isUnknown: isUnknown ?? this.isUnknown,
      price: price ?? this.price,
      unitCost: unitCost ?? this.unitCost,
      physicalStock: physicalStock ?? this.physicalStock,
      weight: weight ?? this.weight,
      expiryDate: expiryDate ?? this.expiryDate,
      hsn: hsn ?? this.hsn,
      gst: gst ?? this.gst,
    );
  }
}
