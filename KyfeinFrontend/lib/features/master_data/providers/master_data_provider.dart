import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class MasterMenuResep {
  final String? id;
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final double jumlahTerpakai;

  MasterMenuResep({
    this.id,
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.jumlahTerpakai,
  });

  factory MasterMenuResep.fromJson(Map<String, dynamic> json) => MasterMenuResep(
        id: json['id']?.toString(),
        bahanId: (json['bahan_id'] ?? '').toString(),
        namaBahan: json['nama_bahan'] ?? '',
        satuan: json['satuan'] ?? '',
        jumlahTerpakai: double.tryParse(json['jumlah_terpakai']?.toString() ?? '0') ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'bahan_id': bahanId,
        'jumlah_terpakai': jumlahTerpakai,
      };
}

class MasterBahan {
  final String id;
  final String nama;
  final String satuan;
  final String area;
  final double isiPerKemasan;
  final double stokMinimum;
  final double hargaRataRata;

  MasterBahan({
    required this.id,
    required this.nama,
    required this.satuan,
    this.area = 'semua',
    this.isiPerKemasan = 1.0,
    this.stokMinimum = 0.0,
    this.hargaRataRata = 0.0,
  });

  bool get punyaKemasan => isiPerKemasan > 0;

  String get areaLabel {
    switch (area) {
      case 'bar':
        return 'Bar (Minuman)';
      case 'kitchen':
        return 'Kitchen (Dapur)';
      default:
        return 'Bar & Kitchen';
    }
  }

  double get batasMinimumSatuanKecil => stokMinimum <= 0
      ? 0.0
      : (punyaKemasan ? stokMinimum * isiPerKemasan : stokMinimum);

  factory MasterBahan.fromJson(Map<String, dynamic> json) => MasterBahan(
        id: json['id'].toString(),
        nama: json['nama'] ?? '',
        satuan: json['satuan'] ?? '',
        area: (json['area'] ?? 'semua').toString().toLowerCase(),
        isiPerKemasan: double.tryParse(json['isi_per_kemasan']?.toString() ?? '1') ?? 1.0,
        stokMinimum: double.tryParse(json['stok_minimum']?.toString() ?? '0') ?? 0.0,
        hargaRataRata: double.tryParse(json['harga_rata_rata']?.toString() ?? '0') ?? 0.0,
      );
}

class MasterMenu {
  final String id;
  final String nama;
  final String kodeMenu;
  final double harga;
  final String? fotoId;
  final String? fotoUrl;
  final String kategoriId;
  final bool statusAktif;
  final List<MasterMenuResep> resep;

  MasterMenu({
    required this.id,
    required this.nama,
    required this.kodeMenu,
    required this.harga,
    this.fotoId,
    this.fotoUrl,
    required this.kategoriId,
    required this.statusAktif,
    this.resep = const [],
  });

  String? get resolvedFotoUrl {
    if (fotoUrl != null && fotoUrl!.isNotEmpty) return fotoUrl;
    if (fotoId == null || fotoId!.isEmpty) return null;
    return fotoId!.startsWith('http') ? fotoId! : '${ApiConfig.baseUrl}/foto/$fotoId';
  }

  factory MasterMenu.fromJson(Map<String, dynamic> json) => MasterMenu(
        id: json['id'].toString(),
        nama: json['nama'] ?? '',
        kodeMenu: json['kode_menu'] ?? '',
        harga: double.tryParse(json['harga']?.toString() ?? '0') ?? 0.0,
        fotoId: json['foto_id'],
        fotoUrl: json['foto_url'],
        kategoriId: json['kategori_id']?.toString() ?? '',
        statusAktif: json['status_aktif'] ?? true,
        resep: (json['resep'] as List?)
                ?.map((e) => MasterMenuResep.fromJson(e))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'kode_menu': kodeMenu,
        'harga': harga,
        'kategori_id': kategoriId,
        'status_aktif': statusAktif,
        if (fotoId != null) 'foto_id': fotoId,
        'resep': resep.map((e) => e.toJson()).toList(),
      };
}

class MasterKategoriMenu {
  final String id;
  final String nama;
  final String areaProduksi; // bar | kitchen
  final bool statusAktif;

  MasterKategoriMenu({
    required this.id,
    required this.nama,
    this.areaProduksi = 'bar',
    this.statusAktif = true,
  });

  factory MasterKategoriMenu.fromJson(Map<String, dynamic> json) => MasterKategoriMenu(
        id: json['id'].toString(),
        nama: json['nama'] ?? '',
        areaProduksi: (json['area_produksi'] ?? 'bar').toString(),
        statusAktif: json['status_aktif'] ?? true,
      );
}

class MasterKaryawan {
  final String id;
  final String nama;
  final String email;
  final String? nomorHp;
  final String role;
  final String? divisi;
  final bool statusAktif;

