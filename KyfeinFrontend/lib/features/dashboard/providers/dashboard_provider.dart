import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class ShiftAktif {
  final String id;
  final String shift;
  final String areaKerja;
  final String jamMulai;
  final String jamSelesai;
  final bool opnameAwalSubmit;

  ShiftAktif({
    required this.id,
    required this.shift,
    required this.areaKerja,
    required this.jamMulai,
    required this.jamSelesai,
    required this.opnameAwalSubmit,
  });

  factory ShiftAktif.fromJson(Map<String, dynamic> json) => ShiftAktif(
        id: json['id'].toString(),
        shift: json['shift'] ?? '',
        areaKerja: json['area_kerja'] ?? '',
        jamMulai: json['jam_mulai'] ?? '',
        jamSelesai: json['jam_selesai'] ?? '',
        opnameAwalSubmit: json['opname_awal_submit'] == true,
      );
}

class LaporanShift {
  final double totalPendapatan;
  final int jumlahTransaksi;
  final double totalCash;
  final double totalQris;

  LaporanShift({
    required this.totalPendapatan,
    required this.jumlahTransaksi,
    required this.totalCash,
    required this.totalQris,
  });

  factory LaporanShift.fromJson(Map<String, dynamic> json) => LaporanShift(
        totalPendapatan: (json['total_pendapatan'] ?? 0).toDouble(),
        jumlahTransaksi: json['jumlah_transaksi'] ?? 0,
        totalCash: (json['total_cash'] ?? 0).toDouble(),
        totalQris: (json['total_qris'] ?? 0).toDouble(),
      );
}

class StokMenipis {
  final String namaBahan;
  final double jumlahSisa;
  final double stokMinimum;
  final String satuan;

  StokMenipis({
    required this.namaBahan,
    required this.jumlahSisa,
    required this.stokMinimum,
    required this.satuan,
  });

  factory StokMenipis.fromJson(Map<String, dynamic> json) => StokMenipis(
        namaBahan: json['nama_bahan'] ?? '',
        jumlahSisa: (json['jumlah_sisa'] ?? 0).toDouble(),
        stokMinimum: (json['stok_minimum'] ?? 0).toDouble(),
        satuan: json['satuan'] ?? '',
      );
}

class PendingApproval {
  final String id;
  final String type; // swap_shift | izin_telat | izin_tidak_masuk
  final String namaKaryawan;
  final String keterangan;
  final String tanggal;

  PendingApproval({
    required this.id,
    required this.type,
    required this.namaKaryawan,
    required this.keterangan,
    required this.tanggal,
  });

  factory PendingApproval.fromJson(Map<String, dynamic> json) =>
      PendingApproval(
        id: json['id'].toString(),
        type: json['type'] ?? 'swap_shift',
        namaKaryawan: json['nama_karyawan'] ?? '',
        keterangan: json['keterangan'] ?? '',
        tanggal: json['tanggal'] ?? '',
      );
}

class AdminSummary {
  final double totalPenjualan;
  final double profitHarian;
  final int jumlahTransaksi;
  final int pendingApprovals;

  AdminSummary({
    required this.totalPenjualan,
    required this.profitHarian,
    required this.jumlahTransaksi,
    required this.pendingApprovals,
  });
}

class DashboardProvider with ChangeNotifier {
  AuthProvider? _auth;

  // State
  bool _isLoading = false;
  String? _error;

  ShiftAktif? _shiftAktif;
  LaporanShift? _laporanShift;
  List<StokMenipis> _stokMenipis = [];
  List<PendingApproval> _pendingApprovals = [];
  AdminSummary? _adminSummary;

  Timer? _autoRefreshTimer;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  ShiftAktif? get shiftAktif => _shiftAktif;
  LaporanShift? get laporanShift => _laporanShift;
  List<StokMenipis> get stokMenipis => _stokMenipis;
  List<PendingApproval> get pendingApprovals => _pendingApprovals;
  AdminSummary? get adminSummary => _adminSummary;

  void updateAuth(AuthProvider auth) {
    final wasAuthenticated = _auth?.isAuthenticated ?? false;
    _auth = auth;
    if (auth.isAuthenticated && !wasAuthenticated) {
      loadDashboard();
    } else if (!auth.isAuthenticated) {
      _clearData();
    }
  }

  void _clearData() {
    _shiftAktif = null;
    _laporanShift = null;
    _stokMenipis = [];
    _pendingApprovals = [];
    _adminSummary = null;
    _autoRefreshTimer?.cancel();
    notifyListeners();
  }

  Future<void> loadDashboard() async {
    if (_auth == null || !_auth!.isAuthenticated) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final role = _auth!.role;
      if (role == 'karyawan') {
        await Future.wait([_loadShiftAktif(), _loadLaporanShift()]);
        _startAutoRefresh();
      } else if (role == 'admin') {
        await Future.wait([
          _loadAdminSummary(),
          _loadStokMenipis(),
          _loadPendingApprovals(),
        ]);
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadLaporanShift().then((_) => notifyListeners());
    });
  }

  Future<void> refresh() => loadDashboard();

  Future<void> _loadShiftAktif() async {
    final resp = await http.get(
      Uri.parse(ApiEndpoints.shiftAktif),
      headers: _auth!.authHeaders,
    ).timeout(const Duration(seconds: 8));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      _shiftAktif = data != null ? ShiftAktif.fromJson(data) : null;
    } else if (resp.statusCode == 404) {
      _shiftAktif = null;
    }
  }

  Future<void> _loadLaporanShift() async {
    try {
      final resp = await http.get(
        Uri.parse(ApiEndpoints.laporanShiftAktif),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        _laporanShift = LaporanShift.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
  }

  Future<void> _loadAdminSummary() async {
    try {
      final resp = await http.get(
        Uri.parse(ApiEndpoints.profitHarian),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body);
        _adminSummary = AdminSummary(
          totalPenjualan: (d['total_penjualan'] ?? 0).toDouble(),
          profitHarian: (d['profit_harian'] ?? 0).toDouble(),
          jumlahTransaksi: d['jumlah_transaksi'] ?? 0,
          pendingApprovals: d['pending_approvals'] ?? 0,
        );
      }
    } catch (_) {}
  }

  Future<void> _loadStokMenipis() async {
    try {
      final resp = await http.get(
        Uri.parse(ApiEndpoints.stokMenipis),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _stokMenipis = list.map((e) => StokMenipis.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _loadPendingApprovals() async {
    try {
      final resp = await http.get(
        Uri.parse(ApiEndpoints.pendingApprovals),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _pendingApprovals =
            list.map((e) => PendingApproval.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> approveItem(String id, String type) async {
    try {
      final url = type == 'swap_shift'
          ? ApiEndpoints.approveSwapShift(id)
          : ApiEndpoints.approveIzin(id);
      final resp = await http.post(Uri.parse(url), headers: _auth!.authHeaders);
      if (resp.statusCode == 200) {
        _pendingApprovals.removeWhere((p) => p.id == id);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> rejectItem(String id, String type) async {
    try {
      final url = type == 'swap_shift'
          ? ApiEndpoints.rejectSwapShift(id)
          : ApiEndpoints.rejectIzin(id);
      final resp =
          await http.post(Uri.parse(url), headers: _auth!.authHeaders);
      if (resp.statusCode == 200) {
        _pendingApprovals.removeWhere((p) => p.id == id);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}
