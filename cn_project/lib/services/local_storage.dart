import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _keyConfigured = 'configured_card_uid';
  
  static Future<void> saveConfiguredCard(String uid) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyConfigured, uid);
  }

  static Future<String?> getConfiguredCard() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyConfigured);
  }

  static Future<void> clearConfiguredCard() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyConfigured);
  }

  static const keyToken = 'auth_token';
  static const keyRole = 'auth_role';
  
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyToken);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyToken);
  }

  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyRole, role);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyRole);
  }

  static Future<void> clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyRole);
  }

  static const keyProfile = 'student_profile';
  
  static Future<void> saveProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyProfile, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(keyProfile);
    if (str == null) return null;
    return jsonDecode(str);
  }

  static const keyHiddenTrips = 'hidden_trips';
  
  static Future<void> saveHiddenTrips(List<String> tripIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyHiddenTrips, jsonEncode(tripIds));
  }

  static Future<List<String>> getHiddenTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(keyHiddenTrips);
    if (str == null) return [];
    return List<String>.from(jsonDecode(str));
  }

  // NEW: Clear all stored data (for logout)
  static Future<void> clearAll() async {
    await clearToken();
    await clearRole();
    await clearConfiguredCard();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyProfile);
    await prefs.remove(keyHiddenTrips);
  }
}
