import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_model.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 🚀 ACTIVE SESSION PROVIDER
final currentStaffProvider = StreamProvider<StaffModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.phoneNumber == null) return Stream.value(null);

  final phoneStr = user.phoneNumber!.replaceAll('+91', '').trim();

  return FirebaseFirestore.instance
      .collection('staff')
      .where('phone', isEqualTo: phoneStr)
      .where('isDeleted', isEqualTo: false)
      .where('isActive', isEqualTo: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return StaffModel.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      });
});

class AuthNotifier extends Notifier<bool> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _verificationId;

  @override
  bool build() => false;

  // 1. SEND OTP WITH DB CHECK
  Future<void> sendOTP(String phoneRaw) async {
    state = true;
    try {
      final phone = phoneRaw.trim();

      // 🚀 Step 1: Backend Validation (IDT app me allow karein ya nahi)
      final staffQuery = await _db
          .collection('staff')
          .where('phone', isEqualTo: phone)
          .where('isDeleted', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (staffQuery.docs.isEmpty) {
        throw "Access Denied: Number not registered or inactive.";
      }

      // 🚀 Step 2: Firebase Phone Auth
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          // 🛡️ Custom claims (role/tenantId/branchCode) turant fresh karne ke liye
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

  // 2. VERIFY OTP
  Future<void> verifyOTP(String otp) async {
    if (_verificationId == null) throw "Please request OTP first";
    state = true;
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);
      // 🛡️ Custom claims (role/tenantId/branchCode) turant fresh karne ke liye
      await Future.delayed(const Duration(seconds: 2));
      await _auth.currentUser?.getIdToken(true);
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
