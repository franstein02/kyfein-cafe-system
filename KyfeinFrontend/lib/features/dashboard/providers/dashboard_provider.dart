import 'package:kyfein_frontend/core/network/firebase_http_adapter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class ShiftAktif {
  final String id;
  final String shift;
  final String areaKerja;
  final String jamMulai;
  final String jamSelesai;
  final bool opnameAwalSubmit;
  final bool sudahAbsenMasuk;
  final bool sudahAbsenPulang;
  final String? absensiId;
  final String? jamAbsenMasuk;
  final String? jamAbsenPulang;
  final int menitTelat;

  ShiftAktif({
    required this.id,
    required this.shift,
    required this.areaKerja,
    required this.jamMulai,
    required this.jamSelesai,
    required this.opnameAwalSubmit,
    this.sudahAbsenMasuk = false,
    this.sudahAbsenPulang = false,
    this.absensiId,
    this.jamAbsenMasuk,
    this.jamAbsenPulang,
    this.menitTelat = 0,
  });

  factory ShiftAktif.fromJson(Map<String, dynamic> json) {
    String formatTime(dynamic val, String fallback) {
      if (val == null) return fallback;
      final s = val.toString().trim();
      if (s.isEmpty) return fallback;
      final parts = s.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
      return s;
    }

    final shiftType = (json['shift'] ?? '').toString().toLowerCase();
    final defaultMulai = shiftType == 'shift_2' ? '16:00' : '08:00';
    final defaultSelesai = shiftType == 'shift_2' ? '23:00' : '16:00';

    final absensiMap = json['absensi'] is Map ? json['absensi'] as Map<String, dynamic> : null;
    final bool sudahMasuk = absensiMap != null;
    final bool sudahPulang = absensiMap != null && absensiMap['jam_pulang'] != null;

    return ShiftAktif(
      id: json['id'].toString(),
      shift: json['shift'] ?? '',
      areaKerja: json['area_kerja'] ?? '',
      jamMulai: formatTime(json['jam_mulai'], defaultMulai),
      jamSelesai: formatTime(json['jam_selesai'], defaultSelesai),
      opnameAwalSubmit: json['opname_awal_submit'] == true,
      sudahAbsenMasuk: sudahMasuk,
      sudahAbsenPulang: sudahPulang,
      absensiId: absensiMap?['id']?.toString(),
      jamAbsenMasuk: absensiMap?['jam_masuk']?.toString(),
      jamAbsenPulang: absensiMap?['jam_pulang']?.toString(),
      menitTelat: absensiMap?['menit_telat'] is int ? absensiMap!['menit_telat'] : 0,
    );
  }
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
        totalPendapatan: double.tryParse(
                (json['total_pendapatan'] ?? json['total_penjualan'] ?? 0)
                    .toString()) ??
            0.0,
        jumlahTransaksi: int.tryParse(
                (json['jumlah_transaksi'] ?? json['total_transaksi'] ?? 0)
                    .toString()) ??
            0,
        totalCash:
            double.tryParse((json['total_cash'] ?? 0).toString()) ?? 0.0,
        totalQris:
            double.tryParse((json['total_qris'] ?? 0).toString()) ?? 0.0,
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
        namaBahan: (json['nama_bahan'] ?? json['nama'] ?? '').toString(),
        jumlahSisa: double.tryParse(
                (json['jumlah_sisa'] ?? json['total_stok'] ?? 0).toString()) ??
            0.0,
        stokMinimum:
            double.tryParse((json['stok_minimum'] ?? 0).toString()) ?? 0.0,
        satuan: (json['satuan'] ?? '').toString(),
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

class SalesChartPoint {
  final String label;
  final String tanggal;
  final double totalPenjualan;
  final double totalHpp;
  final double totalPengeluaran;
  final double netProfit;
  final int jumlahTransaksi;

