import 'local_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class ApiService {
  static String? _accessToken;

  static Future<void> _ensureToken() async {
    _accessToken ??= await LocalStorage.getToken();
  }


  // NEW: Update FCM token
  static Future<bool> updateFcmToken(String fcmToken, {bool isDriver = false}) async {
    await _ensureToken();
    final endpoint = isDriver ? '/drivers/me/fcm_token' : '/students/me/fcm_token';
    
    final res = await http.patch(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: json.encode({'fcm_token': fcmToken}),
    );

    return res.statusCode == 200;
  }

  // NEW: Respond to tap notification
  static Future<Map<String, dynamic>> respondToTapNotification(
    String notificationId,
    bool accepted,
  ) async {
    await _ensureToken();
    
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/students/me/tap_notifications/$notificationId/respond'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: json.encode({
        'notification_id': notificationId,
        'accepted': accepted,
      }),
    );

    if (res.statusCode == 200) {
      return json.decode(res.body);
    } else {
      throw Exception('Failed to respond: ${res.body}');
    }
  }

  // NEW: Get pending notifications
  static Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    await _ensureToken();
    
    final res = await http.get(
      Uri.parse('${AppConfig.baseUrl}/students/me/pending_notifications'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // NEW: Dismiss expired warning
  static Future<bool> dismissExpiredWarning(String notificationId) async {
    await _ensureToken();
    
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/students/me/notifications/$notificationId/dismiss'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    return res.statusCode == 200;
  }

  // NEW: Block NFC
  static Future<bool> blockNfc() async {
    await _ensureToken();
    
    final res = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/students/me/block_nfc'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    return res.statusCode == 200;
  }


  // FIXED: Added role validation
  static Future<bool> login(String email, String password, String expectedRole) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      
      // FIXED: Check if backend role matches frontend-selected role
      final String actualRole = data['role']; // Backend returns actual user role
      if (actualRole != expectedRole) {
        // Throw error if roles don't match
        throw Exception('Invalid credentials for $expectedRole. This account is registered as $actualRole.');
      }
      
      _accessToken = data['access_token'];
      if (_accessToken != null) {
        await LocalStorage.saveToken(_accessToken!);
        await LocalStorage.saveRole(actualRole); // Save backend role, not frontend role
      }
      return true;
    }
    return false;
  }

  static Future<String?> getAccessToken() async {
    await _ensureToken();
    return _accessToken;
  }

  static Future<bool> signupStudent(String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/students'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<bool> signupDriver(String name, String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/drivers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    await _ensureToken();
    final token = _accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ============ STUDENT APIs ============

  static Future<List<Map<String, dynamic>>> getStudentTrips() async {
    final headers = await getAuthHeaders();
    final res = await http.get(Uri.parse('${AppConfig.baseUrl}/students/me/trips'), headers: headers);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data);
    }
    throw Exception('Failed to load student trips');
  }

  static Future<bool> registerNfcCard(String nfcUid) async {
    final headers = await getAuthHeaders();
    final res = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/students/me/nfc'),
      headers: headers,
      body: jsonEncode({'nfc_id': nfcUid}),
    );
    if (res.statusCode == 200) return true;
    try {
      final data = json.decode(res.body);
      throw Exception(data['detail'] ?? 'Failed to register NFC');
    } catch (_) {
      throw Exception('Failed to register NFC');
    }
  }

  static Future<bool> blockNfcCard() async {
    final headers = await getAuthHeaders();
    final res = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/students/me/block_nfc'),
      headers: headers,
      body: jsonEncode({'nfc_id': null}),
    );
    return res.statusCode == 200;
  }

  static Future<Map<String, dynamic>> getStudentProfile() async {
    final headers = await getAuthHeaders();
    final res = await http.get(Uri.parse('${AppConfig.baseUrl}/students/me'), headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
    throw Exception('Failed to load student profile');
  }

  // ============ DRIVER APIs ============

  static Future<List<Map<String, dynamic>>> getDriverTrips() async {
    final headers = await getAuthHeaders();
    final res = await http.get(Uri.parse('${AppConfig.baseUrl}/drivers/me/trips'), headers: headers);
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data);
    }
    throw Exception('Failed to load driver trips: ${res.statusCode} ${res.body}');
  }

  static Future<Map<String, dynamic>> getDriverProfile() async {
    final headers = await getAuthHeaders();
    final res = await http.get(Uri.parse('${AppConfig.baseUrl}/drivers/me'), headers: headers);
    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
    throw Exception('Failed to load driver profile');
  }

  // NEW: Active trip endpoints
  static Future<Map<String, dynamic>> createAndStartActiveTrip(String tripName) async {
    final headers = await getAuthHeaders();
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/drivers/me/trips/active'),
      headers: headers,
      body: jsonEncode({'name': tripName}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return json.decode(res.body);
    }
    throw Exception('Failed to create trip: ${res.body}');
  }

  static Future<Map<String, dynamic>> getActiveTrip() async {
    final headers = await getAuthHeaders();
    final res = await http.get(
      Uri.parse('${AppConfig.baseUrl}/drivers/me/trips/active'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
    throw Exception('No active trip');
  }

  static Future<Map<String, dynamic>> endActiveTrip() async {
    final headers = await getAuthHeaders();
    final res = await http.patch(
      Uri.parse('${AppConfig.baseUrl}/drivers/me/trips/active/end'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      return json.decode(res.body);
    }
    throw Exception('Failed to end trip');
  }

  static Future<Map<String, dynamic>> tapNfcInActiveTrip(String nfcId) async {
    final headers = await getAuthHeaders();
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/drivers/me/trips/active/tap'),
      headers: headers,
      body: jsonEncode({'nfc_id': nfcId}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return json.decode(res.body);
    }
    final errorData = json.decode(res.body);
    throw Exception(errorData['detail'] ?? 'Failed to record tap');
  }

  static Future<List<Map<String, dynamic>>> getTripDetails(String tripId) async {
    final headers = await getAuthHeaders();
    final res = await http.get(
      Uri.parse('${AppConfig.baseUrl}/drivers/me/trips/$tripId/details'),
      headers: headers,
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return List<Map<String, dynamic>>.from(data);
    }
    throw Exception('Failed to load trip details');
  }
}
