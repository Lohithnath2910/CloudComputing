import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class StudentTripDetailsPage extends StatefulWidget {
  final String tripId;
  final String initialTitle;

  const StudentTripDetailsPage({
    super.key,
    required this.tripId,
    required this.initialTitle,
  });

  @override
  State<StudentTripDetailsPage> createState() => _StudentTripDetailsPageState();
}

class _StudentTripDetailsPageState extends State<StudentTripDetailsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getStudentTripDetails(widget.tripId);
      if (!mounted) return;
      setState(() {
        _details = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return 'N/A';
    try {
      final dt = DateTime.parse(value.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = (_details?['trip'] as Map<String, dynamic>?) ?? const {};
    final tapRecords = (_details?['tap_records'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: _loading
          ? const _TripDetailsSkeleton()
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 52),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  AppPageHeader(
                    title: (trip['name']?.toString().isNotEmpty ?? false)
                        ? trip['name'].toString()
                        : widget.initialTitle,
                    subtitle: 'Ride summary and your NFC taps for this trip.',
                  ),
                  const SizedBox(height: 12),
                  AppSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'Bus', value: trip['bus_number']?.toString() ?? 'Not assigned'),
                        _InfoRow(label: 'Route', value: trip['bus_route_name']?.toString() ?? 'Unknown'),
                        _InfoRow(label: 'Driver', value: trip['driver_name']?.toString() ?? 'Unknown'),
                        _InfoRow(label: 'Driver Email', value: trip['driver_email']?.toString() ?? 'N/A'),
                        _InfoRow(label: 'Started', value: _formatDateTime(trip['start_time'])),
                        _InfoRow(label: 'Ended', value: _formatDateTime(trip['end_time'])),
                        _InfoRow(label: 'Total Students', value: '${trip['total_students'] ?? 0}'),
                        _InfoRow(label: 'Your Tap Count', value: '${_details?['tap_count'] ?? 0}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your Tap Records',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (tapRecords.isEmpty)
                    const AppSurfaceCard(
                      child: Text(
                        'No tap records available for this trip.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    )
                  else
                    ...tapRecords.map((record) {
                      final status = (record['status'] ?? '').toString().toLowerCase();
                      final isAccepted = status == 'accepted';
                      final chipColor = isAccepted ? AppColors.success : AppColors.warning;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppSurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: chipColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isAccepted ? Icons.check : Icons.schedule,
                                  color: chipColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatDateTime(record['timestamp']),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Status: ${record['status'] ?? 'unknown'} | Fare: ${record['fare_paid'] ?? 0}',
                                      style: const TextStyle(color: AppColors.mutedText),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripDetailsSkeleton extends StatelessWidget {
  const _TripDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: const [
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonLine(widthFactor: 0.5),
              SizedBox(height: 10),
              _SkeletonLine(widthFactor: 0.7),
              SizedBox(height: 14),
              _SkeletonLine(widthFactor: 0.9),
              SizedBox(height: 10),
              _SkeletonLine(widthFactor: 0.86),
              SizedBox(height: 10),
              _SkeletonLine(widthFactor: 0.8),
            ],
          ),
        ),
        SizedBox(height: 12),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonLine(widthFactor: 0.45),
              SizedBox(height: 12),
              _SkeletonLine(height: 54),
              SizedBox(height: 10),
              _SkeletonLine(height: 54),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _SkeletonLine({this.widthFactor = 1, this.height = 14});

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
