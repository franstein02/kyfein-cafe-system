import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';
import 'stok_models.dart';

double _parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.')) ?? 0;

/// 1 bagian hitungan: jumlah x (pengali opsional).
class OpnamePart {
  final TextEditingController jumlahC = TextEditingController();
  final TextEditingController pengaliC = TextEditingController();

  bool get isEmpty => jumlahC.text.trim().isEmpty;
  double get pengali => pengaliC.text.trim().isEmpty ? 1 : _parseNum(pengaliC.text);
  double get subtotal => _parseNum(jumlahC.text) * pengali;
  bool get hasMultiplier => pengaliC.text.trim().isNotEmpty && _parseNum(pengaliC.text) > 1;

  void dispose() {
    jumlahC.dispose();
    pengaliC.dispose();
  }
}

/// State per bahan untuk opname
class OpnameBahanFormState {
  final Bahan bahan;
  final List<OpnamePart> parts;

  OpnameBahanFormState(this.bahan, {double? defaultPengali})
      : parts = [
          OpnamePart()..pengaliC.text = (defaultPengali != null && defaultPengali > 1) ? formatAngka(defaultPengali) : '',
        ];

  bool get isFilled => parts.any((p) => !p.isEmpty);
  double get total => parts.fold(0.0, (sum, p) => sum + p.subtotal);

  String? get formula {
    final filled = parts.where((p) => !p.isEmpty).toList();
    if (filled.length < 2 && !filled.any((p) => p.hasMultiplier)) return null;
    return filled
        .map((p) => p.hasMultiplier
            ? '${formatAngka(_parseNum(p.jumlahC.text))} × ${formatAngka(p.pengali)}'
            : formatAngka(_parseNum(p.jumlahC.text)))
        .join(' + ');
  }

  void addPart({double? pengali}) {
    final p = OpnamePart();
    if (pengali != null && pengali > 1) {
      p.pengaliC.text = formatAngka(pengali);
    }
    parts.add(p);
  }

  void removePart(int index) {
    if (parts.length > 1 && index < parts.length) {
      parts[index].dispose();
      parts.removeAt(index);
    }
  }

  void reset() {
    for (final p in parts) {
      p.dispose();
    }
    parts.clear();
    parts.add(OpnamePart());
  }

  void dispose() {
    for (final p in parts) {
      p.dispose();
    }
  }
}

class CatatOpnameProvider with ChangeNotifier {
  final AuthProvider? _auth;

  TitikStok _titik = TitikStok.bar;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _errorMessage = '';
  String _searchQuery = '';

  // Master bahan
  List<Bahan> _allBahan = [];

  // Form states per titik & tipe: Map<key: "bar_awal", Map<bahanId, OpnameBahanFormState>>
  final Map<String, Map<String, OpnameBahanFormState>> _formStates = {};
  final Map<String, String> _catatanMap = {};

  // Track status saved per titik & tipe: Map<key: "bar_awal", bool>
  final Map<String, bool> _savedStatus = {};
  final Map<String, DateTime> _savedTime = {};
  final Map<String, Map<String, double>> _savedResults = {};
  final Map<String, bool> _isEditing = {};

  CatatOpnameProvider({AuthProvider? auth}) : _auth = auth;

  TitikStok get titik => _titik;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  List<Bahan> get allBahan => _allBahan;

  bool isAwalSaved(TitikStok t) => _savedStatus['${t.apiValue}_awal'] ?? false;
  bool isAkhirSaved(TitikStok t) => _savedStatus['${t.apiValue}_akhir'] ?? false;
  bool isEditing(TitikStok t, TipeOpname tipe) =>
      _isEditing['${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}'] ?? false;

  DateTime? savedTime(TitikStok t, TipeOpname tipe) =>
      _savedTime['${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}'];
  Map<String, double>? savedResults(TitikStok t, TipeOpname tipe) =>
      _savedResults['${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}'];

  Bahan? getBahanById(String id) {
    try {
      return _allBahan.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_auth?.token != null) 'Authorization': 'Bearer ${_auth!.token}',
      };

