import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/local_storage.dart';
import 'driver_profile.dart';
import 'active_trip_page.dart';
import 'trip_details_page.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  List<Map<String, dynamic>> trips = [];
  List<String> hiddenTripIds = [];
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
      
      // FIXED: Clear hidden trips on refresh (fetch all from DB)
      hiddenTripIds.clear();
      await LocalStorage.saveHiddenTrips([]);
      
      setState(() {
        trips = data;
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
      final trip = await ApiService.createAndStartActiveTrip(tripName);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveTripPage(tripName: tripName),
          ),
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
    setState(() {
      hiddenTripIds.add(tripId);
    });
    await LocalStorage.saveHiddenTrips(hiddenTripIds);
  }

  Future<void> _clearAllTrips() async {
    final allIds = trips.map((t) => t['id'] as String).toList();
    setState(() {
      hiddenTripIds.addAll(allIds);
    });
    await LocalStorage.saveHiddenTrips(hiddenTripIds);
  }

  @override
  Widget build(BuildContext context) {
    final visibleTrips = trips.where((t) => !hiddenTripIds.contains(t['id'])).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrips,
            tooltip: 'Refresh (Shows all trips)',
          ),
          // FIXED: Changed icon to cleaning/sweep icon
          IconButton(
            icon: const Icon(Icons.cleaning_services), // Better icon for "clear all"
            onPressed: visibleTrips.isEmpty ? null : _clearAllTrips,
            tooltip: 'Hide All Trips',
          ),
          IconButton(
            icon: const Icon(Icons.person),
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
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTrips,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : visibleTrips.isEmpty
                  ? const Center(child: Text('No trips yet. Start a new trip!'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: visibleTrips.length,
                      itemBuilder: (context, index) {
                        final trip = visibleTrips[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(trip['name'] ?? 'Trip'),
                            subtitle: Text(
                              'Students: ${trip['total_students']} | Revenue: ₹${trip['total_revenue']}\n'
                              'Started: ${trip['start_time'] ?? 'Not started'}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.visibility_off),
                              onPressed: () => _clearTrip(trip['id']),
                              tooltip: 'Hide trip',
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TripDetailsPage(
                                    tripId: trip['id'],
                                    tripName: trip['name'] ?? 'Trip',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewTrip,
        icon: const Icon(Icons.add),
        label: const Text('Start New Trip'),
      ),
    );
  }
}
