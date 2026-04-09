import 'package:flutter/foundation.dart';

class AppConfig {
  // API Configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000', // Default for development
  );

  // Firebase Configuration
  static const bool enableFirebaseDebug = kDebugMode;

  // App Information
  static const String appName = 'NFC Bus System';
  static const String appVersion = '1.0.0';

  /// Get the API base URL dynamically if needed
  static String getApiBaseUrl() {
    // In development, you can change this to your local backend
    if (kDebugMode) {
      // Local testing
      return apiBaseUrl;
    }
    // Production
    return 'https://your-production-backend.com';
  }

  /// Endpoints
  static String get baseUrl => getApiBaseUrl();
  
  static String get studentLoginEndpoint => '$baseUrl/students/token';
  static String get driverLoginEndpoint => '$baseUrl/drivers/token';
  static String get createStudentEndpoint => '$baseUrl/students';
  static String get createDriverEndpoint => '$baseUrl/drivers';
  static String get getCurrentStudentEndpoint => '$baseUrl/students/me';
  static String get getCurrentDriverEndpoint => '$baseUrl/drivers/me';
}
