import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/idt_cart_model.dart';
import '../../auth/providers/auth_controller.dart';

class ScannerNotifier extends Notifier<List<IdtCartItem>> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool isProcessing = false; // To prevent double scans

  @override
  List<IdtCartItem> build() => [];

  // 🚀 UPDATE THIS METHOD SIGNATURE AND LOGIC
  Future<bool> processBarcode(String barcode) async {
    // Changed void to Future<bool>
    if (isProcessing) return true; // Pretend handled to block spam

    final cleanBarcode = barcode.trim().toUpperCase();
    if (cleanBarcode.isEmpty) return false;

    isProcessing = true;

    try {
      final existingIndex = state.indexWhere(
        (item) => item.barcode == cleanBarcode,
      );

      if (existingIndex >= 0) {
        final updatedList = [...state];
        updatedList[existingIndex] = updatedList[existingIndex].copyWith(
          quantity: updatedList[existingIndex].quantity + 1,
        );
        state = updatedList;
        return true; // Item handled successfully
      } else {
        final staff = ref.read(currentStaffProvider).value;
        if (staff == null) throw "Session Expired!";

        final docId = '${staff.tenantId}_${staff.branchCode}_$cleanBarcode';
        final docSnap = await _db.collection('products').doc(docId).get();

        if (docSnap.exists) {
          final data = docSnap.data()!;
          state = [
            ...state,
            IdtCartItem(
              barcode: cleanBarcode,
              name: data['name'] ?? 'Unknown Product',
              quantity: 1,
              isUnknown: false,
            ),
          ];
          return true; // Item handled successfully
        } else {
          // 🚨 ITEM NOT FOUND IN MASTER!
          return false; // Return false so the UI knows to show the popup!
        }
      }
    } catch (e) {
      print("Scan Error: $e");
      return true; // Return true to prevent spamming errors
    } finally {
      await Future.delayed(const Duration(milliseconds: 800));
      isProcessing = false;
    }
  }

  // ➖ DECREASE QUANTITY
  void decreaseQuantity(String barcode) {
    final existingIndex = state.indexWhere((item) => item.barcode == barcode);
    if (existingIndex >= 0) {
      final item = state[existingIndex];
      final updatedList = [...state];
      if (item.quantity > 1) {
        updatedList[existingIndex] = item.copyWith(quantity: item.quantity - 1);
      } else {
        updatedList.removeAt(existingIndex); // Remove if qty hits 0
      }
      state = updatedList;
    }
  }

  // 🚀 UPDATE: Accept full Map from Dialog
  void addUnknownItemToCart(Map<String, dynamic> data) {
    final existingIndex = state.indexWhere(
      (item) => item.barcode == data['barcode'],
    );

    if (existingIndex >= 0) {
      final updatedList = [...state];
      updatedList[existingIndex] = updatedList[existingIndex].copyWith(
        quantity: updatedList[existingIndex].quantity + 1,
      );
      state = updatedList;
    } else {
      state = [
        ...state,
        IdtCartItem(
          barcode: data['barcode'] ?? '',
          name: data['name'] ?? 'UNKNOWN ITEM',
          quantity:
              int.tryParse(data['physicalStock'] ?? '1') ??
              1, // Agar stock dala hai toh utni quantity ban jayegi!
          isUnknown: true,
          price: data['price'] ?? '',
          unitCost: data['unitCost'] ?? '',
          physicalStock: data['physicalStock'] ?? '',
          weight: data['weight'] ?? '',
          expiryDate: data['expiryDate'] ?? '',
          hsn: data['hsn'] ?? '',
          gst: data['gst'] ?? '',
        ),
      ];
    }
  }

  void clearCart() {
    state = [];
  }
}

final scannerProvider = NotifierProvider<ScannerNotifier, List<IdtCartItem>>(
  () {
    return ScannerNotifier();
  },
);
