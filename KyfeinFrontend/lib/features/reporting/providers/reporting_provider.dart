import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class ProfitReportModel {
  final String filter;
  final String periodeMulai;
  final String periodeSelesai;
  final int jumlahTransaksi;
  final int jumlahTransaksiDibatalkan;
  final double totalCash;
  final double totalQris;
  final double totalPenjualan;
  final double totalHppTeoritis;
  final double pengeluaranBulananProRata;
  final double pengeluaranMendadak;
  final double netProfit;
  final List<String> menuTanpaResep;
  final int jumlahBarangMasuk;
  final int jumlahBarangKeluar;
  final int jumlahSesiOpname;
  final int jumlahStokMenipis;
  final int totalHadir;
  final int totalTepatWaktu;
  final int totalTerlambat;
  final int totalIzinTelat;
  final int totalIzinTidakMasuk;

  ProfitReportModel({
    required this.filter,
    required this.periodeMulai,
    required this.periodeSelesai,
    required this.jumlahTransaksi,
    required this.jumlahTransaksiDibatalkan,
    required this.totalCash,
    required this.totalQris,
    required this.totalPenjualan,
    required this.totalHppTeoritis,
    required this.pengeluaranBulananProRata,
    required this.pengeluaranMendadak,
    required this.netProfit,
    required this.menuTanpaResep,
    required this.jumlahBarangMasuk,
    required this.jumlahBarangKeluar,
    required this.jumlahSesiOpname,
    required this.jumlahStokMenipis,
    required this.totalHadir,
    required this.totalTepatWaktu,
    required this.totalTerlambat,
    required this.totalIzinTelat,
    required this.totalIzinTidakMasuk,
  });

  factory ProfitReportModel.fromJson(Map<String, dynamic> j) {
    final tgl = j['tanggal']?.toString() ?? '';
    return ProfitReportModel(
      filter: j['filter']?.toString() ?? 'harian',
      periodeMulai: j['periode_mulai']?.toString() ?? tgl,
      periodeSelesai: j['periode_selesai']?.toString() ?? tgl,
      jumlahTransaksi: int.tryParse((j['jumlah_transaksi'] ?? 0).toString()) ?? 0,
      jumlahTransaksiDibatalkan: int.tryParse((j['jumlah_transaksi_dibatalkan'] ?? 0).toString()) ?? 0,
      totalCash: double.tryParse((j['total_cash'] ?? 0).toString()) ?? 0.0,
      totalQris: double.tryParse((j['total_qris'] ?? 0).toString()) ?? 0.0,
      totalPenjualan: double.tryParse((j['total_penjualan'] ?? 0).toString()) ?? 0.0,
      totalHppTeoritis: double.tryParse((j['total_hpp_teoritis'] ?? 0).toString()) ?? 0.0,
      pengeluaranBulananProRata: double.tryParse((j['pengeluaran_bulanan_pro_rata'] ?? 0).toString()) ?? 0.0,
      pengeluaranMendadak: double.tryParse((j['pengeluaran_mendadak'] ?? 0).toString()) ?? 0.0,
      netProfit: double.tryParse((j['net_profit'] ?? j['net_profit_harian'] ?? 0).toString()) ?? 0.0,
      menuTanpaResep: ((j['menu_tanpa_resep'] ?? []) as List).map((e) => e.toString()).toList(),
      jumlahBarangMasuk: int.tryParse((j['jumlah_barang_masuk'] ?? 0).toString()) ?? 0,
      jumlahBarangKeluar: int.tryParse((j['jumlah_barang_keluar'] ?? 0).toString()) ?? 0,
      jumlahSesiOpname: int.tryParse((j['jumlah_sesi_opname'] ?? 0).toString()) ?? 0,
      jumlahStokMenipis: int.tryParse((j['jumlah_stok_menipis'] ?? 0).toString()) ?? 0,
      totalHadir: int.tryParse((j['total_hadir'] ?? 0).toString()) ?? 0,
      totalTepatWaktu: int.tryParse((j['total_tepat_waktu'] ?? 0).toString()) ?? 0,
      totalTerlambat: int.tryParse((j['total_terlambat'] ?? 0).toString()) ?? 0,
      totalIzinTelat: int.tryParse((j['total_izin_telat'] ?? 0).toString()) ?? 0,
      totalIzinTidakMasuk: int.tryParse((j['total_izin_tidak_masuk'] ?? 0).toString()) ?? 0,
    );
  }
}

