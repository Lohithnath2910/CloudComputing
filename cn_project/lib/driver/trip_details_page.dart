import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class TripDetailsPage extends StatefulWidget {
  final String tripId;
  final String tripName;

  const TripDetailsPage({
    super.key,
    required this.tripId,
    required this.tripName,
  });

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  List<Map<String, dynamic>> details = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      final data = await ApiService.getTripDetails(widget.tripId);
      setState(() {
        details = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.success;
      case 'denied_misused':
        return AppColors.danger;
      case 'expired_accepted':
        return AppColors.warning;
      default:
        return AppColors.neutralButton;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
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
      appBar: AppBar(title: Text(widget.tripName)),
      body: isLoading
          ? const AppLoadingShell(
              title: 'Trip details',
              subtitle: 'Loading tap records and revenue...',
              statCount: 2,
            )
          : details.isEmpty
          ? const Center(child: Text('No students tapped for this trip'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppSurfaceCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStat(
                          label: 'Total Students',
                          value: '${details.length}',
                        ),
                        _SummaryStat(
                          label: 'Total Revenue',
                          value: '₹${details.length * 20}',
                        ),
                      ],
                    ),
                  ),
                ),

                // Students List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: details.length,
                    itemBuilder: (context, index) {
                      final detail = details[index];
                      final status = detail['status'] ?? 'pending';
                      final statusColor = _getStatusColor(status);
                      final statusText = _getStatusText(status);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppSurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: statusColor,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              detail['student_name'] ?? 'Unknown Student',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'NFC: ${detail['nfc_id']}',
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: const Text(
                              '₹20',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
