import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../services/local_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

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
        expiredNotifications = pending
            .where((n) => n['status'] == 'expired')
            .toList();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeader(
                title: 'Profile settings',
                subtitle: 'Manage your student identity and NFC access.',
              ),
              const SizedBox(height: 16),
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Name'),
                      subtitle: Text(name),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(email),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ✅ UPDATED: NFC Card Section with Unblock/Register New
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NFC card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),

                    if (nfcId == null)
                      Column(
                        children: [
                          const ListTile(
                            leading: Icon(
                              Icons.nfc_rounded,
                              color: AppColors.mutedText,
                            ),
                            title: Text('No NFC card registered'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _registerNfc,
                            icon: const Icon(Icons.nfc_rounded),
                            label: const Text('Register NFC Card'),
                          ),
                        ],
                      )
                    else if (isBlocked)
                      Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.block,
                              color: AppColors.danger,
                            ),
                            title: const Text(
                              'NFC card blocked',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(nfcId),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your card is currently blocked. You can unblock it or register a new card.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _unblockNfc,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Unblock Card'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _registerNewNfc,
                                  icon: const Icon(Icons.nfc_rounded),
                                  label: const Text('Register New'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.neutralButton,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.nfc_rounded,
                              color: AppColors.success,
                            ),
                            title: const Text('NFC card active'),
                            subtitle: Text(nfcId),
                          ),
                          ElevatedButton.icon(
                            onPressed: _blockNfc,
                            icon: const Icon(Icons.block),
                            label: const Text('Block NFC Card'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Expired Notifications Warning Section
              if (expiredNotifications.isNotEmpty)
                AppSurfaceCard(
                  color: const Color(0xFFF8F1E6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Suspicious activity detected (${expiredNotifications.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      const Text(
                        'Your NFC card was used but you did not respond in time. Payments were auto-accepted. If this was not you, block your NFC immediately.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/expired_notifications',
                                ).then((_) => _loadProfile());
                              },
                              child: const Text('View Details'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _blockNfc,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                              ),
                              child: const Text('Block NFC'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          for (var notif in expiredNotifications) {
                            _dismissExpiredWarning(notif['id']);
                          }
                        },
                        child: const Text('This was me - dismiss warnings'),
                      ),
                    ],
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
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
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
