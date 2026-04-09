import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

class TripCard extends StatelessWidget {
  final String route;
  final String date;
  final String status;
  final VoidCallback? onTap;

  const TripCard({
    super.key,
    required this.route,
    required this.date,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        status.toLowerCase() == 'confirmed' ||
            status.toLowerCase() == 'accepted'
        ? AppColors.success
        : status.toLowerCase() == 'active'
        ? AppColors.warning
        : AppColors.mutedText;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.directions_bus_outlined,
            color: AppColors.accent,
          ),
        ),
        title: Text(route, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          date,
          style: const TextStyle(color: AppColors.mutedText),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: AppColors.mutedText,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
