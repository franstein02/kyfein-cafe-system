import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class KategoriMenu {
  final String id;
  final String nama;

  KategoriMenu({required this.id, required this.nama});

  factory KategoriMenu.fromJson(Map<String, dynamic> json) => KategoriMenu(
        id: json['id'].toString(),
        nama: json['nama'] ?? '',
      );
}

class MenuItem {
  final String id;
  final String nama;
  final double harga;
  final String? foto;
  final String kategoriId;

  MenuItem({
    required this.id,
    required this.nama,
    required this.harga,
    this.foto,
    required this.kategoriId,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'].toString(),
        nama: json['nama'] ?? '',
        harga: (json['harga'] ?? 0).toDouble(),
        foto: json['foto'],
        kategoriId: json['kategori_id']?.toString() ?? '',
      );
}

class CartItem {
  final MenuItem menuItem;
  int qty;
  String catatan;

  CartItem({required this.menuItem, this.qty = 1, this.catatan = ''});

  double get subtotal => menuItem.harga * qty;
}

class TransaksiRecord {
  final String id;
  final String nomorTransaksi;
  final double total;
  final String metodeBayar;
  final String status;
  final String waktu;

  TransaksiRecord({
    required this.id,
    required this.nomorTransaksi,
    required this.total,
    required this.metodeBayar,
    required this.status,
    required this.waktu,
  });

  factory TransaksiRecord.fromJson(Map<String, dynamic> json) =>
      TransaksiRecord(
        id: json['id'].toString(),
        nomorTransaksi: json['nomor_transaksi'] ?? '',
        total: (json['total_harga'] ?? 0).toDouble(),
        metodeBayar: json['metode_bayar'] ?? '',
        status: json['status'] ?? '',
        waktu: json['waktu_transaksi'] ?? '',
      );
}

class PosProvider with ChangeNotifier {
  AuthProvider? _auth;

  // Catalog
  List<KategoriMenu> _kategori = [];
  List<MenuItem> _menu = [];
  String? _selectedKategoriId;
  bool _isLoadingMenu = false;

  // Cart
  final List<CartItem> _cart = [];

  // Riwayat
  List<TransaksiRecord> _riwayat = [];
  bool _shiftDitutup = false;
  bool _isLoadingRiwayat = false;

  // Submit
  bool _isSubmitting = false;
  String? _lastError;

  // Getters
  bool get isLoadingMenu => _isLoadingMenu;
  bool get isLoadingRiwayat => _isLoadingRiwayat;
  bool get isSubmitting => _isSubmitting;
  String? get lastError => _lastError;
  bool get shiftDitutup => _shiftDitutup;

  List<KategoriMenu> get kategori => _kategori;
  String? get selectedKategoriId => _selectedKategoriId;
  List<MenuItem> get menu => _selectedKategoriId == null
      ? _menu
      : _menu
          .where((m) => m.kategoriId == _selectedKategoriId)
          .toList();
  List<CartItem> get cart => _cart;
  List<TransaksiRecord> get riwayat => _riwayat;

  double get cartTotal =>
      _cart.fold(0, (sum, item) => sum + item.subtotal);
  int get cartItemCount =>
      _cart.fold(0, (sum, item) => sum + item.qty);

  int qtyInCart(String menuId) {
    final idx = _cart.indexWhere((c) => c.menuItem.id == menuId);
    return idx == -1 ? 0 : _cart[idx].qty;
  }

  void updateAuth(AuthProvider auth) {
    final wasAuthenticated = _auth?.isAuthenticated ?? false;
    _auth = auth;
    if (auth.isAuthenticated && !wasAuthenticated) {
      loadAll();
    } else if (!auth.isAuthenticated) {
      _clearAll();
    }
  }

  void _clearAll() {
    _kategori = [];
    _menu = [];
    _cart.clear();
    _riwayat = [];
    notifyListeners();
  }

  Future<void> loadAll() async {
    await Future.wait([_loadKategori(), _loadMenu(), _loadRiwayat()]);
  }

