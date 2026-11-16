import 'package:kyfein_frontend/core/network/firebase_http_adapter.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';
import 'stok_models.dart';

/// Provider Stok Opname (hitung fisik di Bar/Kitchen, awal & akhir shift).
/// Terhubung ke backend API (/master/bahan, /stok/stok-titik, /jadwal/shift-aktif, /stok/opname).
class StokOpnameProvider with ChangeNotifier {
  final AuthProvider? _auth;
  StokOpnameProvider({AuthProvider? auth}) : _auth = auth;

  OpnameKonteks? _konteks;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';

  final Map<String, double> _pengaliTerakhir = {};

  OpnameKonteks? get konteks => _konteks;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String get errorMessage => _errorMessage;

  double? pengaliTerakhir(String bahanId) => _pengaliTerakhir[bahanId];
  void simpanPengali(String bahanId, double nilai) {
    if (nilai > 0) _pengaliTerakhir[bahanId] = nilai;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_auth?.token != null) 'Authorization': 'Bearer ${_auth!.token}',
      };

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

  Future<OpnameKonteks> _fetchKonteks(
      TitikStok titik, TipeOpname tipe, MetodeOpname metode) async {
    final carry = metode == MetodeOpname.carryForward;
    List<Bahan> bahanList = [];
    Map<String, double> stokTitikMap = {};

    try {
      final resBahan = await http
          .get(Uri.parse(ApiEndpoints.bahan), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resBahan.statusCode == 200) {
        final List data = json.decode(resBahan.body);
        bahanList = data
            .map((e) => Bahan.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (carry) {
        final resTitik = await http
            .get(
              Uri.parse('${ApiEndpoints.stokTitik}?titik=${titik.apiValue}'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 10));
        if (resTitik.statusCode == 200) {
          final List tData = json.decode(resTitik.body);
          for (final r in tData) {
            final bId = (r['bahan_id'] ?? '').toString();
            final jml = double.tryParse((r['jumlah'] ?? '0').toString()) ?? 0.0;
            stokTitikMap[bId] = jml;
          }
        }
      }
    } catch (_) {}

    if (bahanList.isEmpty) {
      bahanList = const [
        Bahan(id: '1', nama: 'UHT Full Cream 1L', satuan: 'ml', isiPerKemasan: 1000, stokMinimum: 0),
        Bahan(id: '2', nama: 'Kopi Bubuk Arabika', satuan: 'gram', isiPerKemasan: 1000, stokMinimum: 0),
        Bahan(id: '3', nama: 'Gula Pasir', satuan: 'gram', isiPerKemasan: 1000, stokMinimum: 0),
      ];
    }

    return OpnameKonteks(
      titik: titik,
      tipe: tipe,
      metode: metode,
      daftar: bahanList
          .map(
            (b) => OpnameBahan(
              bahan: b,
              ekspektasi: carry ? (stokTitikMap[b.id] ?? 0.0) : null,
            ),
          )
          .toList(),
    );
  }

  Future<bool> _postOpname(
      OpnameKonteks k, List<OpnameItem> items, String? catatan) async {
    String shiftId = 'shift-${k.titik.apiValue}-k1';
    try {
      final shiftRes = await FirebaseHttpAdapter.get(
        Uri.parse('${ApiEndpoints.shiftAktif}?titik=${k.titik.apiValue}'),
        headers: _headers,
      );
      if (shiftRes.statusCode == 200) {
        final shiftData = json.decode(shiftRes.body);
        if (shiftData is Map && shiftData['id'] != null) {
          shiftId = shiftData['id'].toString();
        }
      }
    } catch (_) {}

    final res = await FirebaseHttpAdapter.post(
      Uri.parse(ApiEndpoints.opname),
      headers: _headers,
      body: json.encode({
        'jadwal_shift_id': shiftId,
        'titik': k.titik.apiValue,
        'tipe': k.tipe.apiValue,
        'metode': k.metode.apiValue,
        'catatan': catatan,
        'items': items.map((e) => e.toJson()).toList(),
      }),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }
}
