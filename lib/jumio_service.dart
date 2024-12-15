import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:js/js.dart';
import 'package:jumio_mobile_sdk/jumio_mobile_sdk.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:js' as js;

@JS('JumioSDK')
external void initializeJumioWeb(String authToken, dynamic config);

class VerificationResult {
  final String status;
  final Map<String, dynamic> data;

  VerificationResult({
    required this.status,
    required this.data,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      status: json['status'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

class JumioService {
  final String _baseUrl = 'https://api.jumio.com';
  final _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'jumio_auth_token';
  static const String _tokenExpiryKey = 'jumio_token_expiry';

  Future<String> getAuthToken() async {
    // Try to get existing token
    final existingToken = await _storage.read(key: _tokenKey);
    final expiryString = await _storage.read(key: _tokenExpiryKey);
    
    // Check if token exists and is still valid
    if (existingToken != null && expiryString != null) {
      final expiry = DateTime.parse(expiryString);
      if (DateTime.now().isBefore(expiry)) {
        return existingToken;
      }
    }

    // If no valid token exists, get a new one
    return _fetchNewToken();
  }

  Future<String> _fetchNewToken() async {
    final apiToken = dotenv.env['JUMIO_API_TOKEN'];
    final apiSecret = dotenv.env['JUMIO_API_SECRET'];
    
    final response = await http.post(
      Uri.parse('$_baseUrl/oauth2/token'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$apiToken:$apiSecret'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final token = data['access_token'];
      final expiresIn = data['expires_in'] as int;
      
      // Calculate expiry time
      final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
      
      // Store token and expiry
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _tokenExpiryKey, value: expiryTime.toIso8601String());
      
      return token;
    } else {
      throw Exception('Failed to obtain auth token');
    }
  }

  Future<void> clearStoredToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tokenExpiryKey);
  }

  Future<void> _initializeJumioWeb(String token) async {
    // Web SDK configuration
    final config = js.JsObject.jsify({
      'customerInternalReference': 'CUSTOMER_INTERNAL_REFERENCE',
      'locale': 'en',
      'dataCenter': 'US',
      'callback': allowInterop((result) {
        // Handle the verification result
        print('Verification completed: $result');
      }),
      'errorCallback': allowInterop((error) {
        // Handle any errors
        print('Error during verification: $error');
      }),
    });

    try {
      // Initialize the Jumio Web SDK
      initializeJumioWeb(token, config);
    } catch (e) {
      throw Exception('Failed to initialize Jumio Web SDK: $e');
    }
  }

  Future<void> _initializeJumioMobile(String token) async {
    try {
      // Configure the Jumio Mobile SDK
      final config = {
        'authorizationToken': token,
        'dataCenter': 'US',
        'callback': (result) {
          // Handle the verification result
          print('Verification completed: $result');
        },
      };

      // Initialize the SDK
      await JumioMobileSDK.init(config);

      // Start the verification process
      await JumioMobileSDK.start();
    } catch (e) {
      throw Exception('Failed to initialize Jumio Mobile SDK: $e');
    }
  }

  void _handleVerificationResult(dynamic result) {
    if (result is Map<String, dynamic>) {
      final verificationResult = VerificationResult.fromJson(result);
      // Process the verification result
      if (verificationResult.status == 'SUCCESS') {
        // Handle successful verification
      } else {
        // Handle verification failure
      }
    }
  }

  void _handleVerificationError(dynamic error) {
    // Log and handle the error
    print('Verification error: $error');
  }

  // Add error handling for secure storage
  Future<void> _handleStorageError(dynamic error) async {
    print('Storage error: $error');
    // Clear any potentially corrupted data
    await clearStoredToken();
    throw Exception('Failed to access secure storage: $error');
  }

  // Method to check if token exists
  Future<bool> hasValidToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final expiryString = await _storage.read(key: _tokenExpiryKey);
      
      if (token == null || expiryString == null) {
        return false;
      }

      final expiry = DateTime.parse(expiryString);
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      await _handleStorageError(e);
      return false;
    }
  }

  // ... rest of your JumioService class implementation
}
