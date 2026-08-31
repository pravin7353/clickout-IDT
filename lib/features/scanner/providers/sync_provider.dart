import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scanner_provider.dart';
import '../../auth/providers/auth_controller.dart';

class SyncNotifier extends Notifier<bool> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  bool build() => false;

  Future<void> submitDeposit() async {
    state = true;
    try {
      final cartItems = ref.read(scannerProvider);
      final staff = ref.read(currentStaffProvider).value;

      if (cartItems.isEmpty) throw "Cart is empty!";
      if (staff == null) throw "Session expired!";

      // Convert cart to map
      List<Map<String, dynamic>> itemsMap = cartItems
          .map(
            (e) => {
              'barcode': e.barcode,
              'name': e.name,
              'quantity': e.quantity,
              'isUnknown': e.isUnknown,
              // 🚀 Extra data admin ke liye push kar rahe hain
              'price': e.price,
              'unitCost': e.unitCost,
              'physicalStock': e.physicalStock,
              'weight': e.weight,
              'expiryDate': e.expiryDate,
              'hsn': e.hsn,
              'gst': e.gst,
            },
          )
          .toList();

      final depositRef = _db.collection('idt_deposits').doc();

      await depositRef.set({
        'depositId': depositRef.id,
        'tenantId': staff.tenantId,
        'storeId': staff.storeId,
        'branchCode': staff.branchCode,
        'scannedByStaffId': staff.staffId, // 🚀 FIX: Admin schema match!
        'scannedByEmpId': staff.empId, // (GAR001 type ref ke liye)
        'scannedByName': staff.name,
        'totalItems': cartItems.length,
        'items': itemsMap,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'VERIFIED',
      });

      // Clear the cart after successful sync
      ref.read(scannerProvider.notifier).clearCart();
    } catch (e) {
      throw e.toString();
    } finally {
      state = false;
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, bool>(() {
  return SyncNotifier();
});
