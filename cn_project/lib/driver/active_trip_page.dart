import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import 'dart:async';

class ActiveTripPage extends StatefulWidget {
  final String tripName;

  const ActiveTripPage({super.key, required this.tripName});

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage> {
  List<Map<String, dynamic>> scannedStudents = [];
  bool isScanning = false;
  int totalRevenue = 0;
  static const int baseFare = 20;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadActiveTrip();
    
    // Auto-refresh every 3 seconds to get status updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadActiveTripDetails();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadActiveTrip() async {
    try {
      final trip = await ApiService.getActiveTrip();
      setState(() {
        totalRevenue = (trip['total_revenue'] as num).toInt();
      });
      
      // Load trip details
      await _loadActiveTripDetails();
    } catch (e) {
      debugPrint('No active trip data: $e');
    }
  }

  Future<void> _loadActiveTripDetails() async {
    try {
      final trip = await ApiService.getActiveTrip();
      final details = await ApiService.getTripDetails(trip['id']);
      
      setState(() {
        scannedStudents = details;
        totalRevenue = (trip['total_revenue'] as num).toInt();
      });
    } catch (e) {
      debugPrint('Error loading trip details: $e');
    }
  }

  Future<void> _scanCard() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
    });

    try {
      final nfcId = await NfcService.readCardUid();
      if (nfcId == null) {
        throw Exception('No NFC card detected');
      }

      // Check for local duplicate
      if (scannedStudents.any((s) => s['nfc_id'] == nfcId)) {
        throw Exception('This card was already scanned');
      }

      // Tap the card (sends notification to student)
      await ApiService.tapNfcInActiveTrip(nfcId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Card tapped - Notification sent to student'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );

        // Refresh immediately to show pending status
        await _loadActiveTripDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  Future<void> _endTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip?'),
        content: Text(
          'Total students: ${scannedStudents.length}\n'
          'Total revenue: ₹$totalRevenue',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.endActiveTrip();
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip ended successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.yellow.shade700;
      case 'accepted':
        return Colors.green;
      case 'denied_misused':
        return Colors.red;
      case 'expired_accepted':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending...';
      case 'accepted':
        return 'Accepted';
      case 'denied_misused':
        return 'DENIED (Misused)';
      case 'expired_accepted':
        return 'Expired/Auto-Accepted';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tripName),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle),
            onPressed: _endTrip,
            tooltip: 'End Trip',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Card
          Card(
            margin: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.people, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        '${scannedStudents.length}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Students'),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.currency_rupee, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        '₹$totalRevenue',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Revenue'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Student List
          Expanded(
            child: scannedStudents.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nfc, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No cards scanned yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: scannedStudents.length,
                    itemBuilder: (context, index) {
                      final student = scannedStudents[index];
                      final status = student['status'] ?? 'pending';
                      final statusColor = _getStatusColor(status);
                      final statusText = _getStatusText(status);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(student['student_name'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('NFC: ${student['nfc_id']}'),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: const Text('₹20'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isScanning ? null : _scanCard,
        icon: isScanning
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.nfc),
        label: Text(isScanning ? 'Scanning...' : 'Scan Card'),
        backgroundColor: isScanning ? Colors.grey : Colors.blue,
      ),
    );
  }
}
