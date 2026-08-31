import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/scanner_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/unknown_item_dialog.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  final Color darkBaseColor = const Color(0xFF101010);
  final Color brandGreen = const Color(0xFF16A34A);

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(scannerProvider);

    return Scaffold(
      backgroundColor: darkBaseColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Scan Inventory",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 📷 CAMERA SECTION (Top Half)
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: brandGreen, width: 2),
                boxShadow: [
                  BoxShadow(color: brandGreen.withOpacity(0.2), blurRadius: 20),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: MobileScanner(
                  controller: _cameraController,
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty &&
                        barcodes.first.rawValue != null) {
                      final scannedBarcode = barcodes.first.rawValue!;

                      // 1. Try to process it normally
                      final isKnown = await ref
                          .read(scannerProvider.notifier)
                          .processBarcode(scannedBarcode);

                      // 2. If it's UNKNOWN (returned false) and widget is still mounted
                      if (!isKnown && context.mounted) {
                        // Pause scanner so it doesn't keep firing
                        _cameraController.stop();

                        // Show the AI OCR Popup
                        final newItemData =
                            await showDialog<Map<String, dynamic>>(
                              context: context,
                              barrierDismissible:
                                  false, // Force them to handle it
                              builder: (context) =>
                                  UnknownItemDialog(barcode: scannedBarcode),
                            );

                        // If they filled it out and hit "Save to Cart"
                        // If they filled it out and hit "Save to Cart"
                        if (newItemData != null) {
                          ref
                              .read(scannerProvider.notifier)
                              .addUnknownItemToCart(newItemData);
                        }

                        // Resume scanner
                        if (context.mounted) {
                          _cameraController.start();
                        }
                      }
                    }
                  },
                ),
              ),
            ),
          ),

          // 🛒 CART SECTION (Bottom Half)
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    "Scanned Items (${cartItems.length})",
                    style: TextStyle(
                      color: brandGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // LIST OF ITEMS
                  Expanded(
                    child: cartItems.isEmpty
                        ? const Center(
                            child: Text(
                              "No items scanned yet.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            itemCount: cartItems.length,
                            itemBuilder: (context, index) {
                              final item = cartItems[index];
                              return Card(
                                color: const Color(0xFF1A1A1A),
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  title: Text(
                                    item.name,
                                    style: TextStyle(
                                      color: item.isUnknown
                                          ? Colors.redAccent
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    item.barcode,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.white54,
                                        ),
                                        onPressed: () => ref
                                            .read(scannerProvider.notifier)
                                            .decreaseQuantity(item.barcode),
                                      ),
                                      Text(
                                        "${item.quantity}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // SYNC BUTTON (Zinda ho gaya 🚀)
                  Consumer(
                    builder: (context, ref, child) {
                      final isSyncing = ref.watch(syncProvider);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24, top: 12),
                        child: ElevatedButton(
                          onPressed: (cartItems.isEmpty || isSyncing)
                              ? null
                              : () async {
                                  try {
                                    await ref
                                        .read(syncProvider.notifier)
                                        .submitDeposit();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "✅ Deposit Synced Successfully!",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      Navigator.pop(
                                        context,
                                      ); // Go back to Home Screen
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                            disabledBackgroundColor: Colors.grey.shade800,
                            minimumSize: const Size(
                              double.infinity,
                              56,
                            ), // 🚀 THE FIX
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSyncing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "SYNC DEPOSIT",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
