import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ExpiredNotificationsPage extends StatefulWidget {
  const ExpiredNotificationsPage({super.key});

  @override
  State<ExpiredNotificationsPage> createState() => _ExpiredNotificationsPageState();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Warning dismissed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Missed Tap Notifications'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No missed notifications',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      final status = notif['status'] ?? 'pending';
                      final nfcId = notif['nfc_id'] ?? '';
                      final createdAt = notif['created_at'] ?? '';
                      final expiresAt = notif['expires_at'] ?? '';

                      Color statusColor = Colors.orange;
                      String statusText = 'Expired (Auto-Accepted)';
                      
                      if (status == 'pending') {
                        statusColor = Colors.yellow;
                        statusText = 'Pending';
                      } else if (status == 'expired') {
                        statusColor = Colors.orange;
                        statusText = 'Expired (Auto-Accepted)';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor,
                            child: const Icon(Icons.warning, color: Colors.white),
                          ),
                          title: Text('NFC ID: $nfcId'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Status: $statusText'),
                              Text(
                                'Tapped at: ${_formatDateTime(createdAt)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: status == 'expired'
                              ? ElevatedButton(
                                  onPressed: () => _dismissNotification(notif['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                  ),
                                  child: const Text('Dismiss'),
                                )
                              : null,
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
