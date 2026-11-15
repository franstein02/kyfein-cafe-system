import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class AttendanceProvider with ChangeNotifier {
  AuthProvider? _auth;

  // ── State Jadwal & Pengajuan ───────────────────────────────────────────────
  List<Map<String, dynamic>> _karyawan = [];
  List<Map<String, dynamic>> _shiftTemplates = [];
  List<Map<String, dynamic>> _allJadwal = [];
  List<Map<String, dynamic>> _jadwalMendatang = [];
  List<Map<String, dynamic>> _requestOff = [];
  List<Map<String, dynamic>> _tukarShift = [];
  List<Map<String, dynamic>> _izinTelat = [];
  List<Map<String, dynamic>> _izinTidakMasuk = [];

  // ── State Konfigurasi Lokasi & Rekap Absensi ───────────────────────────────
  Map<String, dynamic>? _konfigurasiLokasi;
  List<Map<String, dynamic>> _absensiList = [];
  Map<String, dynamic>? _absensiStatus;

  bool _isLoading = false;
  String? _error;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get karyawan => _karyawan;
  List<Map<String, dynamic>> get shiftTemplates => _shiftTemplates;
  List<Map<String, dynamic>> get allJadwal => _allJadwal;
  List<Map<String, dynamic>> get jadwalMendatang => _jadwalMendatang;
  List<Map<String, dynamic>> get requestOff => _requestOff;
  List<Map<String, dynamic>> get tukarShift => _tukarShift;
  List<Map<String, dynamic>> get izinTelat => _izinTelat;
  List<Map<String, dynamic>> get izinTidakMasuk => _izinTidakMasuk;
  Map<String, dynamic>? get konfigurasiLokasi => _konfigurasiLokasi;
  List<Map<String, dynamic>> get absensiList => _absensiList;
  Map<String, dynamic>? get absensiStatus => _absensiStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get currentUserId => _auth?.karyawanId;
  Map<String, String> get headers => _auth?.authHeaders ?? {
        'Content-Type': 'application/json',
      };

  void updateAuth(AuthProvider auth) {
    _auth = auth;
  }

  String extractErrorMessage(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['detail'] != null) {
        final detail = d['detail'];
        return detail is String ? detail : detail.toString();
      }
      return 'Gagal (${r.statusCode})';
    } catch (_) {
      return 'Gagal (${r.statusCode})';
    }
  }

  // ── Upload & Ambil Foto ────────────────────────────────────────────────────
  Future<String> uploadFoto(XFile file, {String jenis = 'izin'}) async {
    final bytes = await file.readAsBytes();
    final nama = file.name.toLowerCase();
    final tipe = nama.endsWith('.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');

    final req =
        http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/foto'));
    req.headers['Accept'] = 'application/json';
    final authHeader = headers['Authorization'];
    if (authHeader != null) req.headers['Authorization'] = authHeader;
    req.fields['jenis'] = jenis;
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: file.name.isNotEmpty ? file.name : 'foto.jpg',
      contentType: tipe,
    ));

    final res = await http.Response.fromStream(
      await req.send().timeout(const Duration(seconds: 15)),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw extractErrorMessage(res);
    }
    final d = jsonDecode(res.body);
    final id = d is Map ? (d['id'] ?? d['foto_id']) : null;
    if (id == null) throw 'Respons foto tidak berisi ID';
    return id.toString();
  }

  Future<Uint8List?> fetchFotoBytes(String fotoId) async {
    final resp = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/foto/$fotoId'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      return resp.bodyBytes;
    }
    return null;
  }

  // ── Admin & Kasir Jadwal Operations ────────────────────────────────────────
  Future<void> loadAdminJadwalData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await Future.wait([
        http.get(Uri.parse('${ApiEndpoints.karyawan}/'), headers: headers),
        http.get(Uri.parse('${ApiEndpoints.jadwal}/'), headers: headers),
        http.get(Uri.parse(ApiEndpoints.requestOff), headers: headers),
        http.get(Uri.parse('${ApiEndpoints.tukarShift}?status=pending'),
            headers: headers),
        http.get(Uri.parse('${ApiEndpoints.izinTelat}?status=pending'),
            headers: headers),
        http.get(Uri.parse('${ApiEndpoints.izinTidakMasuk}?status=pending'),
            headers: headers),
        http.get(Uri.parse(ApiEndpoints.shiftTemplate), headers: headers),
      ]).timeout(const Duration(seconds: 10));

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (res[0].statusCode == 200) {
        _karyawan = (jsonDecode(res[0].body) as List)
            .cast<Map<String, dynamic>>()
            .where((e) => e['status_aktif'] != false && e['role'] == 'karyawan')
            .toList();
      }
      if (res[1].statusCode == 200) {
        final all =
            (jsonDecode(res[1].body) as List).cast<Map<String, dynamic>>();
        _allJadwal = all;
        _jadwalMendatang = all
            .where((e) => (e['tanggal'] ?? '').toString().compareTo(today) >= 0)
            .toList()
          ..sort((a, b) {
            final cmpTgl = (a['tanggal'] ?? '')
                .toString()
                .compareTo((b['tanggal'] ?? '').toString());
            if (cmpTgl != 0) return cmpTgl;
            return (a['shift'] ?? '')
                .toString()
                .compareTo((b['shift'] ?? '').toString());
          });
      }
      if (res[2].statusCode == 200) {
        _requestOff = (jsonDecode(res[2].body) as List)
            .cast<Map<String, dynamic>>()
            .where((e) => (e['tanggal'] ?? '').toString().compareTo(today) >= 0)
            .toList();
      }
      if (res[3].statusCode == 200) {
        _tukarShift =
            (jsonDecode(res[3].body) as List).cast<Map<String, dynamic>>();
      }
      if (res[4].statusCode == 200) {
        _izinTelat =
            (jsonDecode(res[4].body) as List).cast<Map<String, dynamic>>();
      }
      if (res[5].statusCode == 200) {
        _izinTidakMasuk =
            (jsonDecode(res[5].body) as List).cast<Map<String, dynamic>>();
      }
      if (res[6].statusCode == 200) {
        _shiftTemplates =
            (jsonDecode(res[6].body) as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {
      _error = 'Gagal memuat data: cek koneksi ke server';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<http.Response> updateShiftTemplate({
    required String shift,
    required String jamMulai,
    required String jamSelesai,
  }) async {
    final res = await http
        .put(
          Uri.parse(ApiEndpoints.shiftTemplateByKey(shift)),
          headers: headers,
          body: jsonEncode({
            'jam_mulai': jamMulai,
            'jam_selesai': jamSelesai,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final updated = jsonDecode(res.body) as Map<String, dynamic>;
      final idx = _shiftTemplates.indexWhere((t) => t['shift'] == shift);
      if (idx >= 0) {
        _shiftTemplates[idx] = updated;
      } else {
        _shiftTemplates.add(updated);
      }
      notifyListeners();
    }
    return res;
  }

  Future<void> loadKasirJadwalData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await Future.wait([
        http.get(Uri.parse('${ApiEndpoints.jadwal}/'), headers: headers),
        http.get(Uri.parse(ApiEndpoints.requestOff), headers: headers),
        http.get(Uri.parse(ApiEndpoints.tukarShift), headers: headers),
        http.get(Uri.parse(ApiEndpoints.izinTelat), headers: headers),
        http.get(Uri.parse(ApiEndpoints.izinTidakMasuk), headers: headers),
      ]).timeout(const Duration(seconds: 10));

      if (res[0].statusCode == 200) {
        _allJadwal =
            (jsonDecode(res[0].body) as List).cast<Map<String, dynamic>>();
      } else {
        _error = extractErrorMessage(res[0]);
      }
      if (res[1].statusCode == 200) {
        _requestOff =
            (jsonDecode(res[1].body) as List).cast<Map<String, dynamic>>();
      }
      if (res[2].statusCode == 200) {
        _tukarShift =
            (jsonDecode(res[2].body) as List).cast<Map<String, dynamic>>();
      }
      if (res[3].statusCode == 200) {
        _izinTelat =
            (jsonDecode(res[3].body) as List).cast<Map<String, dynamic>>();
      }
      if (res[4].statusCode == 200) {
        _izinTidakMasuk =
            (jsonDecode(res[4].body) as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {
      _error = 'Tidak bisa terhubung ke server';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<http.Response> createJadwal(Map<String, dynamic> body) {
    return http
        .post(
          Uri.parse('${ApiEndpoints.jadwal}/'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> approvalTukarShift(String id, String status) {
    return http
        .put(
          Uri.parse(ApiEndpoints.approvalTukarShift(id)),
          headers: headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> approvalIzinTelat(String id, String status) {
    return http
        .put(
          Uri.parse(ApiEndpoints.approvalIzinTelat(id)),
          headers: headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> approvalIzinTidakMasuk(String id, String status) {
    return http
        .put(
          Uri.parse(ApiEndpoints.approvalIzinTidakMasuk(id)),
          headers: headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> deleteRequestOff(String id) {
    return http
        .delete(
          Uri.parse('${ApiEndpoints.requestOff}/$id'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<http.Response> postEndpoint(String url, Map<String, dynamic> body) {
    return http
        .post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
  }

  // ── Admin Absensi & Konfigurasi Lokasi ─────────────────────────────────────
  Future<void> loadAdminAbsensiData(String dateStr) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(ApiEndpoints.konfigurasiLokasi), headers: headers),
        http.get(Uri.parse('${ApiEndpoints.absensi}?tanggal=$dateStr'),
            headers: headers),
        http.get(Uri.parse('${ApiEndpoints.karyawan}/'), headers: headers),
        http.get(Uri.parse('${ApiEndpoints.jadwal}/?tanggal=$dateStr'),
            headers: headers),
        http.get(Uri.parse(ApiEndpoints.izinTelat), headers: headers),
        http.get(Uri.parse(ApiEndpoints.izinTidakMasuk), headers: headers),
        http.get(Uri.parse(ApiEndpoints.tukarShift), headers: headers),
      ]).timeout(const Duration(seconds: 10));

      if (responses[0].statusCode == 200) {
        _konfigurasiLokasi =
            jsonDecode(responses[0].body) as Map<String, dynamic>;
      }
      if (responses[1].statusCode == 200) {
        _absensiList = (jsonDecode(responses[1].body) as List)
            .cast<Map<String, dynamic>>();
      }
      if (responses[2].statusCode == 200) {
        _karyawan = (jsonDecode(responses[2].body) as List)
            .cast<Map<String, dynamic>>();
      }
      if (responses[3].statusCode == 200) {
        _allJadwal = (jsonDecode(responses[3].body) as List)
            .cast<Map<String, dynamic>>();
      }
      if (responses[4].statusCode == 200) {
        _izinTelat = (jsonDecode(responses[4].body) as List)
            .cast<Map<String, dynamic>>();
      }
      if (responses[5].statusCode == 200) {
        _izinTidakMasuk = (jsonDecode(responses[5].body) as List)
            .cast<Map<String, dynamic>>();
      }
      if (responses[6].statusCode == 200) {
        _tukarShift = (jsonDecode(responses[6].body) as List)
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {
      _error = 'Tidak bisa terhubung ke server atau memuat data';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<http.Response> updateKonfigurasiLokasi({
    required double latitude,
    required double longitude,
    required int radiusMeter,
  }) {
    return http
        .put(
          Uri.parse(ApiEndpoints.konfigurasiLokasi),
          headers: headers,
          body: jsonEncode({
            'latitude': latitude,
            'longitude': longitude,
            'radius_meter': radiusMeter,
          }),
        )
        .timeout(const Duration(seconds: 10));
  }

  // ── Kasir Status Absensi ───────────────────────────────────────────────────
  Future<Map<String, dynamic>?> fetchAbsensiStatus() async {
    final res = await http
        .get(Uri.parse(ApiEndpoints.absensiStatus), headers: headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      _absensiStatus = jsonDecode(res.body) as Map<String, dynamic>;
      notifyListeners();
      return _absensiStatus;
    }
    return null;
  }
}