  SalesChartPoint({
    required this.label,
    required this.tanggal,
    required this.totalPenjualan,
    required this.totalHpp,
    required this.totalPengeluaran,
    required this.netProfit,
    required this.jumlahTransaksi,
  });

  factory SalesChartPoint.fromJson(Map<String, dynamic> json) =>
      SalesChartPoint(
        label: (json['label'] ?? '').toString(),
        tanggal: (json['tanggal'] ?? '').toString(),
        totalPenjualan:
            double.tryParse((json['total_penjualan'] ?? 0).toString()) ?? 0.0,
        totalHpp: double.tryParse((json['total_hpp'] ?? 0).toString()) ?? 0.0,
        totalPengeluaran:
            double.tryParse((json['total_pengeluaran'] ?? 0).toString()) ?? 0.0,
        netProfit:
            double.tryParse((json['net_profit'] ?? 0).toString()) ?? 0.0,
        jumlahTransaksi:
            int.tryParse((json['jumlah_transaksi'] ?? 0).toString()) ?? 0,
      );
}

class EmployeeBehaviorItem {
  final String karyawanId;
  final String nama;
  final String divisi;
  final int totalShiftTerjadwal;
  final int totalHadir;
  final int tepatWaktuCount;
  final int telatCount;
  final int totalMenitTelat;
  final double rataMenitTelat;
  final int izinTelatCount;
  final int izinTidakMasukCount;
  final int lupaAbsenPulangCount;
  final int tanpaKeteranganCount;
  final int tukarShiftCount;
  final double tingkatKetepatanPersen;
  final String kategoriPerilaku;
  final String ringkasanPerilaku;

  EmployeeBehaviorItem({
    required this.karyawanId,
    required this.nama,
    required this.divisi,
    required this.totalShiftTerjadwal,
    required this.totalHadir,
    required this.tepatWaktuCount,
    required this.telatCount,
    required this.totalMenitTelat,
    required this.rataMenitTelat,
    required this.izinTelatCount,
    required this.izinTidakMasukCount,
    required this.lupaAbsenPulangCount,
    required this.tanpaKeteranganCount,
    required this.tukarShiftCount,
    required this.tingkatKetepatanPersen,
    required this.kategoriPerilaku,
    required this.ringkasanPerilaku,
  });

  factory EmployeeBehaviorItem.fromJson(Map<String, dynamic> json) =>
      EmployeeBehaviorItem(
        karyawanId: (json['karyawan_id'] ?? '').toString(),
        nama: (json['nama'] ?? 'Karyawan').toString(),
        divisi: (json['divisi'] ?? 'kasir').toString(),
        totalShiftTerjadwal:
            int.tryParse((json['total_shift_terjadwal'] ?? 0).toString()) ?? 0,
        totalHadir: int.tryParse((json['total_hadir'] ?? 0).toString()) ?? 0,
        tepatWaktuCount:
            int.tryParse((json['tepat_waktu_count'] ?? 0).toString()) ?? 0,
        telatCount: int.tryParse((json['telat_count'] ?? 0).toString()) ?? 0,
        totalMenitTelat:
            int.tryParse((json['total_menit_telat'] ?? 0).toString()) ?? 0,
        rataMenitTelat:
            double.tryParse((json['rata_menit_telat'] ?? 0).toString()) ?? 0.0,
        izinTelatCount:
            int.tryParse((json['izin_telat_count'] ?? 0).toString()) ?? 0,
        izinTidakMasukCount:
            int.tryParse((json['izin_tidak_masuk_count'] ?? 0).toString()) ?? 0,
        lupaAbsenPulangCount:
            int.tryParse((json['lupa_absen_pulang_count'] ?? 0).toString()) ??
                0,
        tanpaKeteranganCount:
            int.tryParse((json['tanpa_keterangan_count'] ?? 0).toString()) ?? 0,
        tukarShiftCount:
            int.tryParse((json['tukar_shift_count'] ?? 0).toString()) ?? 0,
        tingkatKetepatanPersen:
            double.tryParse((json['tingkat_ketepatan_persen'] ?? 100).toString()) ??
                100.0,
        kategoriPerilaku:
            (json['kategori_perilaku'] ?? 'belum_ada_data').toString(),
        ringkasanPerilaku: (json['ringkasan_perilaku'] ?? '').toString(),
      );
}

