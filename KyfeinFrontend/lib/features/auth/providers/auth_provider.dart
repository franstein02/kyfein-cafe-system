import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/services/firebase_messaging_service.dart';
import '../../../core/services/rtdb_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  String? _token;
  String? _role;
  String? _divisi;
  String? _nama;
  String? _karyawanId;
  String? _fotoProfile;
  bool _isLoading = true;

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

  Future<void> _saveAuthSession(Map<String, dynamic> data,
      {String? tokenOverride}) async {
    _karyawanId =
        (data['karyawan_id'] ?? data['user_id'] ?? data['id'])?.toString();
    _token = tokenOverride ?? data['access_token']?.toString() ?? _karyawanId;
    _role = data['role']?.toString();
    _divisi = data['divisi']?.toString();
    _nama = data['nama']?.toString();
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

    if (_karyawanId != null) {
      try {
        final user = await RtdbService.getById('karyawan', _karyawanId!);
        if (user != null) {
          if (user['status_aktif'] == false) {
            await logout();
            _isLoading = false;
            notifyListeners();
            return;
          }
          await _saveAuthSession(user, tokenOverride: _token);
        }
      } catch (_) {}
      if (_token != null) {
        FirebaseMessagingService.sendTokenToBackend(_token!);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();

    // 1. Coba autentikasi via Firebase Auth bila akun terdaftar di Firebase Auth
    bool firebaseAuthOk = false;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      firebaseAuthOk = true;
    } catch (_) {
      // Lanjut cek langsung ke RTDB node karyawan (mendukung seed JSON)
    }

    // 2. Baca profil karyawan dari Firebase Realtime Database
    final list = await RtdbService.getList('karyawan');
    final matched = list.where((k) =>
        (k['email'] ?? '').toString().trim().toLowerCase() == normalizedEmail);

    if (matched.isEmpty) {
      if (firebaseAuthOk) {
        final fbUser = FirebaseAuth.instance.currentUser!;
        final id = fbUser.uid;
        final newUser = {
          'id': id,
          'role': list.isEmpty ? 'admin' : 'karyawan',
          'nama': fbUser.displayName ?? normalizedEmail.split('@').first,
          'email': normalizedEmail,
          'nomor_hp': '',
          'divisi': 'kasir',
          'status_aktif': true,
          'created_at': RtdbService.nowIso(),
          'updated_at': RtdbService.nowIso(),
        };
        await RtdbService.setRecord('karyawan', id, newUser);
        await _saveAuthSession(newUser);
        notifyListeners();
        return;
      }
      throw Exception('Email atau password salah');
    }

    final user = matched.first;
    if (user['status_aktif'] == false) {
      throw Exception('Akun tidak aktif, hubungi admin');
    }

    if (!firebaseAuthOk && (user['password'] ?? '').toString() != password) {
      throw Exception('Email atau password salah');
    }

    await _saveAuthSession(user);
    if (_token != null) {
      FirebaseMessagingService.sendTokenToBackend(_token!);
    }
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    try {
      try {
        await GoogleSignIn.instance.initialize();
      } catch (_) {}

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Gagal mendapatkan token Google');
      }

      // Sign in ke Firebase Authentication memakai Google credential
      final cred = GoogleAuthProvider.credential(idToken: idToken);
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final fbUser = userCred.user;
      final email = (fbUser?.email ?? googleUser.email).trim().toLowerCase();

      // Cocokkan dengan node `karyawan` di Firebase Realtime Database
      final list = await RtdbService.getList('karyawan');
      final matched = list.where(
          (k) => (k['email'] ?? '').toString().trim().toLowerCase() == email);

      Map<String, dynamic> userRecord;
      if (matched.isNotEmpty) {
        userRecord = matched.first;
        if (userRecord['status_aktif'] == false) {
          await GoogleSignIn.instance.signOut();
          throw Exception('Akun tidak aktif, hubungi admin');
        }
      } else {
        final id = fbUser?.uid ?? RtdbService.newId('karyawan');
        userRecord = {
          'id': id,
          'role': list.isEmpty ? 'admin' : 'karyawan',
          'nama': fbUser?.displayName ?? googleUser.displayName ?? email,
          'email': email,
          'nomor_hp': '',
          'divisi': 'kasir',
          'status_aktif': true,
          'created_at': RtdbService.nowIso(),
          'updated_at': RtdbService.nowIso(),
        };
        await RtdbService.setRecord('karyawan', id, userRecord);
      }

      await _saveAuthSession(userRecord);
      if (_token != null) {
        FirebaseMessagingService.sendTokenToBackend(_token!);
      }
      notifyListeners();
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
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _storage.deleteAll();
    notifyListeners();
  }
}
