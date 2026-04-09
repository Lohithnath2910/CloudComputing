import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../services/local_storage.dart';

class StudentProfile extends StatefulWidget {
  const StudentProfile({super.key});

  @override
  State<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  Map<String, dynamic>? student;
  List<Map<String, dynamic>> expiredNotifications = [];
  bool isLoading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });
    try {
      final data = await ApiService.getStudentProfile();
      final pending = await ApiService.getPendingNotifications();
      setState(() {
        student = data;
        expiredNotifications = pending.where((n) => n['status'] == 'expired').toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMsg = 'Failed to load profile.\n${e.toString()}';
        isLoading = false;
      });
    }
  }

  // Register NFC for first time
  Future<void> _registerNfc() async {
    try {
      final nfcId = await NfcService.readCardUid();
      if (nfcId == null) {
        throw Exception('No NFC card detected');
      }
      
      await ApiService.registerNfcCard(nfcId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ NFC card registered successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadProfile();
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

  // ✅ NEW: Unblock current NFC card
  Future<void> _unblockNfc() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock NFC Card?'),
        content: const Text(
          'This will re-enable your current NFC card for payments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Re-register the same nfc_id to unblock it
        await ApiService.registerNfcCard(student!['nfc_id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ NFC card unblocked successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadProfile();
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

  // ✅ NEW: Register a new NFC card (replaces blocked one)
  Future<void> _registerNewNfc() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register New NFC Card?'),
        content: const Text(
          'This will replace your current blocked card with a new one. '
          'Tap your new NFC card when prompted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Read new NFC card
        final nfcId = await NfcService.readCardUid();
        if (nfcId == null) {
          throw Exception('No NFC card detected');
        }
        
        // Register the new card
        await ApiService.registerNfcCard(nfcId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ New NFC card registered successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadProfile();
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

  // Block NFC card
  Future<void> _blockNfc() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block NFC Card?'),
        content: const Text(
          'This will prevent your NFC card from being used for payments. '
          'You can unblock it or register a new card later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.blockNfc();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚫 NFC card blocked successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadProfile();
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

  Future<void> _dismissExpiredWarning(String notificationId) async {
    try {
      await ApiService.dismissExpiredWarning(notificationId);
      _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMsg != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(errorMsg!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final name = student?['name'] ?? 'N/A';
    final email = student?['email'] ?? 'N/A';
    final nfcId = student?['nfc_id'];
    final isBlocked = student?['is_nfc_blocked'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Name'),
                        subtitle: Text(name),
                      ),
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: const Text('Email'),
                        subtitle: Text(email),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ✅ UPDATED: NFC Card Section with Unblock/Register New
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NFC Card',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      
                      // Case 1: No NFC card registered
                      if (nfcId == null)
                        Column(
                          children: [
                            const ListTile(
                              leading: Icon(Icons.nfc, color: Colors.grey),
                              title: Text('No NFC card registered'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _registerNfc,
                              icon: const Icon(Icons.nfc),
                              label: const Text('Register NFC Card'),
                            ),
                          ],
                        )
                      
                      // Case 2: NFC card is registered but BLOCKED
                      else if (isBlocked)
                        Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.nfc, color: Colors.red),
                              title: const Text(
                                'NFC Card BLOCKED',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(nfcId),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your card is currently blocked. You can unblock it or register a new card.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _unblockNfc,
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('Unblock Card'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _registerNewNfc,
                                    icon: const Icon(Icons.nfc),
                                    label: const Text('Register New'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      
                      // Case 3: NFC card is registered and ACTIVE
                      else
                        Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.nfc, color: Colors.green),
                              title: const Text('NFC Card'),
                              subtitle: Text(nfcId),
                            ),
                            ElevatedButton.icon(
                              onPressed: _blockNfc,
                              icon: const Icon(Icons.block),
                              label: const Text('Block NFC Card'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expired Notifications Warning Section
              if (expiredNotifications.isNotEmpty)
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Suspicious Activity Detected (${expiredNotifications.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        const Text(
                          'Your NFC card was used but you didn\'t respond in time. '
                          'Payments were auto-accepted. If this wasn\'t you, block your NFC immediately!',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/expired_notifications')
                                      .then((_) => _loadProfile());
                                },
                                child: const Text('View Details'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _blockNfc,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Block NFC'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // Dismiss all expired warnings
                            for (var notif in expiredNotifications) {
                              _dismissExpiredWarning(notif['id']);
                            }
                          },
                          child: const Text('No, this was me - Dismiss warnings'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await LocalStorage.clearAll();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login',
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
