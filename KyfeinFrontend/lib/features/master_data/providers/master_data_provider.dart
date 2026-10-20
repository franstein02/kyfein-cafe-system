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
  final String? kategori;

  MasterBahan({
    required this.id,
    required this.nama,
    required this.satuan,
    this.kategori,
  });

  factory MasterBahan.fromJson(Map<String, dynamic> json) => MasterBahan(
        id: json['id'].toString(),
        nama: json['nama'] ?? '',
        satuan: json['satuan'] ?? '',
        kategori: json['kategori'],
      );
}

class MasterMenu {
  final String id;
  final String nama;
  final String kodeMenu;
  final double harga;
  final String? fotoId;
  final String kategoriId;
  final bool statusAktif;
  final List<MasterMenuResep> resep;

  MasterMenu({
    required this.id,
    required this.nama,
    required this.kodeMenu,
    required this.harga,
    this.fotoId,
    required this.kategoriId,
    required this.statusAktif,
    this.resep = const [],
  });

  factory MasterMenu.fromJson(Map<String, dynamic> json) => MasterMenu(
        id: json['id'].toString(),
        nama: json['nama'] ?? '',
        kodeMenu: json['kode_menu'] ?? '',
        harga: double.tryParse(json['harga']?.toString() ?? '0') ?? 0.0,
        fotoId: json['foto_id'],
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

  MasterKategoriMenu({required this.id, required this.nama});

  factory MasterKategoriMenu.fromJson(Map<String, dynamic> json) => MasterKategoriMenu(
        id: json['id'].toString(),
        nama: json['nama'] ?? '',
      );
}

class MasterDataProvider with ChangeNotifier {
  AuthProvider? _auth;
  bool _isLoading = false;
  String _errorMessage = '';

  List<MasterMenu> _menus = [];
  List<MasterKategoriMenu> _categories = [];
  List<MasterBahan> _bahanList = [];

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<MasterMenu> get menus => _menus;
  List<MasterKategoriMenu> get categories => _categories;
  List<MasterBahan> get bahanList => _bahanList;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
    if (_auth?.isAuthenticated == true) {
      loadData();
    } else {
      _menus = [];
      _categories = [];
      _bahanList = [];
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
      Uri.parse(ApiEndpoints.kategoriMenu),
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
}