  void setTitik(TitikStok t) {
    if (_titik == t) return;
    _titik = t;
    _searchQuery = '';
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  List<Bahan> get filteredBahan {
    var list = <Bahan>[];
    // Categorize by area: Bar vs Kitchen
    if (_titik == TitikStok.bar) {
      // Seluruh bahan saat ini adalah bahan bar (kopi, susu, sirup, cup, creamer, dll.)
      list = List<Bahan>.from(_allBahan);
    } else {
      // Saat ini belum ada bahan untuk kitchen, hanya bar
      list = [];
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((b) => b.nama.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  OpnameBahanFormState getFormState(TitikStok t, TipeOpname tipe, Bahan bahan) {
    final key = '${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}';
    _formStates.putIfAbsent(key, () => {});
    final map = _formStates[key]!;
    if (!map.containsKey(bahan.id)) {
      map[bahan.id] = OpnameBahanFormState(bahan, defaultPengali: bahan.isiPerKemasan);
    }
    return map[bahan.id]!;
  }

  String getCatatan(TitikStok t, TipeOpname tipe) {
    final key = '${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}';
    return _catatanMap[key] ?? '';
  }

  void setCatatan(TitikStok t, TipeOpname tipe, String catatan) {
    final key = '${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}';
    _catatanMap[key] = catatan;
  }

  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // 1. Fetch Master Bahan
      final resBahan = await http.get(Uri.parse(ApiEndpoints.bahan), headers: _headers);
      if (resBahan.statusCode == 200) {
        final List<dynamic> data = json.decode(resBahan.body);
        _allBahan = data.map((e) => Bahan.fromJson(e as Map<String, dynamic>)).toList();
      }

      // If bahan list is still empty from server, supply standard fallback cafe ingredients
      if (_allBahan.isEmpty) {
        _allBahan = _defaultBahanList();
      }

      // 2. Fetch Opname Harian to verify if awal_shift or akhir_shift already recorded today
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final harianUri = Uri.parse(ApiEndpoints.opnameHarian).replace(queryParameters: {'tanggal': dateStr});
      final resHarian = await http.get(harianUri, headers: _headers);

      if (resHarian.statusCode == 200) {
        final data = json.decode(resHarian.body) as Map<String, dynamic>;
        final rawSesi = (data['sesi'] as List<dynamic>?) ?? [];
        final rawItems = (data['items'] as List<dynamic>?) ?? [];

        for (final s in rawSesi) {
          final t = (s['titik'] ?? '').toString().toLowerCase();
          final tipe = (s['tipe'] ?? '').toString().toLowerCase();
          final waktuStr = s['waktu_opname']?.toString();
          final waktu = waktuStr != null ? DateTime.tryParse(waktuStr) ?? DateTime.now() : DateTime.now();

          if (tipe == 'awal_shift') {
            _savedStatus['${t}_awal'] = true;
            _savedTime['${t}_awal'] = waktu;
          } else if (tipe == 'akhir_shift') {
            _savedStatus['${t}_akhir'] = true;
            _savedTime['${t}_akhir'] = waktu;
          }
        }

        // Populate saved results summary from rawItems & pre-fill form controllers
        for (final item in rawItems) {
          final t = (item['titik'] ?? '').toString().toLowerCase();
          final bId = (item['bahan_id'] ?? '').toString();
          final awal = double.tryParse(item['stok_awal']?.toString() ?? '');
          final akhir = double.tryParse(item['stok_akhir']?.toString() ?? '');

          final titikEnum = t == 'kitchen' ? TitikStok.kitchen : TitikStok.bar;
          final bahanObj = _allBahan.firstWhere(
            (b) => b.id == bId,
            orElse: () => Bahan(
              id: bId,
              nama: (item['nama_bahan'] ?? bId).toString(),
              satuan: (item['satuan'] ?? '').toString(),
              isiPerKemasan: 1,
              stokMinimum: 0,
            ),
          );

          if (awal != null) {
            _savedResults.putIfAbsent('${t}_awal', () => {})[bId] = awal;
            _savedStatus['${t}_awal'] = true;

            final stateAwal = getFormState(titikEnum, TipeOpname.awalShift, bahanObj);
            if (stateAwal.parts.isNotEmpty) {
              stateAwal.parts[0].jumlahC.text = formatAngka(awal);
              stateAwal.parts[0].pengaliC.text = '';
            }
          }
          if (akhir != null) {
            _savedResults.putIfAbsent('${t}_akhir', () => {})[bId] = akhir;
            _savedStatus['${t}_akhir'] = true;

            final stateAkhir = getFormState(titikEnum, TipeOpname.akhirShift, bahanObj);
            if (stateAkhir.parts.isNotEmpty) {
              stateAkhir.parts[0].jumlahC.text = formatAngka(akhir);
              stateAkhir.parts[0].pengaliC.text = '';
            }
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat bahan: $e';
      if (_allBahan.isEmpty) {
        _allBahan = _defaultBahanList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> simpanOpname({
    required TitikStok titik,
    required TipeOpname tipe,
    required String? catatan,
  }) async {
    _isSubmitting = true;
    _errorMessage = '';
    notifyListeners();

    final key = '${titik.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}';
    final formMap = _formStates[key] ?? {};

    // Collect all counted items
    final List<Map<String, dynamic>> itemsPayload = [];
    final Map<String, double> countResult = {};

    for (final entry in formMap.entries) {
      final state = entry.value;
      if (state.isFilled && state.total >= 0) {
        itemsPayload.add({
          'bahan_id': state.bahan.id,
          'jumlah': state.total,
        });
        countResult[state.bahan.id] = state.total;
      }
    }

    try {
      // 1. Try sending to backend POST /api/v1/stok/opname
      // First try to resolve active shift or fallback
      String shiftId = 'shift-${titik.apiValue}-k1';
      try {
        final shiftRes = await http.get(
          Uri.parse('${ApiEndpoints.shiftAktif}?titik=${titik.apiValue}'),
          headers: _headers,
        );
        if (shiftRes.statusCode == 200) {
          final shiftData = json.decode(shiftRes.body);
          if (shiftData is Map && shiftData['id'] != null) {
            shiftId = shiftData['id'].toString();
          }
        }
      } catch (_) {}

      final postBody = json.encode({
        'jadwal_shift_id': shiftId,
        'titik': titik.apiValue,
        'tipe': tipe == TipeOpname.awalShift ? 'awal_shift' : 'akhir_shift',
        'metode': 'hitung_manual',
        'catatan': catatan?.trim().isEmpty == true ? null : catatan?.trim(),
        'items': itemsPayload,
      });

      final res = await http.post(
        Uri.parse(ApiEndpoints.opname),
        headers: _headers,
        body: postBody,
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        _savedStatus[key] = true;
        _isEditing[key] = false;
        _savedTime[key] = DateTime.now();
        _savedResults[key] = countResult;
        _isSubmitting = false;
        notifyListeners();
        return true;
      } else {
        String msg = 'Gagal menyimpan opname (${res.statusCode})';
        try {
          final err = json.decode(res.body);
          if (err is Map && err['detail'] != null) {
            msg = err['detail'].toString();
          }
        } catch (_) {}
        _errorMessage = msg;
        _isSubmitting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Tidak dapat terhubung ke server: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Masuk ke mode edit: mempertahankan seluruh data yang sudah pernah diisi
  /// ke form controllers sehingga pengguna bisa langsung mengoreksi tanpa mengetik ulang.
  void mulaiEdit(TitikStok t, TipeOpname tipe) {
    final key = '${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}';
    _isEditing[key] = true;

    // Pastikan semua controller terisi nilai dari _savedResults
    final savedMap = _savedResults[key];
    if (savedMap != null) {
      for (final entry in savedMap.entries) {
        final bId = entry.key;
        final val = entry.value;
        final bahan = _allBahan.firstWhere(
          (b) => b.id == bId,
          orElse: () => Bahan(id: bId, nama: bId, satuan: '', isiPerKemasan: 1, stokMinimum: 0),
        );
        final state = getFormState(t, tipe, bahan);
        if (state.parts.isEmpty) {
          state.parts.add(OpnamePart());
        }
        state.parts[0].jumlahC.text = formatAngka(val);
        state.parts[0].pengaliC.text = '';
        while (state.parts.length > 1) {
          state.parts.removeLast().dispose();
        }
      }
    }
    notifyListeners();
  }

  /// Membatalkan mode edit dan kembali ke tampilan rincian stok tersimpan
  void batalEdit(TitikStok t, TipeOpname tipe) {
    final key = '${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}';
    _isEditing[key] = false;
    notifyListeners();
  }

  void resetForm(TitikStok t, TipeOpname tipe) {
    final key = '${t.apiValue}_${tipe == TipeOpname.awalShift ? "awal" : "akhir"}';
    _savedStatus[key] = false;
    _isEditing[key] = false;
    _savedResults.remove(key);
    final formMap = _formStates[key];
    if (formMap != null) {
      for (final s in formMap.values) {
        s.reset();
      }
    }
    notifyListeners();
  }

  List<Bahan> _defaultBahanList() {
    return const [
      Bahan(id: 'b-kopi', nama: 'Biji Kopi House Blend', satuan: 'gram', isiPerKemasan: 1000, stokMinimum: 500),
      Bahan(id: 'b-uht', nama: 'Susu UHT Diamond', satuan: 'ml', isiPerKemasan: 1000, stokMinimum: 3000),
      Bahan(id: 'b-aren', nama: 'Sirup Gula Aren Organik', satuan: 'ml', isiPerKemasan: 1000, stokMinimum: 1000),
      Bahan(id: 'b-matcha', nama: 'Bubuk Matcha Kyoto', satuan: 'gram', isiPerKemasan: 500, stokMinimum: 200),
      Bahan(id: 'b-gula', nama: 'Gula Cair Fruktosa', satuan: 'ml', isiPerKemasan: 1000, stokMinimum: 1000),
      Bahan(id: 'b-cup16', nama: 'Cup Plastik 16oz + Tutup', satuan: 'pcs', isiPerKemasan: 50, stokMinimum: 50),
      Bahan(id: 'b-sedotan', nama: 'Sedotan Kertas Steril', satuan: 'pcs', isiPerKemasan: 100, stokMinimum: 50),
      Bahan(id: 'b-beras', nama: 'Beras Premium', satuan: 'gram', isiPerKemasan: 5000, stokMinimum: 2000),
      Bahan(id: 'b-telur', nama: 'Telur Ayam Negeri', satuan: 'pcs', isiPerKemasan: 30, stokMinimum: 20),
      Bahan(id: 'b-minyak', nama: 'Minyak Goreng Sawit', satuan: 'ml', isiPerKemasan: 2000, stokMinimum: 1000),
      Bahan(id: 'b-bumbu-nasgor', nama: 'Bumbu Racik Nasi Goreng', satuan: 'gram', isiPerKemasan: 500, stokMinimum: 200),
      Bahan(id: 'b-basmati', nama: 'Beras Basmati Import', satuan: 'gram', isiPerKemasan: 5000, stokMinimum: 1000),
      Bahan(id: 'b-kambing', nama: 'Daging Kambing Potong', satuan: 'gram', isiPerKemasan: 1000, stokMinimum: 1000),
      Bahan(id: 'b-samin', nama: 'Minyak Samin', satuan: 'ml', isiPerKemasan: 1000, stokMinimum: 500),
      Bahan(id: 'b-bumbu-kebuli', nama: 'Bumbu Rempah Kebuli', satuan: 'gram', isiPerKemasan: 500, stokMinimum: 200),
    ];
  }

  @override
  void dispose() {
    for (final map in _formStates.values) {
      for (final s in map.values) {
        s.dispose();
      }
    }
    super.dispose();
  }
}
