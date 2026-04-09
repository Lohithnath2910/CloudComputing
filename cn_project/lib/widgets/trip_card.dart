import 'package:flutter/material.dart';

class TripCard extends StatelessWidget {
  final String route;
  final String date;
  final String status;

  const TripCard({
    super.key,
    required this.route,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.directions_bus),
        title: Text(route, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(date),
        trailing: Text(
          status,
          style: TextStyle(
            color: status == 'Confirmed' ? Colors.green : Colors.orange,
          ),
        ),
      ),
    );
  }
}
