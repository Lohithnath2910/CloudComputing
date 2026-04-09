import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class ExpiredNotificationsPage extends StatefulWidget {
  const ExpiredNotificationsPage({super.key});

  @override
  State<ExpiredNotificationsPage> createState() =>
      _ExpiredNotificationsPageState();
}

class _ExpiredNotificationsPageState extends State<ExpiredNotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.getPendingNotifications();
      setState(() {
        notifications = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load notifications: $e')),
      );
    }
  }

  Future<void> _dismissNotification(String notificationId) async {
    try {
      await ApiService.dismissExpiredWarning(notificationId);
      _loadNotifications();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Warning dismissed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missed Tap Notifications')),
      body: isLoading
          ? const AppLoadingShell(
              title: 'Missed taps',
              subtitle: 'Loading notifications that need review...',
              statCount: 2,
            )
          : notifications.isEmpty
          ? const Center(
              child: AppSurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 56,
                      color: AppColors.success,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No missed notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  final status = notif['status'] ?? 'pending';
                  final nfcId = notif['nfc_id'] ?? '';
                  final createdAt = notif['created_at'] ?? '';

                  final statusColor = status == 'expired'
                      ? AppColors.warning
                      : AppColors.neutralButton;
                  final statusText = status == 'expired'
                      ? 'Expired (Auto-Accepted)'
                      : 'Pending';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppSurfaceCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: statusColor,
                          child: const Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          'NFC ID: $nfcId',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Status: $statusText'),
                            Text(
                              'Tapped at: ${_formatDateTime(createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                        trailing: status == 'expired'
                            ? ElevatedButton(
                                onPressed: () =>
                                    _dismissNotification(notif['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.neutralButton,
                                ),
                                child: const Text('Dismiss'),
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(dateTimeStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeStr;
    }
  }
}
