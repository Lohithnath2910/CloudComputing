import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'student/student_dashboard.dart';
import 'student/student_profile.dart';
import 'student/expired_notifications_page.dart';
import 'driver/driver_dashboard.dart';
import 'driver/driver_profile.dart';
import 'auth/login_page.dart';
import 'services/local_storage.dart';
import 'services/fcm_service.dart';
import 'services/notification_handler.dart';

final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeBackgroundLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await _backgroundLocalNotifications.initialize(initializationSettings);

  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'nfc_taps',
      'NFC Tap Notifications',
      description: 'Notifications for NFC card taps',
      importance: Importance.high,
    );

    await _backgroundLocalNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}

// ✅ CRITICAL: Top-level function for handling background messages
// This runs even when app is COMPLETELY CLOSED
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  await Firebase.initializeApp();
  
  print('Background message received: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');

  await _initializeBackgroundLocalNotifications();

  final data = message.data;
  final type = data['type'];

  final title = message.notification?.title ??
      (type == 'nfc_tap' ? 'NFC Card Tapped' : 'Notification');
  final body = message.notification?.body ??
      (type == 'nfc_tap'
          ? 'Please review this trip tap request.'
          : 'Open app to view details.');

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'nfc_taps',
    'NFC Tap Notifications',
    channelDescription: 'Notifications for NFC card taps',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await _backgroundLocalNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    platformDetails,
    payload: jsonEncode(data),
  );
  
  // Note: You can't show dialogs here, but you can:
  // 1. Show local notifications
  // 2. Update local database
  // 3. Make API calls
  
  // The notification will be handled when user taps it via onMessageOpenedApp
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // ✅ Register background message handler BEFORE initializing FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize FCM
  await FcmService.initialize();
  
  // Initialize Notification Handler
  NotificationHandler.initialize();
  
  runApp(const NFCBusApp());
}

class NFCBusApp extends StatefulWidget {
  const NFCBusApp({super.key});

  @override
  State<NFCBusApp> createState() => _NFCBusAppState();
}

class _NFCBusAppState extends State<NFCBusApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _role;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _checkForInitialMessage();
  }

  // ✅ Check if app was opened from a notification while terminated
  Future<void> _checkForInitialMessage() async {
    RemoteMessage? initialMessage = 
        await FirebaseMessaging.instance.getInitialMessage();
    
    if (initialMessage != null) {
      print('App opened from terminated state via notification');
      print('Initial message: ${initialMessage.data}');
      
      // Handle the notification after app is ready
      Future.delayed(const Duration(seconds: 1), () {
        final type = initialMessage.data['type'];
        if (type == 'nfc_tap') {
          final notificationId = initialMessage.data['notification_id'];
          final nfcId = initialMessage.data['nfc_id'];
          NotificationHandler.showTapDialogDirectly(notificationId, nfcId);
        }
      });
    }
  }

  Future<void> _bootstrap() async {
    final token = await LocalStorage.getToken();
    String? role = await LocalStorage.getRole();

    if (role == null && token != null && token.isNotEmpty) {
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          String normalized(String input) {
            final pad = (4 - input.length % 4) % 4;
            return input + ('=' * pad);
          }

          final payload = parts[1];
          final decoded = String.fromCharCodes(
            base64Url.decode(normalized(payload)),
          );
          final map = jsonDecode(decoded) as Map;
          final extractedRole = map['role'] as String?;
          if (extractedRole != null) {
            role = extractedRole;
            await LocalStorage.saveRole(extractedRole);
          }
        }
      } catch (_) {}
    }

    debugPrint('Startup token: $token, role: $role');
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
      _role = role;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        debugShowCheckedModeBanner: false,
      );
    }

    late final Widget startScreen;
    late final String startName;

    if (_isLoggedIn) {
      if (_role == 'driver') {
        startScreen = const DriverDashboard();
        startName = 'driver';
      } else {
        startScreen = const StudentDashboard();
        startName = 'student';
      }
    } else {
      startScreen = const LoginPage();
      startName = 'login';
    }

    debugPrint('Start screen -> $startName');

    return MaterialApp(
      title: "NFC Bus System",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      navigatorKey: NotificationHandler.navigatorKey,
      home: startScreen,
      routes: {
        '/login': (_) => const LoginPage(),
        '/student': (_) => const StudentDashboard(),
        '/student_profile': (_) => const StudentProfile(),
        '/expired_notifications': (_) => const ExpiredNotificationsPage(),
        '/driver': (_) => const DriverDashboard(),
        '/driver_profile': (_) => const DriverProfile(),
      },
    );
  }
}
