import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:async';
import '../theme/app_theme.dart';

class TapNotificationDialog extends StatefulWidget {
  final String notificationId;
  final String nfcId;

  const TapNotificationDialog({
    super.key,
    required this.notificationId,
    required this.nfcId,
  });

  @override
  State<TapNotificationDialog> createState() => _TapNotificationDialogState();
}

class _TapNotificationDialogState extends State<TapNotificationDialog> {
  // TIMEOUT: 2 minutes - EASILY CHANGEABLE HERE
  static const int timeoutSeconds = 120; // 2 minutes

  int remainingSeconds = timeoutSeconds;
  Timer? _timer;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        _autoExpire();
      }
    });
  }

  void _autoExpire() async {
    if (!_responding && mounted) {
      // ✅ FIXED: Call backend to mark as expired
      try {
        await ApiService.respondToTapNotification(widget.notificationId, true);
      } catch (e) {
        debugPrint('Error auto-expiring notification: $e');
      }

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Notification expired - Payment auto-accepted'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _respond(bool accepted) async {
    if (_responding) return;

    setState(() {
      _responding = true;
    });

    _timer?.cancel();

    try {
      await ApiService.respondToTapNotification(
        widget.notificationId,
        accepted,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted
                  ? '✅ Payment accepted successfully'
                  : '❌ Payment denied - marked as misused',
            ),
            backgroundColor: accepted ? Colors.green : Colors.red,
          ),
        );

        // If denied, show block NFC option
        if (!accepted) {
          _showBlockNfcOption();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _responding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBlockNfcOption() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Block Your NFC?'),
        content: const Text(
          'Was this payment attempt fraudulent? '
          'If your card was stolen or lost, you should block it now to prevent further misuse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No, Ignore'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/student_profile');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Block NFC'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      scrollable: true,
      title: const Row(
        children: [
          Icon(Icons.nfc_rounded, color: AppColors.accent, size: 28),
          SizedBox(width: 12),
          Expanded(child: Text('NFC Card Tapped')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your NFC card was just scanned on a bus.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'NFC ID: ${widget.nfcId}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(
              'Time remaining: $minutes:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: remainingSeconds < 30
                    ? AppColors.danger
                    : AppColors.warning,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Was this you? Accept to pay for this trip, or deny if this is fraudulent.',
              style: TextStyle(fontSize: 14, color: AppColors.mutedText),
            ),
          ],
        ),
      ),
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actions: [
        TextButton(
          onPressed: _responding ? null : () => _respond(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: _responding
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('DENY'),
        ),
        ElevatedButton(
          onPressed: _responding ? null : () => _respond(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          child: _responding
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('ACCEPT'),
        ),
      ],
    );
  }
}
