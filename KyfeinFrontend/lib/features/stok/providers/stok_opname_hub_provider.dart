import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_endpoints.dart';
import 'stok_opname_hub_models.dart';

class StokOpnameHubProvider with ChangeNotifier {
  final AuthProvider? _auth;

  DateTime _selectedDate = DateTime.now();
  String _selectedTitik = 'Semua'; // 'Semua', 'bar', 'kitchen'
  String _query = '';

  bool _isLoading = false;
  String _errorMessage = '';

  // Tab 1 Data (Stok Harian)
  List<OpnameHarianItem> _harianItems = [];
  List<OpnameHarianSesi> _harianSesi = [];

  // Tab 2 Data (Audit BOM vs Opname) & Perbandingan Shift 1 vs Shift 2
  List<OpnameAuditItem> _auditItems = [];
  OpnameAuditSummary _auditSummary = OpnameAuditSummary();
  List<ShiftComparisonItem> _perbandinganShift = [];

  StokOpnameHubProvider({AuthProvider? auth}) : _auth = auth;

  DateTime get selectedDate => _selectedDate;
  String get selectedTitik => _selectedTitik;
  String get query => _query;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  List<OpnameHarianItem> get harianItems {
    var list = _harianItems;
    if (_selectedTitik != 'Semua') {
      list = list.where((i) => i.titik.toLowerCase() == _selectedTitik.toLowerCase()).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((i) => i.namaBahan.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<OpnameHarianSesi> get harianSesi {
    if (_selectedTitik != 'Semua') {
      return _harianSesi.where((s) => s.titik.toLowerCase() == _selectedTitik.toLowerCase()).toList();
    }
    return _harianSesi;
  }

  List<OpnameAuditItem> get auditItems {
    var list = _auditItems;
    if (_selectedTitik != 'Semua') {
      list = list.where((i) => i.titik.toLowerCase() == _selectedTitik.toLowerCase()).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((i) => i.namaBahan.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  OpnameAuditSummary get auditSummary => _auditSummary;

  List<ShiftComparisonItem> get perbandinganShift {
    var list = _perbandinganShift;
    if (_selectedTitik != 'Semua') {
      list = list
          .where((i) => i.titik.toLowerCase() == _selectedTitik.toLowerCase())
          .toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((i) => i.namaBahan.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_auth?.token != null) 'Authorization': 'Bearer ${_auth!.token}',
      };

  void setTanggal(DateTime date) {
    if (_selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day) {
      return;
    }
    _selectedDate = date;
    loadData();
  }

  void previousDay() {
    setTanggal(_selectedDate.subtract(const Duration(days: 1)));
  }

  void nextDay() {
    setTanggal(_selectedDate.add(const Duration(days: 1)));
  }

  void setTitik(String titik) {
    _selectedTitik = titik;
    notifyListeners();
  }

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      // 1. Fetch Opname Harian
      final harianUri = Uri.parse(ApiEndpoints.opnameHarian).replace(
        queryParameters: {
          'tanggal': dateStr,
        },
      );
      final resHarian = await http.get(harianUri, headers: _headers);

      if (resHarian.statusCode == 200) {
        final data = json.decode(resHarian.body) as Map<String, dynamic>;
        final rawItems = (data['items'] as List<dynamic>?) ?? [];
        final rawSesi = (data['sesi'] as List<dynamic>?) ?? [];
        final rawPerb = (data['perbandingan_shift'] as List<dynamic>?) ?? [];
        _harianItems = rawItems
            .map((e) => OpnameHarianItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _harianSesi = rawSesi
            .map((e) => OpnameHarianSesi.fromJson(e as Map<String, dynamic>))
            .toList();
        _perbandinganShift = rawPerb
            .map((e) => ShiftComparisonItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (resHarian.statusCode == 403) {
        try {
          final decoded = json.decode(resHarian.body);
          _errorMessage = decoded['detail']?.toString() ?? 'Akses rekap stok ditolak';
        } catch (_) {
          _errorMessage = 'Akses rekap stok ditolak';
        }
      }

      // 2. Fetch Opname Audit
      final auditUri = Uri.parse(ApiEndpoints.opnameAudit).replace(
        queryParameters: {
          'tanggal': dateStr,
        },
      );
      final resAudit = await http.get(auditUri, headers: _headers);

      if (resAudit.statusCode == 200) {
        final data = json.decode(resAudit.body) as Map<String, dynamic>;
        final rawItems = (data['items'] as List<dynamic>?) ?? [];
        final rawSummary = (data['summary'] as Map<String, dynamic>?) ?? {};
        final rawPerb = (data['perbandingan_shift'] as List<dynamic>?) ?? [];
        _auditItems = rawItems
            .map((e) => OpnameAuditItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _auditSummary = OpnameAuditSummary.fromJson(rawSummary);
        if (rawPerb.isNotEmpty) {
          _perbandinganShift = rawPerb
              .map((e) => ShiftComparisonItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat data stok opname: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
