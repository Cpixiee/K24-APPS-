import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apps_k24/models/dashboard_data.dart';
import 'package:apps_k24/services/http_debug_logger.dart';


class ApiService {
  static String? _customBaseUrl;
  static String? _serverLanIp;
  static const String _publicServerUrl = 'http://103.236.140.19:9001/api';
  static const String _knownServerIp = '103.236.140.19';
  static const int _serverPort = 9001;

  static String? get serverLanIp => _serverLanIp;

  // Initialize the API Service, loading custom base URL if saved
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty && savedUrl != _publicServerUrl) {
        try {
          final response = await http
              .get(Uri.parse('$savedUrl/health'))
              .timeout(const Duration(milliseconds: 1000));
          if (response.statusCode == 200) {
            _customBaseUrl = savedUrl;
            return;
          }
        } catch (_) {
          await prefs.remove('custom_base_url');
        }
      }
    } catch (_) {}

    // Default directly to Public Server instantly (no wasted delay loop on local IPs)
    _customBaseUrl = _publicServerUrl;
  }

  /// Fast public server connection check
  static Future<void> _autoDiscoverServer() async {
    _customBaseUrl = _publicServerUrl;
  }

  static Future<void> fetchServerLanIp() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['lan_ip'] != null) {
          _serverLanIp = data['lan_ip'];
          debugPrint('[API] Dynamic Server LAN IP resolved: $_serverLanIp');
        }
      }
    } catch (e) {
      debugPrint('[API] Failed to dynamically resolve server LAN IP: $e');
    }
  }

  // Configures the API Base URL dynamically
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    return _publicServerUrl;
  }

  // Set or clear a custom API Base URL
  static Future<void> setCustomBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url.trim().isEmpty) {
        await prefs.remove('custom_base_url');
        _customBaseUrl = null;
      } else {
        String formattedUrl = url.trim();
        if (!formattedUrl.startsWith('http://') &&
            !formattedUrl.startsWith('https://')) {
          formattedUrl = 'http://$formattedUrl';
        }
        if (!formattedUrl.endsWith('/api') &&
            !formattedUrl.endsWith('/api/')) {
          formattedUrl = formattedUrl.endsWith('/')
              ? '${formattedUrl}api'
              : '$formattedUrl/api';
        }
        await prefs.setString('custom_base_url', formattedUrl);
        _customBaseUrl = formattedUrl;
      }
    } catch (_) {}
  }

  // Retrieve stored JWT token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Save authentication details in local storage
  static Future<void> saveAuthData(String token, String name, String email, String role, {String? phone, String? plate, String? rating}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('driver_name', name);
    await prefs.setString('driver_email', email);
    await prefs.setString('user_role', role);
    if (phone != null) await prefs.setString('driver_phone', phone);
    if (plate != null) await prefs.setString('driver_plate', plate);
    if (rating != null) await prefs.setString('driver_rating', rating);
  }

  // Clear authentication details on logout
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('driver_name');
    await prefs.remove('driver_email');
    await prefs.remove('user_role');
    await prefs.remove('driver_phone');
    await prefs.remove('driver_plate');
    await prefs.remove('driver_rating');
    await prefs.remove('user_profile_pic_path');
    await prefs.remove('user_avatar_index');
  }

  // Retrieve stored user role
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  // Retrieve stored user name
  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_name');
  }

  // Retrieve stored user email
  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_email');
  }

  // Retrieve stored user phone
  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_phone');
  }

  // Retrieve stored user license plate
  static Future<String?> getPlate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_plate');
  }

  // Retrieve stored user rating
  static Future<String?> getRating() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('driver_rating');
  }

  // Check if driver is currently logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Validate stored session token for auto-login
  static Future<bool> validateSession() async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) return false;
    
    try {
      final url = Uri.parse('$baseUrl/driver/dashboard');
      final headers = await _getHeaders(authRequired: true);
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 401) {
        // Token is expired or invalid on backend
        await clearAuthData();
        return false;
      }
      // For temporary server errors or other status codes, keep session active
      return true;
    } catch (_) {
      // Offline / network timeout: treat saved token as valid
      return true;
    }
  }

  // Header factory to automatically attach Bearer JWT token when available
  static Future<Map<String, String>> _getHeaders({bool authRequired = true}) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
    };

    if (authRequired) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Parse backend error messages
  static String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['message'] ?? 'Terjadi kesalahan sistem (${response.statusCode})';
    } catch (_) {
      return 'Terjadi kesalahan server (${response.statusCode})';
    }
  }

  // HTTP Request Helper with fast 10s default timeout & fallback
  static Future<http.Response> _postWithRetry(Uri url, {required Map<String, String> headers, required String body, Duration timeout = const Duration(seconds: 10)}) async {
    return HttpDebugLogger.wrapRequest(
      method: 'POST',
      url: url,
      headers: headers,
      body: body,
      requestFn: () async {
        try {
          return await http.post(url, headers: headers, body: body).timeout(timeout);
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('timeout') || errStr.contains('socketexception') || errStr.contains('clientexception')) {
            throw Exception('Koneksi internet lambat / terputus. Silakan periksa jaringan Anda.');
          }
          if (!kIsWeb && !url.host.contains(_knownServerIp)) {
            final fallbackUrl = Uri.parse(url.toString().replaceFirst(RegExp(r'http://[^/]+'), 'http://$_knownServerIp:$_serverPort'));
            debugPrint('[API Fallback] Retrying POST on known server IP: $fallbackUrl');
            _customBaseUrl = 'http://$_knownServerIp:$_serverPort/api';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('custom_base_url', _customBaseUrl!);
            return await http.post(fallbackUrl, headers: headers, body: body).timeout(const Duration(seconds: 8));
          }
          rethrow;
        }
      },
    );
  }

  static Future<http.Response> _getWithRetry(Uri url, {required Map<String, String> headers, Duration timeout = const Duration(seconds: 10)}) async {
    return HttpDebugLogger.wrapRequest(
      method: 'GET',
      url: url,
      headers: headers,
      requestFn: () async {
        try {
          return await http.get(url, headers: headers).timeout(timeout);
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('timeout') || errStr.contains('socketexception') || errStr.contains('clientexception')) {
            throw Exception('Koneksi internet lambat / terputus. Silakan periksa jaringan Anda.');
          }
          if (!kIsWeb && !url.host.contains(_knownServerIp)) {
            final fallbackUrl = Uri.parse(url.toString().replaceFirst(RegExp(r'http://[^/]+'), 'http://$_knownServerIp:$_serverPort'));
            debugPrint('[API Fallback] Retrying GET on known server IP: $fallbackUrl');
            _customBaseUrl = 'http://$_knownServerIp:$_serverPort/api';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('custom_base_url', _customBaseUrl!);
            return await http.get(fallbackUrl, headers: headers).timeout(const Duration(seconds: 8));
          }
          rethrow;
        }
      },
    );
  }

  static Future<http.Response> _putWithRetry(Uri url, {required Map<String, String> headers, required String body, Duration timeout = const Duration(seconds: 10)}) async {
    return HttpDebugLogger.wrapRequest(
      method: 'PUT',
      url: url,
      headers: headers,
      body: body,
      requestFn: () async {
        try {
          return await http.put(url, headers: headers, body: body).timeout(timeout);
        } catch (e) {
          final errStr = e.toString().toLowerCase();
          if (errStr.contains('timeout') || errStr.contains('socketexception') || errStr.contains('clientexception')) {
            throw Exception('Koneksi internet lambat / terputus. Silakan periksa jaringan Anda.');
          }
          if (!kIsWeb && !url.host.contains(_knownServerIp)) {
            final fallbackUrl = Uri.parse(url.toString().replaceFirst(RegExp(r'http://[^/]+'), 'http://$_knownServerIp:$_serverPort'));
            debugPrint('[API Fallback] Retrying PUT on known server IP: $fallbackUrl');
            _customBaseUrl = 'http://$_knownServerIp:$_serverPort/api';
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('custom_base_url', _customBaseUrl!);
            return await http.put(fallbackUrl, headers: headers, body: body).timeout(const Duration(seconds: 8));
          }
          rethrow;
        }
      },
    );
  }

  // Register a new driver via Email, Password, Vehicle Type, and Documents
  static Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String plateNumber,
    required String password,
    required String vehicleType,
    required String ktpUrl,
    required String simUrl,
    required String stnkUrl,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');
    final headers = await _getHeaders(authRequired: false);
    final body = jsonEncode({
      'name': name,
      'email': email,
      'phone': phone,
      'plate_number': plateNumber,
      'password': password,
      'vehicle_type': vehicleType,
      'ktp_url': ktpUrl,
      'sim_url': simUrl,
      'stnk_url': stnkUrl,
    });

    try {
      final response = await _postWithRetry(url, headers: headers, body: body, timeout: const Duration(seconds: 8));
      if (response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        final token = resData['data']['token'];
        final driverName = resData['data']['driver']['name'];
        final driverEmail = resData['data']['driver']['email'];
        final role = resData['data']['role'] ?? 'DRIVER';
        await saveAuthData(token, driverName, driverEmail, role);
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Log in a driver via Email and Password (8s fast timeout)
  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final headers = await _getHeaders(authRequired: false);
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    try {
      final response = await _postWithRetry(url, headers: headers, body: body, timeout: const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final token = resData['data']['token'];
        final driverName = resData['data']['driver']['name'];
        final driverEmail = resData['data']['driver']['email'];
        final role = resData['data']['role'] ?? 'DRIVER';
        await saveAuthData(token, driverName, driverEmail, role);
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Authenticate driver using Google credentials (mock id_token verification)
  static Future<void> loginWithGoogle({
    required String email,
    required String name,
  }) async {
    final url = Uri.parse('$baseUrl/auth/google');
    final headers = await _getHeaders(authRequired: false);
    final body = jsonEncode({
      'id_token': 'mock_google_id_token_${DateTime.now().millisecondsSinceEpoch}',
      'email': email,
      'name': name,
    });

    try {
      final response = await _postWithRetry(url, headers: headers, body: body, timeout: const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final token = resData['data']['token'];
        final driverName = resData['data']['driver']['name'];
        final driverEmail = resData['data']['driver']['email'];
        final role = resData['data']['role'] ?? 'DRIVER';
        await saveAuthData(token, driverName, driverEmail, role);
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ---------------------------------------------------------
  // Dashboard & Driver Operations
  // ---------------------------------------------------------

  // Fetch all dashboard aggregations
  static Future<DashboardDataModel> getDashboard() async {
    final url = Uri.parse('$baseUrl/driver/dashboard');
    final headers = await _getHeaders(authRequired: true);

    try {
      final response = await _getWithRetry(url, headers: headers);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return DashboardDataModel.fromJson(resData['data']);
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Toggle active driver status (online / offline)
  static Future<void> toggleActive(bool isActive) async {
    final url = Uri.parse('$baseUrl/driver/toggle-active');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({'is_active': isActive});

    try {
      final response = await _postWithRetry(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Mark active order delivery completed
  static Future<void> completeOrder(int orderId) async {
    final url = Uri.parse('$baseUrl/driver/orders/$orderId/complete');
    final headers = await _getHeaders(authRequired: true);

    try {
      final response = await _postWithRetry(url, headers: headers, body: '');
      if (response.statusCode != 200) {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ---------------------------------------------------------
  // Admin Operations
  // ---------------------------------------------------------

  // Fetch admin dashboard stats
  static Future<AdminStatsModel> getAdminStats() async {
    final url = Uri.parse('$baseUrl/admin/stats');
    final headers = await _getHeaders(authRequired: true);

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return AdminStatsModel.fromJson(resData['data']);
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Fetch all registered drivers for Admin
  static Future<List<DriverModel>> getDrivers() async {
    final url = Uri.parse('$baseUrl/admin/drivers');
    final headers = await _getHeaders(authRequired: true);

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final list = resData['data'] as List<dynamic>? ?? [];
        return list.map((e) => DriverModel.fromJson(e)).toList();
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Fetch all registered mitra (partners) for Admin
  static Future<List<MitraModel>> getMitra() async {
    final url = Uri.parse('$baseUrl/admin/mitra');
    final headers = await _getHeaders(authRequired: true);

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final list = resData['data'] as List<dynamic>? ?? [];
        return list.map((e) => MitraModel.fromJson(e)).toList();
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Create a new mitra (partner)
  static Future<void> createMitra({
    required String username,
    required String email,
    required String name,
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/admin/mitra');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({
      'username': username,
      'email': email,
      'name': name,
      'phone': phone,
      'password': password,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 201) {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Change user password
  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('$baseUrl/user/change-password');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({
      'old_password': oldPassword,
      'new_password': newPassword,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Register face template
  static Future<void> registerFace(String faceData) async {
    final url = Uri.parse('$baseUrl/user/face-register');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({'face_data': faceData});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Log in via face verification
  static Future<void> loginWithFace({
    required String username,
    required String faceData,
  }) async {
    final url = Uri.parse('$baseUrl/auth/face-login');
    final headers = await _getHeaders(authRequired: false);
    final body = jsonEncode({
      'username': username,
      'face_data': faceData,
    });

    try {
      final response = await http.post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 7), onTimeout: () {
            throw Exception('Koneksi timeout. Pastikan server Go menyala dan HP terhubung ke Wi-Fi laptop Anda.');
          });
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        final token = resData['data']['token'];
        final driverName = resData['data']['driver']['name'];
        final driverEmail = resData['data']['driver']['email'];
        final role = resData['data']['role'] ?? 'DRIVER';
        await saveAuthData(token, driverName, driverEmail, role);
      } else {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Update user profile details
  static Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? plateNumber,
    String? profilePicture,
  }) async {
    final url = Uri.parse('$baseUrl/user/update-profile');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({
      'name': name,
      'email': email,
      'phone': phone,
      'plate_number': plateNumber ?? '',
      'profile_picture': profilePicture ?? '',
    });

    try {
      debugPrint("[API Request] POST $url");
      debugPrint("[API Request Payload] name: $name, email: $email, phone: $phone, plate: $plateNumber, picture length: ${profilePicture?.length ?? 0} chars");
      
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        final parsedError = _parseError(response);
        debugPrint("[API Error Response] Status Code: ${response.statusCode}, Body: ${response.body}, Message: $parsedError");
        throw Exception(parsedError);
      }
      debugPrint("[API Success Response] Status Code: 200");
    } catch (e) {
      debugPrint("[API Exception] Error updating profile: $e");
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Update order status to PICKUP
  static Future<void> updateOrderPickup({
    required int orderId,
    required String pickupPhoto,
    String? pickupNote,
  }) async {
    final url = Uri.parse('$baseUrl/driver/orders/$orderId/pickup');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({
      'pickup_photo': pickupPhoto,
      'pickup_note': pickupNote ?? '',
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Update order arrival proof photo
  static Future<void> updateOrderArrived({
    required int orderId,
    required String arrivedPhoto,
    String? arrivedNote,
  }) async {
    final url = Uri.parse('$baseUrl/driver/orders/$orderId/arrived');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({
      'arrived_photo': arrivedPhoto,
      'arrived_note': arrivedNote ?? '',
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Reject order pickup/stop
  static Future<void> updateOrderReject({
    required int orderId,
    required String rejectPhoto,
    required String rejectNote,
    required String rejectReason,
  }) async {
    final url = Uri.parse('$baseUrl/driver/orders/$orderId/reject');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({
      'reject_photo': rejectPhoto,
      'reject_note': rejectNote,
      'reject_reason': rejectReason,
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Upload facture physical copy
  static Future<void> updateOrderFacture({
    required int orderId,
    required String facturePhoto,
  }) async {
    final url = Uri.parse('$baseUrl/driver/orders/$orderId/facture');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({
      'facture_photo': facturePhoto,
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Submit complete driver unboxing checklist, signature & facture proof photo
  static Future<void> submitUnboxAndFacture({
    required int orderId,
    required String checkedInvoices,
    required String facturePhoto,
    String? signaturePhoto,
    String? extraItemsNote,
    String? extraItemsPhoto,
    String? handoverPhoto,
  }) async {
    final url = Uri.parse('$baseUrl/public/orders/$orderId/unbox');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'checked_invoices': checkedInvoices,
      'extra_items_note': extraItemsNote ?? '',
      'extra_items_photo_url': extraItemsPhoto ?? facturePhoto,
      'facture_photo_url': facturePhoto,
      'signature_photo_url': signaturePhoto ?? '',
      'handover_photo_url': handoverPhoto ?? '',
    });

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Delay / wait unboxing order
  static Future<void> waitUnboxOrder(int orderId, String reason) async {
    final url = Uri.parse('$baseUrl/public/orders/$orderId/wait-unbox');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'reason': reason});

    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Complete POD return stage with POD signature
  static Future<void> completePODOrder({
    required int orderId,
    required String podSignaturePhoto,
  }) async {
    final url = Uri.parse('$baseUrl/driver/orders/$orderId/pod-complete');
    final headers = await _getHeaders(authRequired: true);
    final body = jsonEncode({
      'pod_signature_photo_url': podSignaturePhoto,
    });

    final response = await _postWithRetry(url, headers: headers, body: body);
    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // Fetch driver notifications
  static Future<List<dynamic>> getNotifications() async {
    final url = Uri.parse('$baseUrl/driver/notifications');
    final headers = await _getHeaders(authRequired: true);

    try {
      final response = await _getWithRetry(url, headers: headers);
      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        return resData['data'] as List<dynamic>? ?? [];
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('[Notifications] Connection warning swallowed gracefully: $e');
      return [];
    }
  }

  // Mark all notifications as read
  static Future<void> markNotificationsRead() async {
    final url = Uri.parse('$baseUrl/driver/notifications/read');
    final headers = await _getHeaders(authRequired: true);

    try {
      final response = await http.post(url, headers: headers);
      if (response.statusCode != 200) {
        throw Exception(_parseError(response));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Update Driver Live Location (POST /driver/location)
  static Future<bool> updateDriverLocation(double latitude, double longitude) async {
    final url = Uri.parse('$baseUrl/driver/location');
    final headers = await _getHeaders(authRequired: true);

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Location] Location update swallowed gracefully: $e');
      return false;
    }
  }
}
