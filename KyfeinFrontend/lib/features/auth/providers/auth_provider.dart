import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/services/firebase_messaging_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _role;
  String? _divisi;
  String? _nama;
  String? _karyawanId;
  String? _fotoProfile;
  bool _isLoading = true; // Start true so splash shows while checking storage

  String? get token => _token;
  String? get role => _role;
  String? get divisi => _divisi;
  String? get nama => _nama;
  String? get karyawanId => _karyawanId;
  String? get fotoProfile => _fotoProfile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  /// Area kerja default berdasarkan divisi akun (`kasir`, `bar`, `kitchen`).
  String get divisiEfektif {
    if (_divisi == 'bar' || _divisi == 'kitchen' || _divisi == 'kasir') {
      return _divisi!;
    }
    return 'kasir';
  }

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<void> _saveAuthSession(Map<String, dynamic> data, {String? tokenOverride}) async {
    _token = tokenOverride ?? data['access_token']?.toString();
    _role = data['role']?.toString();
    _divisi = data['divisi']?.toString();
    _nama = data['nama']?.toString();
    _karyawanId = (data['karyawan_id'] ?? data['user_id'] ?? data['id'])?.toString();
    _fotoProfile = (data['foto_profile'] ?? data['foto_profile_id'])?.toString();

    if (_token != null) {
      await _storage.write(key: 'jwt_token', value: _token);
    }
    if (_role != null) {
      await _storage.write(key: 'role', value: _role);
    }
    if (_divisi != null && _divisi!.isNotEmpty) {
      await _storage.write(key: 'divisi', value: _divisi);
    } else {
      await _storage.delete(key: 'divisi');
    }
    if (_nama != null) {
      await _storage.write(key: 'nama', value: _nama);
    }
    if (_karyawanId != null) {
      await _storage.write(key: 'karyawan_id', value: _karyawanId);
    }
    if (_fotoProfile != null) {
      await _storage.write(key: 'foto_profile', value: _fotoProfile);
    }
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    _token = await _storage.read(key: 'jwt_token');
    _role = await _storage.read(key: 'role');
    _divisi = await _storage.read(key: 'divisi');
    _nama = await _storage.read(key: 'nama');
    _karyawanId = await _storage.read(key: 'karyawan_id');
    _fotoProfile = await _storage.read(key: 'foto_profile');

    if (_token != null) {
      try {
        final meResp = await http
            .get(Uri.parse(ApiEndpoints.me), headers: authHeaders)
            .timeout(const Duration(seconds: 5));
        if (meResp.statusCode == 200) {
          final meData = jsonDecode(meResp.body) as Map<String, dynamic>;
          await _saveAuthSession(meData, tokenOverride: _token);
        } else if (meResp.statusCode == 401 || meResp.statusCode == 403) {
          await logout();
          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (_) {
        // Pertahankan sesi tersimpan bila server sementara tidak terjangkau.
      }
      if (_token != null) {
        FirebaseMessagingService.sendTokenToBackend(_token!);
      }
    }

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
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveAuthSession(data);

        if (_token != null) {
          FirebaseMessagingService.sendTokenToBackend(_token!);
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

  Future<void> loginWithGoogle() async {
    try {
      try {
        await GoogleSignIn.instance.initialize();
      } catch (_) {
        // Already initialized or ignoring error
      }
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Gagal mendapatkan token Google');
      }

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.googleLogin),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _saveAuthSession(data);

        if (_token != null) {
          FirebaseMessagingService.sendTokenToBackend(_token!);
        }

        notifyListeners();
      } else if (response.statusCode == 403) {
        await GoogleSignIn.instance.signOut();
        throw Exception('Akun tidak aktif, hubungi admin');
      } else {
        await GoogleSignIn.instance.signOut();
        final body = jsonDecode(response.body);
        throw Exception(body['detail'] ?? 'Gagal login menggunakan Google');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Exception:')) rethrow;
      throw Exception('Gagal login dengan Google: $e');
    }
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _divisi = null;
    _nama = null;
    _karyawanId = null;
    _fotoProfile = null;
    await _storage.deleteAll();
    notifyListeners();
  }
}
