import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/trip_card.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  List<Map<String, dynamic>> trips = [];
  List<Map<String, dynamic>> pendingNotifications = [];
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    try {
      // Load trips
      final tripsData = await ApiService.getStudentTrips();
      
      // Load pending notifications
      final pendingData = await ApiService.getPendingNotifications();
      
      debugPrint('Student trips loaded: ${tripsData.length}');
      debugPrint('Pending notifications: ${pendingData.length}');
      
      setState(() {
        trips = tripsData;
        pendingNotifications = pendingData;
        isLoading = false;
      });

      // Show warning popup if there are expired notifications
      if (pendingNotifications.isNotEmpty) {
        _showExpiredNotificationsPopup();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        errorMsg = 'Failed to load data.\n${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _showExpiredNotificationsPopup() {
    final expiredCount = pendingNotifications.where((n) => n['status'] == 'expired').length;
    
    if (expiredCount == 0) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Missed Notifications'),
              ],
            ),
            content: Text(
              'You have $expiredCount missed NFC tap notification(s) that were auto-accepted. '
              'If these payments weren\'t made by you, block your NFC immediately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamed(context, '/expired_notifications');
                },
                child: const Text('View Details'),
              ),
            ],
          ),
        );
      }
    });
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTimeStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
  // ✅ FIXED: Show notification badge only for expired notifications
  if (pendingNotifications.where((n) => n['status'] == 'expired').isNotEmpty)
    Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            Navigator.pushNamed(context, '/expired_notifications')
                .then((_) => _loadData());
          },
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${pendingNotifications.where((n) => n['status'] == 'expired').length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    ),
  IconButton(
    icon: const Icon(Icons.person),
    onPressed: () {
      Navigator.pushNamed(context, '/student_profile').then((_) => _loadData());
    },
  ),
],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMsg!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : trips.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No trips yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          final startTime = trip['start_time'];
                          final endTime = trip['end_time'];
                          final status = endTime == null ? 'Active' : 'Completed';

                          return TripCard(
                            route: trip['name'] ?? 'Trip',
                            date: _formatDateTime(startTime),
                            status: status,
                          );
                        },
                      ),
                    ),
    );
  }
}
