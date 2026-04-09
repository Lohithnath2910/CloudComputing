// lib/services/nfc_service.dart
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class NfcService {
  /// Reads an NFC tag and returns its UID
  static Future<String?> readCardUid() async {
    try {
      final tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
      );
      await FlutterNfcKit.finish();
      return tag.id; // UID of the card or phone
    } catch (e) {
      print('NFC read error: $e');
      return null;
    }
  }
}
