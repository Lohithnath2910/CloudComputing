import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class NfcService {
  /// Reads the UID of an NFC card.
  /// Returns null if no card is detected or if an error occurs.
  static Future<String?> readCardUid() async {
    // Use random UID in debug/emulator mode
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final tag = await FlutterNfcKit.poll(timeout: const Duration(seconds: 10));
        await FlutterNfcKit.finish(); // stop polling after reading
        return tag.id; // actual NFC UID
      } catch (e) {
        debugPrint('NFC read error: $e');
        return null;
      }
    } else {
      // Emulator or unsupported platform: generate random UID
      final random = Random();
      final uid = 'CARD-${random.nextInt(999999)}';
      debugPrint('Simulated NFC UID: $uid');
      await Future.delayed(const Duration(seconds: 1));
      return uid;
    }
  }
}