class DashboardOverviewData {
  final String filter;
  final String periodeMulai;
  final String periodeSelesai;
  final String chartGranularity;
  final String chartPeriodeMulai;
  final String chartPeriodeSelesai;
  final String periodePerilakuMulai;
  final String periodePerilakuSelesai;
  final double totalPenjualan;
  final double totalHppTeoritis;
  final double pengeluaranBulananProRata;
  final double pengeluaranMendadak;
  final double totalPengeluaran;
  final double netProfit;
  final double marginProfitPersen;
  final int jumlahTransaksi;
  final int jumlahTransaksiDibatalkan;
  final double rataRataTransaksi;
  final double totalCash;
  final double totalQris;
  final double? perubahanPenjualanPersen;
  final List<SalesChartPoint> grafikPenjualan;
  final int ringkasanDisiplinTotalHadir;
  final int ringkasanDisiplinTepatWaktu;
  final int ringkasanDisiplinTelat;
  final int ringkasanDisiplinAlpha;
  final double tingkatKetepatanTimPersen;
  final List<EmployeeBehaviorItem> perilakuKaryawan;

  DashboardOverviewData({
    required this.filter,
    required this.periodeMulai,
    required this.periodeSelesai,
    required this.chartGranularity,
    required this.chartPeriodeMulai,
    required this.chartPeriodeSelesai,
    required this.periodePerilakuMulai,
    required this.periodePerilakuSelesai,
    required this.totalPenjualan,
    required this.totalHppTeoritis,
    required this.pengeluaranBulananProRata,
    required this.pengeluaranMendadak,
    required this.totalPengeluaran,
    required this.netProfit,
    required this.marginProfitPersen,
    required this.jumlahTransaksi,
    required this.jumlahTransaksiDibatalkan,
    required this.rataRataTransaksi,
    required this.totalCash,
    required this.totalQris,
    this.perubahanPenjualanPersen,
    required this.grafikPenjualan,
    required this.ringkasanDisiplinTotalHadir,
    required this.ringkasanDisiplinTepatWaktu,
    required this.ringkasanDisiplinTelat,
    required this.ringkasanDisiplinAlpha,
    required this.tingkatKetepatanTimPersen,
    required this.perilakuKaryawan,
  });

