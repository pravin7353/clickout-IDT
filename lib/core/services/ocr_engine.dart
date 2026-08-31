import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrEngine {
  // 🧠 1. MAIN FUNCTION: Image lo, Text do
  static Future<Map<String, String>> scanPacketText(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      String fullText = recognizedText.text;

      // 🚀 Regex Filters Apply Karo
      String extractedMrp = _findMRP(fullText);
      String extractedDate = _findExpiryDate(fullText);

      return {
        'fullText': fullText, // Debugging ke liye
        'mrp': extractedMrp,
        'expiryDate': extractedDate,
      };
    } catch (e) {
      throw "OCR Failed: $e";
    } finally {
      textRecognizer.close();
    }
  }

  // 💰 2. FIND MRP (Regex Magic)
  static String _findMRP(String text) {
    // Ye check karega: "MRP 150", "Rs. 45.50", "₹ 99"
    RegExp mrpRegex = RegExp(
      r'(MRP|RS\.?|₹|PRICE)\s*:?\s*(\d+(\.\d{1,2})?)',
      caseSensitive: false,
    );
    var match = mrpRegex.firstMatch(text);
    if (match != null && match.groupCount >= 2) {
      return match.group(2) ?? ''; // Sirf number return karega (e.g., "150")
    }
    return '';
  }

  // 📅 3. FIND EXPIRY DATE (Regex Magic)
  static String _findExpiryDate(String text) {
    // 🚀 ADVANCED INDIAN FORMAT MATCHER: "EXP 06 2024", "USE BY: 08/25", "06/24"
    RegExp expRegex = RegExp(
      r'(?:EXP|USE BY|BEST BEFORE|EXPIRY|MFG)[\s\S]{0,15}?(0[1-9]|1[0-2])[\s\.\-/]?(20\d{2}|\d{2})\b',
      caseSensitive: false,
    );
    var match = expRegex.firstMatch(text);
    if (match != null && match.groupCount >= 2) {
      String month = match.group(1) ?? '';
      String year = match.group(2) ?? '';

      if (year.length == 2) year = "20$year"; // Normalize to YYYY

      return "$month/$year"; // Return format: MM/YYYY
    }
    return '';
  }
}
