import 'package:flutter/material.dart';
import '../../auth/providers/auth_provider.dart';
import 'stok_models.dart';

/// Provider Stok Opname (hitung fisik di Bar/Kitchen, awal & akhir shift).
///
/// SEKARANG: data mock (useMock = true).
/// NANTI: isi 2 fungsi di "TITIK SAMBUNG BACKEND". Metode (carry_forward / hitung_manual)
/// seharusnya datang dari backend, karena backend yang tahu shift sebelumnya.
class StokOpnameProvider with ChangeNotifier {
  static const bool useMock = true;

  final AuthProvider? _auth;
  StokOpnameProvider({AuthProvider? auth}) : _auth = auth;

  OpnameKonteks? _konteks;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  /// Pengali terakhir yang dipakai per bahan (mis. UHT: 1000 ml per kotak),
  /// supaya tidak diketik ulang tiap opname. Hanya di memori selama aplikasi berjalan.
  final Map<String, double> _pengaliTerakhir = {};

  OpnameKonteks? get konteks => _konteks;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String get errorMessage => _errorMessage;

  double? pengaliTerakhir(String bahanId) => _pengaliTerakhir[bahanId];
  void simpanPengali(String bahanId, double nilai) {
    if (nilai > 0) _pengaliTerakhir[bahanId] = nilai;
  }

  // ignore: unused_element
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_auth?.token != null) 'Authorization': 'Bearer ${_auth!.token}',
      };

  /// [metodeMock] hanya dipakai saat useMock = true, untuk menguji kedua alur.
  Future<void> loadKonteks({
    required TitikStok titik,
    required TipeOpname tipe,
    MetodeOpname metodeMock = MetodeOpname.hitungManual,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _konteks = await _fetchKonteks(titik, tipe, metodeMock);
    } catch (e) {
      _errorMessage = 'Gagal memuat data opname. Coba lagi.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitOpname({
    required List<OpnameItem> items,
    String? catatan,
  }) async {
    final k = _konteks;
    if (k == null) return false;
    _isSubmitting = true;
    notifyListeners();
    try {
      return await _postOpname(k, items, catatan);
    } catch (e) {
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // TITIK SAMBUNG BACKEND. Tambahkan dulu di core/constants/api_endpoints.dart, mis.:
  //   static const opnameKonteks = '$baseUrl/stok/opname/konteks';
  //   static const opname        = '$baseUrl/stok/opname';
  //
  // _fetchKonteks (real): backend mengembalikan metode + daftar bahan titik tsb
  // (+ ekspektasi kalau carry_forward), berdasarkan shift aktif karyawan.
  //
  // _postOpname (real): jadwal_shift_id sebaiknya ditentukan backend dari shift aktif + token
  // (validasi kepemilikan shift ada di audit endpoint).
  //   final res = await http.post(Uri.parse(ApiEndpoints.opname),
  //     headers: _headers,
  //     body: json.encode({
  //       'titik': k.titik.apiValue,
  //       'tipe': k.tipe.apiValue,
  //       'metode': k.metode.apiValue,
  //       'catatan': catatan,
  //       'detail': items.map((e) => e.toJson()).toList(),
  //     }));
  //   return res.statusCode == 200 || res.statusCode == 201;
  // ===========================================================================

  // --- Mock ---------------------------------------------------------------
  Future<OpnameKonteks> _fetchKonteks(
      TitikStok titik, TipeOpname tipe, MetodeOpname metode) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final carry = metode == MetodeOpname.carryForward;
    const uht = Bahan(
        id: '1', nama: 'UHT Full Cream 1L', satuan: 'ml', isiPerKemasan: 0, stokMinimum: 0);
    const kopi = Bahan(
        id: '2', nama: 'Kopi Bubuk Arabika', satuan: 'gram', isiPerKemasan: 0, stokMinimum: 0);
    const gula =
        Bahan(id: '3', nama: 'Gula Pasir', satuan: 'gram', isiPerKemasan: 0, stokMinimum: 0);
    const sirup = Bahan(
        id: '4', nama: 'Sirup Vanilla', satuan: 'ml', isiPerKemasan: 0, stokMinimum: 0);
    const cup = Bahan(
        id: '5', nama: 'Cup Plastik 16oz', satuan: 'pcs', isiPerKemasan: 0, stokMinimum: 0);

    return OpnameKonteks(
      titik: titik,
      tipe: tipe,
      metode: metode,
      daftar: [
        OpnameBahan(bahan: uht, ekspektasi: carry ? 4500 : null),
        OpnameBahan(bahan: kopi, ekspektasi: carry ? 800 : null),
        OpnameBahan(bahan: gula, ekspektasi: carry ? 1200 : null),
        OpnameBahan(bahan: sirup, ekspektasi: carry ? 350 : null),
        OpnameBahan(bahan: cup, ekspektasi: carry ? 40 : null),
      ],
    );
  }

  Future<bool> _postOpname(
      OpnameKonteks k, List<OpnameItem> items, String? catatan) async {
    // Ganti dengan panggilan API (lihat komentar di atas) saat useMock = false.
    await Future.delayed(const Duration(milliseconds: 700));
    return true;
  }
}