  factory DashboardOverviewData.fromJson(Map<String, dynamic> json) {
    final chartRaw = (json['grafik_penjualan'] as List?) ?? const [];
    final behRaw = (json['perilaku_karyawan'] as List?) ?? const [];
    return DashboardOverviewData(
      filter: (json['filter'] ?? 'hari_ini').toString(),
      periodeMulai: (json['periode_mulai'] ?? '').toString(),
      periodeSelesai: (json['periode_selesai'] ?? '').toString(),
      chartGranularity: (json['chart_granularity'] ?? 'hari').toString(),
      chartPeriodeMulai: (json['chart_periode_mulai'] ?? '').toString(),
      chartPeriodeSelesai: (json['chart_periode_selesai'] ?? '').toString(),
      periodePerilakuMulai: (json['periode_perilaku_mulai'] ?? '').toString(),
      periodePerilakuSelesai: (json['periode_perilaku_selesai'] ?? '').toString(),
      totalPenjualan:
          double.tryParse((json['total_penjualan'] ?? 0).toString()) ?? 0.0,
      totalHppTeoritis:
          double.tryParse((json['total_hpp_teoritis'] ?? 0).toString()) ?? 0.0,
      pengeluaranBulananProRata: double.tryParse(
              (json['pengeluaran_bulanan_pro_rata'] ?? 0).toString()) ??
          0.0,
      pengeluaranMendadak:
          double.tryParse((json['pengeluaran_mendadak'] ?? 0).toString()) ??
              0.0,
      totalPengeluaran:
          double.tryParse((json['total_pengeluaran'] ?? 0).toString()) ?? 0.0,
      netProfit: double.tryParse((json['net_profit'] ?? 0).toString()) ?? 0.0,
      marginProfitPersen:
          double.tryParse((json['margin_profit_persen'] ?? 0).toString()) ??
              0.0,
      jumlahTransaksi:
          int.tryParse((json['jumlah_transaksi'] ?? 0).toString()) ?? 0,
      jumlahTransaksiDibatalkan:
          int.tryParse((json['jumlah_transaksi_dibatalkan'] ?? 0).toString()) ??
              0,
      rataRataTransaksi:
          double.tryParse((json['rata_rata_transaksi'] ?? 0).toString()) ?? 0.0,
      totalCash: double.tryParse((json['total_cash'] ?? 0).toString()) ?? 0.0,
      totalQris: double.tryParse((json['total_qris'] ?? 0).toString()) ?? 0.0,
      perubahanPenjualanPersen: json['perubahan_penjualan_persen'] != null
          ? double.tryParse(json['perubahan_penjualan_persen'].toString())
          : null,
      grafikPenjualan: chartRaw
          .map((e) => SalesChartPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      ringkasanDisiplinTotalHadir: int.tryParse(
              (json['ringkasan_disiplin_total_hadir'] ?? 0).toString()) ??
          0,
      ringkasanDisiplinTepatWaktu: int.tryParse(
              (json['ringkasan_disiplin_tepat_waktu'] ?? 0).toString()) ??
          0,
      ringkasanDisiplinTelat:
          int.tryParse((json['ringkasan_disiplin_telat'] ?? 0).toString()) ?? 0,
      ringkasanDisiplinAlpha:
          int.tryParse((json['ringkasan_disiplin_alpha'] ?? 0).toString()) ?? 0,
      tingkatKetepatanTimPersen: double.tryParse(
              (json['tingkat_ketepatan_tim_persen'] ?? 100).toString()) ??
          100.0,
      perilakuKaryawan: behRaw
          .map((e) => EmployeeBehaviorItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DashboardProvider with ChangeNotifier {
  AuthProvider? _auth;

  // State
  bool _isLoading = false;
  bool _isOverviewLoading = false;
  String? _error;

  ShiftAktif? _shiftAktif;
  LaporanShift? _laporanShift;
  List<StokMenipis> _stokMenipis = [];
  List<PendingApproval> _pendingApprovals = [];
  AdminSummary? _adminSummary;
  DashboardOverviewData? _overview;
  String _selectedPreset = 'hari_ini';
  DateTime? _customStart;
  DateTime? _customEnd;
  String _chartMode = 'auto';

  Timer? _autoRefreshTimer;

  // Getters
  bool get isLoading => _isLoading;
  bool get isOverviewLoading => _isOverviewLoading;
  String? get error => _error;
  ShiftAktif? get shiftAktif => _shiftAktif;
  LaporanShift? get laporanShift => _laporanShift;
  List<StokMenipis> get stokMenipis => _stokMenipis;
  List<PendingApproval> get pendingApprovals => _pendingApprovals;
  AdminSummary? get adminSummary => _adminSummary;
  DashboardOverviewData? get overview => _overview;
  String get selectedPreset => _selectedPreset;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;
  String get chartMode => _chartMode;

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
    _overview = null;
    _selectedPreset = 'hari_ini';
    _customStart = null;
    _customEnd = null;
    _chartMode = 'auto';
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
          _loadAdminOverview(),
          _loadStokMenipis(),
          _loadPendingApprovals(),
        ]);
        if (_adminSummary != null) {
          _adminSummary = AdminSummary(
            totalPenjualan: _adminSummary!.totalPenjualan,
            profitHarian: _adminSummary!.profitHarian,
            jumlahTransaksi: _adminSummary!.jumlahTransaksi,
            pendingApprovals: _pendingApprovals.length,
          );
        }
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
    final resp = await FirebaseHttpAdapter.get(
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
      final resp = await FirebaseHttpAdapter.get(
        Uri.parse(ApiEndpoints.laporanShiftAktif),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        _laporanShift = LaporanShift.fromJson(jsonDecode(resp.body));
      }
    } catch (_) {}
  }

  Uri _buildOverviewUri() {
    final params = <String, String>{
      'preset': _selectedPreset,
      'chart_mode': _chartMode,
    };
    if (_selectedPreset == 'custom' &&
        _customStart != null &&
        _customEnd != null) {
      final fmt = DateFormat('yyyy-MM-dd');
      params['tanggal_mulai'] = fmt.format(_customStart!);
      params['tanggal_selesai'] = fmt.format(_customEnd!);
    }
    return Uri.parse(ApiEndpoints.dashboardOverview)
        .replace(queryParameters: params);
  }

  Future<void> _loadAdminOverview() async {
    if (_auth == null || !_auth!.isAuthenticated || _auth!.token == null) {
      return;
    }
    try {
      final resp = await http
          .get(
            _buildOverviewUri(),
            headers: _auth!.authHeaders,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = DashboardOverviewData.fromJson(d);
        _overview = data;
        _adminSummary = AdminSummary(
          totalPenjualan: data.totalPenjualan,
          profitHarian: data.netProfit,
          jumlahTransaksi: data.jumlahTransaksi,
          pendingApprovals: _pendingApprovals.length,
        );
        return;
      }
    } catch (_) {}
    await _loadAdminSummary();
  }

  Future<void> applyOverviewPreset(String preset) async {
    _selectedPreset = preset;
    if (preset != 'hari_ini' && _chartMode == 'jam') {
      _chartMode = 'auto';
    }
    await _reloadOverviewOnly();
  }

  Future<void> applyCustomRange(DateTime start, DateTime end) async {
    _selectedPreset = 'custom';
    _customStart = start;
    _customEnd = end;
    if (end.difference(start).inDays > 0 && _chartMode == 'jam') {
      _chartMode = 'auto';
    }
    await _reloadOverviewOnly();
  }

  Future<void> setChartMode(String mode) async {
    if (_chartMode == mode) return;
    _chartMode = mode;
    await _reloadOverviewOnly();
  }

  Future<void> _reloadOverviewOnly() async {
    if (_auth == null || !_auth!.isAuthenticated || _auth!.token == null) {
      notifyListeners();
      return;
    }
    _isOverviewLoading = true;
    notifyListeners();
    try {
      await _loadAdminOverview();
    } finally {
      _isOverviewLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAdminSummary() async {
    try {
      final resp = await FirebaseHttpAdapter.get(
        Uri.parse(ApiEndpoints.profitHarian),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body);
        _adminSummary = AdminSummary(
          totalPenjualan: double.tryParse((d['total_penjualan'] ?? 0).toString()) ?? 0.0,
          profitHarian: double.tryParse((d['profit_harian'] ?? d['net_profit_harian'] ?? 0).toString()) ?? 0.0,
          jumlahTransaksi: int.tryParse((d['jumlah_transaksi'] ?? 0).toString()) ?? 0,
          pendingApprovals: d['pending_approvals'] ?? _pendingApprovals.length,
        );
      }
    } catch (_) {}
  }

  Future<void> _loadStokMenipis() async {
    try {
      final resp = await FirebaseHttpAdapter.get(
        Uri.parse(ApiEndpoints.stokMenipis),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _stokMenipis = list.map((e) => StokMenipis.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  // Gabungan endpoint pending: tukar shift, izin telat, izin tidak masuk, & request off
  Future<void> _loadPendingApprovals() async {
    try {
      final h = _auth!.authHeaders;
      const t = Duration(seconds: 8);
      final res = await Future.wait([
        FirebaseHttpAdapter.get(Uri.parse('${ApiEndpoints.karyawan}/'), headers: h).timeout(t),
        http
            .get(Uri.parse('${ApiEndpoints.tukarShift}?status=pending'),
                headers: h)
            .timeout(t),
        http
            .get(Uri.parse('${ApiEndpoints.izinTelat}?status=pending'),
                headers: h)
            .timeout(t),
        http
            .get(Uri.parse('${ApiEndpoints.izinTidakMasuk}?status=pending'),
                headers: h)
            .timeout(t),
        FirebaseHttpAdapter.get(Uri.parse(ApiEndpoints.requestOff), headers: h).timeout(t),
      ]);

      // Peta id karyawan -> nama
      final nama = <String, String>{};
      if (res[0].statusCode == 200) {
        for (final k in jsonDecode(res[0].body) as List) {
          nama[k['id'].toString()] = (k['nama'] ?? '').toString();
        }
      }

      final items = <PendingApproval>[];
      void tambah(http.Response r, String type, String karyawanKey) {
        if (r.statusCode != 200) return;
        for (final e in jsonDecode(r.body) as List) {
          items.add(PendingApproval(
            id: e['id'].toString(),
            type: type,
            namaKaryawan: nama[e[karyawanKey].toString()] ?? 'Karyawan',
            keterangan: (e['alasan'] ?? '').toString(),
            tanggal: (e['diajukan_at'] ?? e['tanggal'] ?? '')
                .toString()
                .split('T')
                .first,
          ));
        }
      }

      tambah(res[1], 'swap_shift', 'karyawan_pengaju_id');
      tambah(res[2], 'izin_telat', 'karyawan_id');
      tambah(res[3], 'izin_tidak_masuk', 'karyawan_id');

      if (res[4].statusCode == 200) {
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        for (final e in jsonDecode(res[4].body) as List) {
          final tgl = (e['tanggal'] ?? '').toString();
          if (tgl.compareTo(todayStr) >= 0) {
            items.add(PendingApproval(
              id: e['id'].toString(),
              type: 'request_off',
              namaKaryawan: nama[e['karyawan_id'].toString()] ?? 'Karyawan',
              keterangan: (e['alasan'] ?? '').toString(),
              tanggal: tgl,
            ));
          }
        }
      }

      _pendingApprovals = items;
    } catch (_) {}
  }

  String _approvalUrl(String id, String type) {
    switch (type) {
      case 'swap_shift':
        return ApiEndpoints.approvalTukarShift(id);
      case 'izin_telat':
        return ApiEndpoints.approvalIzinTelat(id);
      default:
        return ApiEndpoints.approvalIzinTidakMasuk(id);
    }
  }

  Future<bool> _prosesApproval(String id, String type, String status) async {
    try {
      if (type == 'request_off') {
        if (status == 'ditolak') {
          final resp = await http
              .delete(
                Uri.parse('${ApiEndpoints.requestOff}/$id'),
                headers: _auth!.authHeaders,
              )
              .timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200) {
            _pendingApprovals.removeWhere((p) => p.id == id);
            notifyListeners();
            return true;
          }
        } else {
          // Dismiss from dashboard card (remain active request off)
          _pendingApprovals.removeWhere((p) => p.id == id);
          notifyListeners();
          return true;
        }
        return false;
      }

      final resp = await http
          .put(
            Uri.parse(_approvalUrl(id, type)),
            headers: _auth!.authHeaders,
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        _pendingApprovals.removeWhere((p) => p.id == id);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> approveItem(String id, String type) =>
      _prosesApproval(id, type, 'disetujui');

  Future<bool> rejectItem(String id, String type) =>
      _prosesApproval(id, type, 'ditolak');

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
}