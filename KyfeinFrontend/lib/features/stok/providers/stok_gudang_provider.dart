import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';
import 'stok_models.dart';

/// Provider Stok Gudang (terhubung langsung ke API backend).
class StokGudangProvider with ChangeNotifier {
  static const bool useMock = false;

  final AuthProvider? _auth;
  StokGudangProvider({AuthProvider? auth}) : _auth = auth;

  List<StokGudang> _semua = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';
  String _query = '';
  bool _hanyaMenipis = false;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String get errorMessage => _errorMessage;
  bool get hanyaMenipis => _hanyaMenipis;
  int get jumlahMenipis => _semua.where((s) => s.menipis).length;

  /// Daftar bahan untuk dropdown form (diambil dari baris stok_gudang, 1 baris per bahan).
  List<Bahan> get daftarBahan => _semua.map((s) => s.bahan).toList();

  /// Hanya Admin & Owner yang boleh input Barang Masuk (lihat bagian 4 rencana).
  bool get bolehInputBarangMasuk {
    final role = _auth?.role?.toLowerCase();
    return role == 'admin' || role == 'owner';
  }

  // ignore: unused_element
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth?.token != null) 'Authorization': 'Bearer ${_auth!.token}',
  };

  List<StokGudang> get items {
    return _semua.where((s) {
      final cocokNama = s.bahan.nama.toLowerCase().contains(_query.toLowerCase());
      final cocokFilter = !_hanyaMenipis || s.menipis;
      return cocokNama && cocokFilter;
    }).toList();
  }

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _semua = await _fetchStokGudang();
    } catch (e) {
      _errorMessage = 'Gagal memuat stok gudang. Tarik layar ke bawah untuk coba lagi.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void toggleMenipis(bool value) {
    _hanyaMenipis = value;
    notifyListeners();
  }

  /// Submit Barang Masuk. Return true kalau berhasil.
  Future<bool> submitBarangMasuk({
    required List<BarangMasukItem> items,
    String? keterangan,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final ok = await _postBarangMasuk(items, keterangan);
      if (ok) await loadData();
      return ok;
    } catch (e) {
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Cari stok gudang 1 bahan (untuk validasi "tidak boleh melebihi stok" di form).
  StokGudang? stokUntuk(String bahanId) {
    for (final s in _semua) {
      if (s.bahan.id == bahanId) return s;
    }
    return null;
  }

  /// Submit Barang Keluar (gudang -> bar/kitchen). Hanya mengurangi stok gudang.
  /// Stok bar/kitchen TIDAK ditambah di sini, diperbarui lewat opname.
  Future<bool> submitBarangKeluar({
    required TitikStok titik,
    required List<BarangKeluarItem> items,
  }) async {
    _isSubmitting = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final ok = await _postBarangKeluar(titik, items);
      if (ok) await loadData();
      return ok;
    } catch (e) {
      _errorMessage = 'Tidak dapat terhubung ke server: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Update / Edit stok gudang langsung (jumlah kemasan besar, eceran, isi per kemasan, stok minimum).
  Future<bool> updateStokGudang({
    required String bahanId,
    required int jumlahKemasanBesar,
    required double jumlahSatuanKecil,
    double? stokMinimum,
    double? isiPerKemasan,
  }) async {
    _isSubmitting = true;
    _errorMessage = '';
    notifyListeners();

    try {
      if (useMock) {
        await Future.delayed(const Duration(milliseconds: 300));
        final idx = _semua.indexWhere((s) => s.bahan.id == bahanId);
        if (idx >= 0) {
          final cur = _semua[idx];
          final updatedBahan = cur.bahan.copyWith(
            stokMinimum: stokMinimum ?? cur.bahan.stokMinimum,
            isiPerKemasan: isiPerKemasan ?? cur.bahan.isiPerKemasan,
          );
          _semua[idx] = StokGudang(
            bahan: updatedBahan,
            jumlahKemasanBesar: jumlahKemasanBesar,
            jumlahSatuanKecil: jumlahSatuanKecil,
          );
          notifyListeners();
        }
        return true;
      }

      final uri = Uri.parse(ApiEndpoints.updateStokGudang(bahanId));
      final res = await http.put(
        uri,
        headers: _headers,
        body: json.encode({
          'jumlah_kemasan_besar': jumlahKemasanBesar,
          'jumlah_satuan_kecil': jumlahSatuanKecil,
          if (stokMinimum != null) 'stok_minimum': stokMinimum,
          if (isiPerKemasan != null) 'isi_per_kemasan': isiPerKemasan,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(res.body);
        final updated = StokGudang.fromJson(data);
        final idx = _semua.indexWhere((s) => s.bahan.id == bahanId);
        if (idx >= 0) {
          _semua[idx] = updated;
        } else {
          _semua.insert(0, updated);
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Gagal menyimpan perubahan: ${res.statusCode}';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Terjadi kesalahan: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // TITIK SAMBUNG BACKEND (3 fungsi di bawah). Sisanya tidak perlu diubah.
  // Tambahkan dulu endpoint-nya di core/constants/api_endpoints.dart, mis.:
  //   static const stokGudang   = '$baseUrl/stok/gudang';
  //   static const barangMasuk  = '$baseUrl/stok/barang-masuk';
  //   static const barangKeluar = '$baseUrl/stok/barang-keluar';
  //
  // _fetchStokGudang (real):
  //   final res = await http.get(Uri.parse(ApiEndpoints.stokGudang), headers: _headers);
  //   if (res.statusCode != 200) throw Exception('Gagal memuat stok gudang');
  //   return (json.decode(res.body) as List).map((e) => StokGudang.fromJson(e)).toList();
  //
  // _postBarangMasuk (real):
  //   final res = await http.post(Uri.parse(ApiEndpoints.barangMasuk),
  //     headers: _headers,
  //     body: json.encode({
  //       'keterangan': keterangan,
  //       'detail': items.map((e) => e.toJson()).toList(),
  //     }));
  //   return res.statusCode == 200 || res.statusCode == 201;
  //
  // _postBarangKeluar (real): karyawan_id sebaiknya diambil backend dari token.
  //   final res = await http.post(Uri.parse(ApiEndpoints.barangKeluar),
  //     headers: _headers,
  //     body: json.encode({
  //       'titik_tujuan': titik.apiValue,
  //       'detail': items.map((e) => e.toJson()).toList(),
  //     }));
  //   return res.statusCode == 200 || res.statusCode == 201;
  // ===========================================================================

  // --- Mock ---------------------------------------------------------------
  final List<StokGudang> _mockData = const [
    StokGudang(
        bahan: Bahan(id: '1', nama: 'UHT Full Cream 1L', satuan: 'pcs', isiPerKemasan: 12, stokMinimum: 12),
        jumlahKemasanBesar: 2,
        jumlahSatuanKecil: 5),
    StokGudang(
        bahan: Bahan(id: '2', nama: 'Kopi Bubuk Arabika', satuan: 'gram', isiPerKemasan: 1000, stokMinimum: 2000),
        jumlahKemasanBesar: 1,
        jumlahSatuanKecil: 350),
    StokGudang(
        bahan: Bahan(id: '3', nama: 'Gula Pasir', satuan: 'gram', isiPerKemasan: 1000, stokMinimum: 3000),
        jumlahKemasanBesar: 4,
        jumlahSatuanKecil: 0),
    StokGudang(
        bahan: Bahan(id: '4', nama: 'Sirup Vanilla', satuan: 'ml', isiPerKemasan: 750, stokMinimum: 750),
        jumlahKemasanBesar: 0,
        jumlahSatuanKecil: 400),
    StokGudang(
        bahan: Bahan(id: '5', nama: 'Cup Plastik 16oz', satuan: 'pcs', isiPerKemasan: 50, stokMinimum: 100),
        jumlahKemasanBesar: 3,
        jumlahSatuanKecil: 20),
  ];

  Future<List<StokGudang>> _fetchStokGudang() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return List.of(_mockData);
    }
    final res = await http.get(Uri.parse(ApiEndpoints.stokGudang), headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Gagal memuat stok gudang: ${res.statusCode}');
    }
    final List data = json.decode(res.body);
    return data.map((e) => StokGudang.fromJson(e)).toList();
  }

  Future<bool> _postBarangMasuk(List<BarangMasukItem> items, String? keterangan) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 700));
      return true;
    }
    final res = await http.post(
      Uri.parse(ApiEndpoints.barangMasuk),
      headers: _headers,
      body: json.encode({
        'catatan': keterangan,
        'items': items.map((e) => e.toJson()).toList(),
      }),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<bool> _postBarangKeluar(TitikStok titik, List<BarangKeluarItem> items) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 700));
      return true;
    }
    final res = await http.post(
      Uri.parse(ApiEndpoints.barangKeluar),
      headers: _headers,
      body: json.encode({
        'titik_tujuan': titik.apiValue,
        'items': items.map((e) => {
          'bahan_id': e.bahan.id,
          'jumlah': e.jumlah,
        }).toList(),
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      _errorMessage = '';
      return true;
    }
    try {
      final err = json.decode(res.body);
      _errorMessage = err['detail']?.toString() ?? 'Gagal menyimpan barang keluar (${res.statusCode})';
    } catch (_) {
      _errorMessage = 'Gagal menyimpan barang keluar (${res.statusCode})';
    }
    return false;
  }
}