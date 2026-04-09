import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import 'driver_profile.dart';
import 'active_trip_page.dart';
import 'trip_details_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  List<Map<String, dynamic>> trips = [];
  List<String> hiddenTripIds = [];
  Map<String, dynamic>? activeTrip;
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadHiddenTrips();
    _loadTrips();
  }

  Future<void> _loadHiddenTrips() async {
    final hidden = await LocalStorage.getHiddenTrips();
    setState(() {
      hiddenTripIds = hidden;
    });
  }

  Future<void> _loadTrips() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      debugPrint('Loading driver trips...');
      final data = await ApiService.getDriverTrips();
      debugPrint('Loaded ${data.length} trips');

      Map<String, dynamic>? active;
      try {
        active = await ApiService.getActiveTrip();
      } catch (_) {
        active = null;
      }

      // FIXED: Clear hidden trips on refresh (fetch all from DB)
      hiddenTripIds.clear();
      await LocalStorage.saveHiddenTrips([]);

      setState(() {
        trips = data;
        activeTrip = active;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading trips: $e');
      setState(() {
        errorMsg = 'Failed to load trips.\n${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _startNewTrip() async {
    if (activeTrip != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End the current active trip before creating a new one.'),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveTripPage(
              tripName: (activeTrip!['name'] ?? 'Active Trip').toString(),
            ),
          ),
        ).then((_) => _loadTrips());
      }
      return;
    }

    final nameController = TextEditingController(text: 'Trip');
    final tripName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Trip'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Trip Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (tripName == null || tripName.isEmpty) return;

    try {
      await ApiService.createAndStartActiveTrip(tripName);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ActiveTripPage(tripName: tripName)),
        ).then((_) => _loadTrips());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start trip: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _clearTrip(String tripId) async {
    if (activeTrip != null && activeTrip!['id'] == tripId) {
      return;
    }
    setState(() {
      hiddenTripIds.add(tripId);
    });
    await LocalStorage.saveHiddenTrips(hiddenTripIds);
  }

  Future<void> _clearAllTrips() async {
    final activeTripId = activeTrip?['id']?.toString();
    final allIds = trips
        .map((t) => t['id'] as String)
        .where((id) => id != activeTripId)
        .toList();
    setState(() {
      hiddenTripIds.addAll(allIds);
    });
    await LocalStorage.saveHiddenTrips(hiddenTripIds);
  }

  Future<void> _endCurrentActiveTrip() async {
    try {
      await ApiService.endActiveTrip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active trip ended successfully')),
      );
      await _loadTrips();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end active trip: ${e.toString()}')),
      );
    }
  }

  void _openActiveTrip() {
    if (activeTrip == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveTripPage(
          tripName: (activeTrip!['name'] ?? 'Active Trip').toString(),
        ),
      ),
    ).then((_) => _loadTrips());
  }

  @override
  Widget build(BuildContext context) {
    final visibleTrips = trips
        .where((t) => !hiddenTripIds.contains(t['id']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadTrips,
            tooltip: 'Refresh (Shows all trips)',
          ),
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined),
            onPressed: visibleTrips.isEmpty ? null : _clearAllTrips,
            tooltip: 'Hide All Trips',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DriverProfile()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: isLoading
          ? const AppLoadingShell(
              title: 'Driver Dashboard',
              subtitle: 'Loading trips and fleet activity...',
              statCount: 4,
            )
          : errorMsg != null
          ? Center(
              child: AppSurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMsg!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadTrips,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : visibleTrips.isEmpty
          ? const Center(
              child: AppSurfaceCard(
                child: Text(
                  'No trips yet. Start a new trip!',
                  style: TextStyle(color: AppColors.mutedText),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                const AppPageHeader(
                  title: 'Driver operations',
                  subtitle:
                      'Launch trips, review revenue, and keep the visible list tidy.',
                ),
                const SizedBox(height: 12),
                if (activeTrip != null) ...[
                  AppSurfaceCard(
                    color: AppColors.surfaceAlt,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active trip in progress',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${activeTrip!['name'] ?? 'Active Trip'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Started: ${activeTrip!['start_time'] ?? '-'}',
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _openActiveTrip,
                                child: const Text('Resume Active Trip'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _endCurrentActiveTrip,
                                child: const Text('End Active Trip'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ...visibleTrips.map((trip) {
                  final isActive =
                      activeTrip != null &&
                      activeTrip!['id']?.toString() == trip['id']?.toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppSurfaceCard(
                      padding: const EdgeInsets.all(14),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          trip['name'] ?? 'Trip',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Students: ${trip['total_students']} | Revenue: ₹${trip['total_revenue']}\n'
                          'Started: ${trip['start_time'] ?? 'Not started'}',
                        ),
                        trailing: isActive
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.visibility_off_outlined),
                                onPressed: () => _clearTrip(trip['id']),
                                tooltip: 'Hide trip',
                              ),
                        onTap: () {
                          if (isActive) {
                            _openActiveTrip();
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TripDetailsPage(
                                  tripId: trip['id'],
                                  tripName: trip['name'] ?? 'Trip',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewTrip,
        icon: Icon(activeTrip != null ? Icons.play_arrow : Icons.add),
        label: Text(activeTrip != null ? 'Resume Active Trip' : 'Start New Trip'),
      ),
    );
  }
}