class ExpenseBreakdownItemModel {
  final String kategoriId;
  final String namaKategori;
  final double totalNominal;
  final double persentase;

  ExpenseBreakdownItemModel({
    required this.kategoriId,
    required this.namaKategori,
    required this.totalNominal,
    required this.persentase,
  });

  factory ExpenseBreakdownItemModel.fromJson(Map<String, dynamic> j) => ExpenseBreakdownItemModel(
        kategoriId: j['kategori_id']?.toString() ?? '',
        namaKategori: j['nama_kategori']?.toString() ?? '-',
        totalNominal: double.tryParse((j['total_nominal'] ?? 0).toString()) ?? 0.0,
        persentase: double.tryParse((j['persentase'] ?? 0).toString()) ?? 0.0,
      );
}

class ExpenseBreakdownReportModel {
  final String filter;
  final String periodeMulai;
  final String periodeSelesai;
  final double totalPengeluaran;
  final List<ExpenseBreakdownItemModel> items;

  ExpenseBreakdownReportModel({
    required this.filter,
    required this.periodeMulai,
    required this.periodeSelesai,
    required this.totalPengeluaran,
    required this.items,
  });

  factory ExpenseBreakdownReportModel.fromJson(Map<String, dynamic> j) => ExpenseBreakdownReportModel(
        filter: j['filter']?.toString() ?? 'harian',
        periodeMulai: j['periode_mulai']?.toString() ?? '',
        periodeSelesai: j['periode_selesai']?.toString() ?? '',
        totalPengeluaran: double.tryParse((j['total_pengeluaran'] ?? 0).toString()) ?? 0.0,
        items: ((j['items'] ?? j['breakdown'] ?? []) as List)
            .map((e) => ExpenseBreakdownItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PengeluaranModel {
  final String id;
  final String tipe;
  final String kategoriId;
  final String namaKategori;
  final double nominal;
  final String? bulan;
  final String? tanggal;
  final String? keterangan;
  final String? dicatatOleh;

  PengeluaranModel({
    required this.id,
    required this.tipe,
    required this.kategoriId,
    required this.namaKategori,
    required this.nominal,
    this.bulan,
    this.tanggal,
    this.keterangan,
    this.dicatatOleh,
  });

  factory PengeluaranModel.fromJson(Map<String, dynamic> j) => PengeluaranModel(
        id: j['id']?.toString() ?? '',
        tipe: j['tipe']?.toString() ?? 'mendadak',
        kategoriId: j['kategori_id']?.toString() ?? '',
        namaKategori: j['nama_kategori']?.toString() ?? '-',
        nominal: double.tryParse((j['nominal'] ?? 0).toString()) ?? 0.0,
        bulan: j['bulan']?.toString(),
        tanggal: j['tanggal']?.toString(),
        keterangan: j['keterangan']?.toString(),
        dicatatOleh: j['dicatat_oleh']?.toString(),
      );
}

class KategoriPengeluaranModel {
  final String id;
  final String nama;
  final bool statusAktif;

  KategoriPengeluaranModel({
    required this.id,
    required this.nama,
    required this.statusAktif,
  });

  factory KategoriPengeluaranModel.fromJson(Map<String, dynamic> j) => KategoriPengeluaranModel(
        id: j['id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? '',
        statusAktif: j['status_aktif'] == true,
      );
}

class StokMenipisItemModel {
  final String id;
  final String nama;
  final String satuanDasar;
  final double batasStokMinimum;
  final double totalStok;

  StokMenipisItemModel({
    required this.id,
    required this.nama,
    required this.satuanDasar,
    required this.batasStokMinimum,
    required this.totalStok,
  });

  factory StokMenipisItemModel.fromJson(Map<String, dynamic> j) => StokMenipisItemModel(
        id: j['id']?.toString() ?? '',
        nama: j['nama']?.toString() ?? j['nama_bahan']?.toString() ?? '-',
        satuanDasar: j['satuan_dasar']?.toString() ?? '',
        batasStokMinimum: double.tryParse((j['batas_stok_minimum'] ?? 0).toString()) ?? 0.0,
        totalStok: double.tryParse((j['total_stok'] ?? j['jumlah_sisa'] ?? 0).toString()) ?? 0.0,
      );
}

class ActionResult {
  final bool success;
  final String message;
  const ActionResult({required this.success, required this.message});
}

class ReportingProvider with ChangeNotifier {
  AuthProvider? _auth;

  bool _isLoading = false;
  ProfitReportModel? _profitReport;
  ExpenseBreakdownReportModel? _breakdownReport;
  List<PengeluaranModel> _pengeluaranList = [];
  List<KategoriPengeluaranModel> _kategoriList = [];
  List<StokMenipisItemModel> _stokMenipisList = [];

  bool get isLoading => _isLoading;
  ProfitReportModel? get profitReport => _profitReport;
  ExpenseBreakdownReportModel? get breakdownReport => _breakdownReport;
  List<PengeluaranModel> get pengeluaranList => _pengeluaranList;
  List<KategoriPengeluaranModel> get kategoriList => _kategoriList;
  List<KategoriPengeluaranModel> get activeKategoriList =>
      _kategoriList.where((k) => k.statusAktif).toList();
  List<StokMenipisItemModel> get stokMenipisList => _stokMenipisList;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
  }

  Map<String, String> get _headers => _auth?.authHeaders ?? {};

  Future<void> loadAll({
    String filter = 'harian',
    String? tanggal,
    String? tanggalMulai,
    String? tanggalSelesai,
    String? bulan,
    int? tahun,
  }) async {
    if (_auth?.token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await Future.wait([
        loadProfitAndBreakdown(
          filter: filter,
          tanggal: tanggal,
          tanggalMulai: tanggalMulai,
          tanggalSelesai: tanggalSelesai,
          bulan: bulan,
          tahun: tahun,
          notify: false,
        ),
        loadPengeluaran(notify: false),
        loadKategori(notify: false),
        loadStokMenipis(notify: false),
      ]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProfitAndBreakdown({
    required String filter,
    String? tanggal,
    String? tanggalMulai,
    String? tanggalSelesai,
    String? bulan,
    int? tahun,
    bool notify = true,
  }) async {
    if (_auth?.token == null) return;
    if (notify) {
      _isLoading = true;
      notifyListeners();
    }

    final queryParams = <String, String>{'filter': filter};
    if (tanggal != null && tanggal.isNotEmpty) queryParams['tanggal'] = tanggal;
    if (tanggalMulai != null && tanggalMulai.isNotEmpty) queryParams['tanggal_mulai'] = tanggalMulai;
    if (tanggalSelesai != null && tanggalSelesai.isNotEmpty) queryParams['tanggal_selesai'] = tanggalSelesai;
    if (bulan != null && bulan.isNotEmpty) queryParams['bulan'] = bulan;
    if (tahun != null) queryParams['tahun'] = tahun.toString();

    try {
      final profitUri = Uri.parse(ApiEndpoints.profitPeriode).replace(queryParameters: queryParams);
      final breakdownUri = Uri.parse(ApiEndpoints.pengeluaranBreakdown).replace(queryParameters: queryParams);

      final responses = await Future.wait([
        http.get(profitUri, headers: _headers).timeout(const Duration(seconds: 10)),
        http.get(breakdownUri, headers: _headers).timeout(const Duration(seconds: 10)),
      ]);

      if (responses[0].statusCode == 200) {
        _profitReport = ProfitReportModel.fromJson(jsonDecode(responses[0].body));
      }
      if (responses[1].statusCode == 200) {
        _breakdownReport = ExpenseBreakdownReportModel.fromJson(jsonDecode(responses[1].body));
      }
    } catch (_) {
    } finally {
      if (notify) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadPengeluaran({
    String? tipe,
    String? kategoriId,
    bool notify = true,
  }) async {
    if (_auth?.token == null) return;
    final queryParams = <String, String>{};
    if (tipe != null && tipe.isNotEmpty) queryParams['tipe'] = tipe;
    if (kategoriId != null && kategoriId.isNotEmpty) queryParams['kategori_id'] = kategoriId;

    try {
      final uri = Uri.parse(ApiEndpoints.pengeluaran).replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _pengeluaranList = list
            .map((e) => PengeluaranModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (notify) notifyListeners();
  }

  Future<ActionResult> createPengeluaran({
    required String tipe,
    required String kategoriId,
    required double nominal,
    String? bulan,
    String? tanggal,
    String? keterangan,
  }) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final body = <String, dynamic>{
        'tipe': tipe,
        'kategori_id': kategoriId,
        'nominal': nominal,
      };
      if (tipe == 'bulanan' && bulan != null && bulan.isNotEmpty) {
        body['bulan'] = bulan;
      }
      if (tipe == 'mendadak' && tanggal != null && tanggal.isNotEmpty) {
        body['tanggal'] = tanggal;
      }
      if (keterangan != null && keterangan.trim().isNotEmpty) {
        body['keterangan'] = keterangan.trim();
      }

      final resp = await http.post(
        Uri.parse(ApiEndpoints.pengeluaran),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await loadPengeluaran();
        return const ActionResult(success: true, message: 'Pengeluaran berhasil dicatat!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal mencatat pengeluaran',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<ActionResult> updatePengeluaran(
    String id, {
    String? tipe,
    String? kategoriId,
    double? nominal,
    String? bulan,
    String? tanggal,
    String? keterangan,
  }) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final body = <String, dynamic>{};
      if (tipe != null) body['tipe'] = tipe;
      if (kategoriId != null) body['kategori_id'] = kategoriId;
      if (nominal != null) body['nominal'] = nominal;
      if (bulan != null) body['bulan'] = bulan;
      if (tanggal != null) body['tanggal'] = tanggal;
      if (keterangan != null) body['keterangan'] = keterangan;

      final resp = await http.put(
        Uri.parse('${ApiEndpoints.pengeluaran}/$id'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        await loadPengeluaran();
        return const ActionResult(success: true, message: 'Pengeluaran berhasil diperbarui!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal memperbarui pengeluaran',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<ActionResult> deletePengeluaran(String id) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final resp = await http.delete(
        Uri.parse('${ApiEndpoints.pengeluaran}/$id'),
        headers: _headers,
      );
      if (resp.statusCode == 200) {
        await loadPengeluaran();
        return const ActionResult(success: true, message: 'Data pengeluaran berhasil dihapus!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal menghapus pengeluaran',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<void> loadKategori({bool includeNonaktif = true, bool notify = true}) async {
    if (_auth?.token == null) return;
    try {
      final uri = Uri.parse(ApiEndpoints.kategoriPengeluaran).replace(
        queryParameters: {'include_nonaktif': includeNonaktif.toString()},
      );
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _kategoriList = list
            .map((e) => KategoriPengeluaranModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (notify) notifyListeners();
  }

  Future<ActionResult> createKategori(String nama) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final resp = await http.post(
        Uri.parse(ApiEndpoints.kategoriPengeluaran),
        headers: _headers,
        body: jsonEncode({'nama': nama.trim(), 'status_aktif': true}),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await loadKategori();
        return const ActionResult(success: true, message: 'Kategori pengeluaran berhasil ditambahkan!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal menambahkan kategori',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<ActionResult> updateKategori(
    String id, {
    String? nama,
    bool? statusAktif,
  }) async {
    if (_auth?.token == null) {
      return const ActionResult(success: false, message: 'Sesi telah berakhir');
    }
    try {
      final body = <String, dynamic>{};
      if (nama != null) body['nama'] = nama.trim();
      if (statusAktif != null) body['status_aktif'] = statusAktif;

      final resp = await http.put(
        Uri.parse('${ApiEndpoints.kategoriPengeluaran}/$id'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (resp.statusCode == 200) {
        await loadKategori();
        return const ActionResult(success: true, message: 'Kategori pengeluaran berhasil diperbarui!');
      }
      final err = jsonDecode(resp.body);
      return ActionResult(
        success: false,
        message: err['detail']?.toString() ?? 'Gagal memperbarui kategori',
      );
    } catch (e) {
      return ActionResult(success: false, message: 'Kesalahan jaringan: $e');
    }
  }

  Future<void> loadStokMenipis({bool notify = true}) async {
    if (_auth?.token == null) return;
    try {
      final resp = await http
          .get(Uri.parse(ApiEndpoints.stokMenipis), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _stokMenipisList = list
            .map((e) => StokMenipisItemModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (notify) notifyListeners();
  }
}
