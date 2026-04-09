import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../widgets/tap_notification_dialog.dart';
import 'api_service.dart';
import 'fcm_service.dart';
import 'local_storage.dart';

class NotificationHandler {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Timer? _pendingPollTimer;
  static final Set<String> _activePendingDialogs = <String>{};

  static void showTapDialogDirectly(String notificationId, String nfcId) {
    _showTapDialog(notificationId, nfcId);
  }


  static void initialize() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received foreground message: ${message.data}');
      
      final data = message.data;
      final type = data['type'];

      if (type == 'nfc_tap') {
        // Show accept/deny dialog
        final notificationId = data['notification_id'];
        final nfcId = data['nfc_id'];
        
        _showTapDialog(notificationId, nfcId);
      } else if (type == 'expired_notification') {
        // Show warning about expired notification
        _showExpiredWarning();
      } else if (type == 'blocked_nfc_alert') {
        // Show alert that blocked NFC was used
        _showBlockedAlert();
      }

      // Avoid duplicates: show local notification only for data-only payloads.
      if (message.notification == null) {
        final fallbackTitle = type == 'nfc_tap'
            ? 'NFC Card Tapped'
            : type == 'expired_notification'
                ? 'Payment Auto-Accepted'
                : type == 'blocked_nfc_alert'
                    ? 'Blocked NFC Used'
                    : 'Notification';
        final fallbackBody = type == 'nfc_tap'
            ? 'Please review this trip tap request.'
            : type == 'expired_notification'
                ? 'A tap request expired and was auto-accepted.'
                : type == 'blocked_nfc_alert'
                    ? 'Blocked NFC card usage detected.'
                    : 'Open app to view details.';

        FcmService.showLocalNotification(
          title: fallbackTitle,
          body: fallbackBody,
          payload: message.data.toString(),
        );
      }
    });

    // Handle background/terminated messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification opened from background: ${message.data}');
      final data = message.data;
      final type = data['type'];

      if (type == 'nfc_tap') {
        final notificationId = data['notification_id'];
        final nfcId = data['nfc_id'];
        _showTapDialog(notificationId, nfcId);
      }
    });

    // Fallback path: pull pending notifications periodically in case
    // trip pushes are delayed/missing, then show the same approval dialog.
    _startPendingNotificationPolling();
  }

  static void _startPendingNotificationPolling() {
    _pendingPollTimer?.cancel();
    _pendingPollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      await _checkPendingNotifications();
    });
    _checkPendingNotifications();
  }

  static Future<void> _checkPendingNotifications() async {
    try {
      final role = await LocalStorage.getRole();
      if (role != 'student') return;

      final pending = await ApiService.getPendingNotifications();
      for (final item in pending) {
        final status = item['status']?.toString();
        if (status != 'pending') continue;

        final notificationId = item['id']?.toString();
        if (notificationId == null || notificationId.isEmpty) continue;
        if (_activePendingDialogs.contains(notificationId)) continue;

        final nfcId = item['nfc_id']?.toString() ?? 'Unknown';
        _activePendingDialogs.add(notificationId);

        final shown = _showTapDialog(notificationId, nfcId);
        if (!shown) {
          _activePendingDialogs.remove(notificationId);
          continue;
        }
        break;
      }
    } catch (e) {
      debugPrint('Pending notification poll failed: $e');
    }
  }

  static bool _showTapDialog(String notificationId, String nfcId) {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TapNotificationDialog(
        notificationId: notificationId,
        nfcId: nfcId,
      ),
    ).whenComplete(() {
      _activePendingDialogs.remove(notificationId);
    });

    return true;
  }

  static void _showExpiredWarning() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Payment Auto-Accepted'),
            ],
          ),
          content: const Text(
            'Your NFC was used but you didn\'t respond in time. '
            'Payment was automatically accepted. If this wasn\'t you, '
            'block your NFC immediately in your profile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/student_profile');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Block NFC Now'),
            ),
          ],
        ),
      );
    }
  }

  static void _showBlockedAlert() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text('Blocked NFC Used!'),
            ],
          ),
          content: const Text(
            'Your blocked NFC card was just used! '
            'This is suspicious activity. Contact support if needed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
