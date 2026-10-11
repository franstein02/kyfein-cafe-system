import 'package:flutter/material.dart';
import '../../auth/providers/auth_provider.dart';
import 'stok_models.dart';

/// Provider untuk MELIHAT stok Bar/Kitchen (read-only).
/// Stok titik hanya berubah lewat opname, jadi layar ini tidak punya aksi tulis.
///
/// SEKARANG: data mock. NANTI: isi [_fetchStokTitik] dengan panggilan API.
class StokTitikProvider with ChangeNotifier {
  static const bool useMock = true;

  final AuthProvider? _auth;
  StokTitikProvider({AuthProvider? auth}) : _auth = auth;

  TitikStok _titik = TitikStok.bar;
  List<StokTitik> _items = [];
  bool _isLoading = false;
  String _errorMessage = '';

  TitikStok get titik => _titik;
  List<StokTitik> get items => _items;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // ignore: unused_element
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_auth?.token != null) 'Authorization': 'Bearer ${_auth!.token}',
      };

  Future<void> pilihTitik(TitikStok t) async {
    _titik = t;
    await load();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      _items = await _fetchStokTitik(_titik);
    } catch (e) {
      _errorMessage = 'Gagal memuat stok ${_titik.label}. Tarik layar ke bawah untuk coba lagi.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // TITIK SAMBUNG BACKEND. Contoh:
  //   final res = await http.get(
  //     Uri.parse('${ApiEndpoints.stokTitik}?titik=${titik.apiValue}'), headers: _headers);
  //   if (res.statusCode != 200) throw Exception('Gagal memuat stok titik');
  //   return (json.decode(res.body) as List).map((e) => StokTitik.fromJson(e)).toList();
  // ---------------------------------------------------------------------------
  Future<List<StokTitik>> _fetchStokTitik(TitikStok titik) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final tadi = DateTime.now().subtract(const Duration(hours: 3));
    Bahan b(String id, String nama, String satuan) =>
        Bahan(id: id, nama: nama, satuan: satuan, isiPerKemasan: 0, stokMinimum: 0);

    if (titik == TitikStok.bar) {
      return [
        StokTitik(bahan: b('1', 'UHT Full Cream 1L', 'ml'), titik: titik, jumlah: 6600, diperbaruiPada: tadi),
        StokTitik(bahan: b('2', 'Kopi Bubuk Arabika', 'gram'), titik: titik, jumlah: 1200, diperbaruiPada: tadi),
        StokTitik(bahan: b('3', 'Gula Pasir', 'gram'), titik: titik, jumlah: 800, diperbaruiPada: tadi),
        StokTitik(bahan: b('4', 'Sirup Vanilla', 'ml'), titik: titik, jumlah: 350, diperbaruiPada: tadi),
        StokTitik(bahan: b('5', 'Cup Plastik 16oz', 'pcs'), titik: titik, jumlah: 40, diperbaruiPada: tadi),
      ];
    }
    return [
      StokTitik(bahan: b('6', 'Minyak Goreng', 'ml'), titik: titik, jumlah: 2500, diperbaruiPada: tadi),
      StokTitik(bahan: b('7', 'Tepung Terigu', 'gram'), titik: titik, jumlah: 3000, diperbaruiPada: tadi),
      StokTitik(bahan: b('8', 'Telur', 'pcs'), titik: titik, jumlah: 30, diperbaruiPada: tadi),
    ];
  }
}
