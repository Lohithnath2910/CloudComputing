import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/trip_card.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'student_trip_details_page.dart';

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
    final expiredCount = pendingNotifications
        .where((n) => n['status'] == 'expired')
        .length;

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
            content: SingleChildScrollView(
              child: Text(
                'You have $expiredCount missed NFC tap notification(s) that were auto-accepted. '
                'If these payments weren\'t made by you, block your NFC immediately.',
              ),
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

  Future<void> _openTripDetails(Map<String, dynamic> trip) async {
    final tripId = trip['id']?.toString();
    if (tripId == null || tripId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentTripDetailsPage(
          tripId: tripId,
          initialTitle: (trip['name'] ?? 'Trip').toString(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: const [
        AppPageHeader(
          title: 'Trips and tap history',
          subtitle: 'Loading your rides and alert status...',
        ),
        SizedBox(height: 12),
        AppSurfaceCard(
          child: Row(
            children: [
              _StudentDashSkeletonBox(width: 46, height: 46, radius: 14),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StudentDashSkeletonLine(widthFactor: 0.55),
                    SizedBox(height: 8),
                    _StudentDashSkeletonLine(widthFactor: 0.35, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        _StudentTripSkeletonCard(),
        SizedBox(height: 10),
        _StudentTripSkeletonCard(),
        SizedBox(height: 10),
        _StudentTripSkeletonCard(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          if (pendingNotifications
              .where((n) => n['status'] == 'expired')
              .isNotEmpty)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/expired_notifications',
                    ).then((_) => _loadData());
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
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
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/student_profile',
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : errorMsg != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: AppSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 56,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : trips.isEmpty
          ? const Center(
              child: AppSurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_bus_outlined,
                      size: 56,
                      color: AppColors.mutedText,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No trips yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  const AppPageHeader(
                    title: 'Trips and tap history',
                    subtitle: 'Track current and past rides in one clean view.',
                  ),
                  const SizedBox(height: 12),
                  ...trips.map((trip) {
                    final startTime = trip['start_time'];
                    final endTime = trip['end_time'];
                    final status = endTime == null ? 'Active' : 'Completed';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TripCard(
                        route: trip['name'] ?? 'Trip',
                        date: _formatDateTime(startTime),
                        status: status,
                        onTap: () => _openTripDetails(trip),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _StudentTripSkeletonCard extends StatelessWidget {
  const _StudentTripSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const AppSurfaceCard(
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          _StudentDashSkeletonBox(width: 48, height: 48, radius: 16),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StudentDashSkeletonLine(widthFactor: 0.58),
                SizedBox(height: 8),
                _StudentDashSkeletonLine(widthFactor: 0.42, height: 12),
              ],
            ),
          ),
          SizedBox(width: 10),
          _StudentDashSkeletonBox(width: 64, height: 26, radius: 999),
        ],
      ),
    );
  }
}

class _StudentDashSkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _StudentDashSkeletonLine({this.widthFactor = 1, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _StudentDashSkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _StudentDashSkeletonBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