  MasterKaryawan({
    required this.id,
    required this.nama,
    required this.email,
    this.nomorHp,
    required this.role,
    this.divisi,
    required this.statusAktif,
  });

  String get effectiveDivisi {
    if (divisi == 'bar' || divisi == 'kitchen' || divisi == 'kasir') {
      return divisi!;
    }
    return 'kasir';
  }

  String get divisiLabel {
    switch (effectiveDivisi) {
      case 'kitchen':
        return 'Kitchen';
      case 'bar':
        return 'Bar / Barista';
      default:
        return 'Kasir';
    }
  }

  factory MasterKaryawan.fromJson(Map<String, dynamic> json) => MasterKaryawan(
        id: json['id'].toString(),
        nama: (json['nama'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        nomorHp: json['nomor_hp']?.toString(),
        role: (json['role'] ?? 'karyawan').toString(),
        divisi: json['divisi']?.toString(),
        statusAktif: json['status_aktif'] ?? true,
      );
}

class MasterDataProvider with ChangeNotifier {
  AuthProvider? _auth;
  bool _isLoading = false;
  String _errorMessage = '';

  List<MasterMenu> _menus = [];
  List<MasterKategoriMenu> _categories = [];
  List<MasterBahan> _bahanList = [];
  List<MasterKaryawan> _karyawanList = [];

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<MasterMenu> get menus => _menus;
  List<MasterKategoriMenu> get categories => _categories;
  List<MasterBahan> get bahanList => _bahanList;
  List<MasterKaryawan> get karyawanList => _karyawanList;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
    if (_auth?.isAuthenticated == true) {
      loadData();
    } else {
      _menus = [];
      _categories = [];
      _bahanList = [];
      _karyawanList = [];
      notifyListeners();
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_auth?.token != null) 'Authorization': 'Bearer ${_auth!.token}',
      };

  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await Future.wait([
        _fetchCategories(),
        _fetchBahanList(),
        _fetchMenus(),
        _fetchKaryawanList(),
      ]);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCategories() async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.kategoriMenu}?include_nonaktif=true'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      _categories = data.map((e) => MasterKategoriMenu.fromJson(e)).toList();
    } else {
      throw Exception('Gagal memuat kategori');
    }
  }

  Future<void> _fetchBahanList() async {
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.bahan),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        _bahanList = data.map((e) => MasterBahan.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Gagal memuat bahan: $e');
    }
  }

  Future<void> _fetchMenus() async {
    final response = await http.get(
      Uri.parse('${ApiEndpoints.menu}?include_nonaktif=true'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      _menus = data.map((e) => MasterMenu.fromJson(e)).toList();
    } else {
      throw Exception('Gagal memuat menu');
    }
  }

  Future<void> _fetchKaryawanList() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.karyawan}/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        _karyawanList = data.map((e) => MasterKaryawan.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Gagal memuat karyawan: $e');
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final String filePath = 'menu/$fileName';

      await Supabase.instance.client.storage.from('Storage').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return Supabase.instance.client.storage.from('Storage').getPublicUrl(filePath);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // --- MENU CRUD ---
  Future<bool> createMenu(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.menu),
        headers: _headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchMenus();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMenu(String id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.menu}/$id'),
        headers: _headers,
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        await _fetchMenus();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleMenuStatus(String id, bool currentStatus) async {
    return updateMenu(id, {'status_aktif': !currentStatus});
  }

  Future<bool> deleteMenu(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.menu}/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        await _fetchMenus();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- KATEGORI MENU CRUD ---
  Future<bool> createKategoriMenu(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.kategoriMenu),
        headers: _headers,
        body: json.encode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchCategories();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateKategoriMenu(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.kategoriMenu}/$id'),
        headers: _headers,
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        await _fetchCategories();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // --- BAHAN BAKU CRUD ---
  Future<bool> createBahan(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.bahan),
        headers: _headers,
        body: json.encode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchBahanList();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateBahan(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiEndpoints.bahan}/$id'),
        headers: _headers,
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        await _fetchBahanList();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final err = json.decode(response.body);
      if (err is Map<String, dynamic> && err['detail'] != null) {
        final detail = err['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }
          return first.toString();
        }
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  // --- KARYAWAN CRUD PER DIVISI (KASIR / BAR / KITCHEN) ---
  Future<String?> createKaryawan(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiEndpoints.karyawan}/'),
        headers: _headers,
        body: json.encode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchKaryawanList();
        notifyListeners();
        return null;
      }
      return _extractErrorMessage(response, 'Gagal menambah karyawan');
    } catch (e) {
      return 'Gagal menghubungi server: $e';
    }
  }

  Future<String?> updateKaryawan(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse(ApiEndpoints.karyawanById(id)),
        headers: _headers,
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        await _fetchKaryawanList();
        notifyListeners();
        return null;
      }
      return _extractErrorMessage(response, 'Gagal mengubah data karyawan');
    } catch (e) {
      return 'Gagal menghubungi server: $e';
    }
  }
}