  Future<void> _loadKategori() async {
    if (_auth == null) return;
    try {
      final resp = await http.get(
        Uri.parse(ApiEndpoints.kategoriMenu),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _kategori = list
            .where((e) => e['status_aktif'] == true || e['status_aktif'] == 1)
            .map((e) => KategoriMenu.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _loadMenu() async {
    if (_auth == null) return;
    _isLoadingMenu = true;
    notifyListeners();
    try {
      final resp = await http.get(
        Uri.parse(ApiEndpoints.menu),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _menu = list
            .where((e) => e['status_aktif'] == true || e['status_aktif'] == 1)
            .map((e) => MenuItem.fromJson(e))
            .toList();
      }
    } catch (_) {} finally {
      _isLoadingMenu = false;
      notifyListeners();
    }
  }

  Future<void> _loadRiwayat() async {
    if (_auth == null) return;
    _isLoadingRiwayat = true;
    notifyListeners();
    try {
      final resp = await http.get(
        Uri.parse(ApiEndpoints.transaksi),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = data is List ? data : (data['items'] ?? []) as List;
        _riwayat =
            list.map((e) => TransaksiRecord.fromJson(e)).toList();
        // Check if shift is closed
        _shiftDitutup = data is Map && data['shift_ditutup'] == true;
      }
    } catch (_) {} finally {
      _isLoadingRiwayat = false;
      notifyListeners();
    }
  }

  void selectKategori(String? id) {
    _selectedKategoriId = id;
    notifyListeners();
  }

  void addToCart(MenuItem item) {
    final idx = _cart.indexWhere((c) => c.menuItem.id == item.id);
    if (idx == -1) {
      _cart.add(CartItem(menuItem: item));
    } else {
      _cart[idx].qty++;
    }
    notifyListeners();
  }

  void decreaseQty(String menuId) {
    final idx = _cart.indexWhere((c) => c.menuItem.id == menuId);
    if (idx == -1) return;
    if (_cart[idx].qty <= 1) {
      _cart.removeAt(idx);
    } else {
      _cart[idx].qty--;
    }
    notifyListeners();
  }

  void removeFromCart(String menuId) {
    _cart.removeWhere((c) => c.menuItem.id == menuId);
    notifyListeners();
  }

  void updateCatatan(String menuId, String catatan) {
    final idx = _cart.indexWhere((c) => c.menuItem.id == menuId);
    if (idx != -1) {
      _cart[idx].catatan = catatan;
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> submitTransaksi({
    required String metodeBayar,
    required double uangDiterima,
    String? fotoBuktiQris,
  }) async {
    if (_auth == null || _cart.isEmpty) return null;
    _isSubmitting = true;
    _lastError = null;
    notifyListeners();

    try {
      final details = _cart
          .map((c) => {
                'menu_id': int.tryParse(c.menuItem.id) ?? c.menuItem.id,
                'qty': c.qty,
                'harga_satuan': c.menuItem.harga,
                'catatan': c.catatan,
                'subtotal': c.subtotal,
              })
          .toList();

      final body = {
        'metode_bayar': metodeBayar,
        'total_harga': cartTotal,
        'uang_diterima': uangDiterima,
        'kembalian': (uangDiterima - cartTotal).clamp(0, double.infinity),
        if (fotoBuktiQris != null) 'foto_bukti_qris': fotoBuktiQris,
        'details': details,
      };

      final resp = await http.post(
        Uri.parse(ApiEndpoints.transaksi),
        headers: _auth!.authHeaders,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        clearCart();
        await _loadRiwayat();
        return data;
      } else {
        _lastError = 'Gagal menyimpan transaksi (${resp.statusCode})';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _lastError = 'Tidak bisa terhubung ke server';
      notifyListeners();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> batalkanTransaksi(String id) async {
    if (_auth == null || _shiftDitutup) return false;
    try {
      final resp = await http.patch(
        Uri.parse(ApiEndpoints.voidTransaksi(id)),
        headers: _auth!.authHeaders,
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        await _loadRiwayat();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
