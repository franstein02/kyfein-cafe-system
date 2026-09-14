import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final StorageService _storage = StorageService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _userName;
  String? _userRole;
  bool _isAuthenticated = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get userName => _userName;
  String? get userRole => _userRole;
  bool get isAuthenticated => _isAuthenticated;

  Future<void> checkAuthStatus() async {
    final token = await _storage.getToken();
    if (token != null) {
      _isAuthenticated = true;
      _userName = await _storage.getUserName();
      _userRole = await _storage.getRole();
    } else {
      _isAuthenticated = false;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiEndpoints.login,
        body: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.saveSession(
          token: data['access_token'],
          userId: data['user_id'],
          name: data['nama'],
          role: data['role'],
        );
        _userName = data['nama'];
        _userRole = data['role'];
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        _errorMessage = errorData['detail'] ?? 'Login gagal. Periksa kembali email dan password.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Gagal terhubung ke server backend: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearSession();
    _isAuthenticated = false;
    _userName = null;
    _userRole = null;
    notifyListeners();
  }
}
