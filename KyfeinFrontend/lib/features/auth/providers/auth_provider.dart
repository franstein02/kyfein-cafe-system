import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _role;
  String? _nama;
  String? _karyawanId;
  String? _fotoProfile;
  bool _isLoading = true; // Start true so splash shows while checking storage

  String? get token => _token;
  String? get role => _role;
  String? get nama => _nama;
  String? get karyawanId => _karyawanId;
  String? get fotoProfile => _fotoProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    _token = await _storage.read(key: 'jwt_token');
    _role = await _storage.read(key: 'role');
    _nama = await _storage.read(key: 'nama');
    _karyawanId = await _storage.read(key: 'karyawan_id');
    _fotoProfile = await _storage.read(key: 'foto_profile');
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiEndpoints.login),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _role = data['role'];
        _nama = data['nama'];
        _karyawanId = data['karyawan_id']?.toString();
        _fotoProfile = data['foto_profile'];

        await _storage.write(key: 'jwt_token', value: _token);
        await _storage.write(key: 'role', value: _role);
        await _storage.write(key: 'nama', value: _nama);
        await _storage.write(key: 'karyawan_id', value: _karyawanId);
        if (_fotoProfile != null) {
          await _storage.write(key: 'foto_profile', value: _fotoProfile);
        }

        notifyListeners();
      } else if (response.statusCode == 403) {
        throw Exception('Akun tidak aktif, hubungi admin');
      } else {
        throw Exception('Email atau password salah');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Exception:')) rethrow;
      throw Exception('Tidak bisa terhubung ke server, cek koneksi WiFi cafe');
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _nama = null;
    _karyawanId = null;
    _fotoProfile = null;
    await _storage.deleteAll();
    notifyListeners();
  }
}
