import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/staff_model.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 🚀 ACTIVE SESSION PROVIDER — streams the verified IDT staff doc
// Role filter ('idt') prevents cross-role access if same phone is
// registered under multiple roles (e.g., both 'idt' and 'cashier').
final currentStaffProvider = StreamProvider<StaffModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.phoneNumber == null) return Stream.value(null);

  final phoneStr = user.phoneNumber!.replaceAll('+91', '').trim();

  return FirebaseFirestore.instance
      .collection('staff')
      .where('phone', whereIn: [phoneStr, '+91$phoneStr'])
      .where('isDeleted', isEqualTo: false)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final match = snapshot.docs.where((d) {
          final r = (d.data()['role'] ?? '').toString().toLowerCase();
          return r == 'idt';
        }).firstOrNull;
        if (match == null) return null;
        return StaffModel.fromMap(
          match.data(),
          match.id,
        );
      });
});

class AuthNotifier extends Notifier<bool> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _verificationId;

  @override
  bool build() => false;

  // 1. SEND OTP — validates phone against 'idt' role in staff collection
  Future<void> sendOTP(String phoneRaw) async {
    state = true;
    try {
      final phone = phoneRaw.trim();

      // 🚀 Backend Validation: confirm phone is registered as active IDT staff
      final staffQuery = await _db
          .collection('staff')
          .where('phone', isEqualTo: phone)
          .where('role', isEqualTo: 'idt') // 🔒 Role-scoped pre-check
          .where('isDeleted', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (staffQuery.docs.isEmpty) {
        // Also check with +91 prefix for resilience
        final staffQueryAlt = await _db
            .collection('staff')
            .where('phone', isEqualTo: '+91$phone')
            .where('role', isEqualTo: 'idt')
            .where('isDeleted', isEqualTo: false)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (staffQueryAlt.docs.isEmpty) {
          throw "Access Denied: Number not registered as active IDT staff.";
        }
      }

      // 🚀 Firebase Phone Auth
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          await Future.delayed(const Duration(seconds: 2));
          await _auth.currentUser?.getIdToken(true);
          state = false;
        },
        verificationFailed: (FirebaseAuthException e) {
          state = false;
          throw e.message ?? "Verification failed";
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          state = false;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      state = false;
      throw e.toString();
    }
  }

  // 2. VERIFY OTP + call resolveStaffSession for session context
  Future<void> verifyOTP(String otp) async {
    if (_verificationId == null) throw "Please request OTP first";
    state = true;
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);

      // Force-refresh token so Cloud Function sees verified phone claim
      await Future.delayed(const Duration(seconds: 2));
      await _auth.currentUser?.getIdToken(true);

      // Sync UID to staff doc via resolveStaffSession (fire-and-forget is acceptable;
      // currentStaffProvider will reactively pick up the correct doc by phone anyway)
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'resolveStaffSession',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        );
        await callable.call({'role': 'idt'});
      } catch (fnErr) {
        // Non-fatal: currentStaffProvider stream still works via phone lookup
        // Log for investigation but don't block login
        // ignore: avoid_print
        print('resolveStaffSession warning (non-fatal): $fnErr');
      }
    } catch (e) {
      throw "Invalid OTP. Please try again.";
    } finally {
      state = false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}

final authProvider = NotifierProvider<AuthNotifier, bool>(() {
  return AuthNotifier();
});
