import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../auth/providers/auth_provider.dart';

class TransaksiItemModel {
  final String id;
  final String menuId;
  final String namaMenu;
  final int qty;
  final double hargaSatuan;
  final double hppSatuan;
  final String? catatan;
  final double subtotal;
  final String statusItem;

  TransaksiItemModel({
    required this.id,
    required this.menuId,
    required this.namaMenu,
    required this.qty,
    required this.hargaSatuan,
    this.hppSatuan = 0,
    this.catatan,
    required this.subtotal,
    required this.statusItem,
  });

  factory TransaksiItemModel.fromJson(Map<String, dynamic> json) {
    return TransaksiItemModel(
      id: json['id']?.toString() ?? '',
      menuId: json['menu_id']?.toString() ?? '',
      namaMenu: (json['nama_menu'] != null && json['nama_menu'].toString().isNotEmpty)
          ? json['nama_menu'].toString()
          : (json['menu'] != null ? json['menu']['nama']?.toString() ?? 'Menu Item' : 'Menu Item'),
      qty: int.tryParse(json['qty']?.toString() ?? '1') ?? 1,
      hargaSatuan: double.tryParse(json['harga_satuan']?.toString() ?? '0') ?? 0.0,
      hppSatuan: double.tryParse(json['hpp_satuan']?.toString() ?? '0') ?? 0.0,
      catatan: json['catatan']?.toString(),
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      statusItem: json['status_item']?.toString() ?? 'menunggu',
    );
  }
}

class TransaksiModel {
  final String id;
  final String jadwalShiftId;
  final String kasirId;
  final String namaKasir;
  final String nomorTransaksi;
  final String metodeBayar;
  final double totalHarga;
  final double? uangDiterima;
  final double? kembalian;
  final String? fotoBuktiQrisId;
  final String status;
  final DateTime waktuTransaksi;
  final List<TransaksiItemModel> details;

  TransaksiModel({
    required this.id,
    required this.jadwalShiftId,
    required this.kasirId,
    required this.namaKasir,
    required this.nomorTransaksi,
    required this.metodeBayar,
    required this.totalHarga,
    this.uangDiterima,
    this.kembalian,
    this.fotoBuktiQrisId,
    required this.status,
    required this.waktuTransaksi,
    required this.details,
  });

  factory TransaksiModel.fromJson(Map<String, dynamic> json) {
    DateTime waktu;
    try {
      waktu = DateTime.parse(json['waktu_transaksi'] ?? json['created_at']);
    } catch (_) {
      waktu = DateTime.now();
    }

    final rawDetails = json['details'] as List? ?? [];
    final items = rawDetails.map((d) => TransaksiItemModel.fromJson(d)).toList();

    return TransaksiModel(
      id: json['id']?.toString() ?? '',
      jadwalShiftId: json['jadwal_shift_id']?.toString() ?? '',
      kasirId: json['kasir_id']?.toString() ?? '',
      namaKasir: (json['nama_kasir'] != null && json['nama_kasir'].toString().isNotEmpty)
          ? json['nama_kasir'].toString()
          : 'Kasir',
      nomorTransaksi: json['nomor_transaksi']?.toString() ?? '',
      metodeBayar: json['metode_bayar']?.toString() ?? 'cash',
      totalHarga: double.tryParse(json['total_harga']?.toString() ?? '0') ?? 0.0,
      uangDiterima: json['uang_diterima'] != null ? double.tryParse(json['uang_diterima'].toString()) : null,
      kembalian: json['kembalian'] != null ? double.tryParse(json['kembalian'].toString()) : null,
      fotoBuktiQrisId: json['foto_bukti_qris_id']?.toString(),
      status: json['status']?.toString() ?? 'selesai',
      waktuTransaksi: waktu,
      details: items,
    );
  }
}

class RekapMenuItem {
  final String menuId;
  final String namaMenu;
  final int totalQty;
  final double totalSubtotal;

  RekapMenuItem({
    required this.menuId,
    required this.namaMenu,
    required this.totalQty,
    required this.totalSubtotal,
  });
}

class RekapBahanBOMItem {
  final String bahanId;
  final String namaBahan;
  final String satuan;
  final double estimasiTerpakai;
  final List<String> sumberMenu;

  RekapBahanBOMItem({
    required this.bahanId,
    required this.namaBahan,
    required this.satuan,
    required this.estimasiTerpakai,
    required this.sumberMenu,
  });
}

class TransaksiProvider with ChangeNotifier {
  final AuthProvider auth;

  List<TransaksiModel> _transaksiList = [];
  Map<String, List<Map<String, dynamic>>> _menuResepMap = {}; // menuId -> list of recipe items
  bool _isLoading = false;
  String? _errorMessage;

  DateTime? _selectedDate = DateTime.now();
  String _selectedStatus = 'semua'; // 'semua' | 'selesai' | 'dibatalkan'
  String _searchQuery = '';

  TransaksiProvider({required this.auth});

  List<TransaksiModel> get allTransaksi => _transaksiList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  DateTime? get selectedDate => _selectedDate;
  String get selectedStatus => _selectedStatus;
  String get searchQuery => _searchQuery;

  void setDateFilter(DateTime? date) {
    _selectedDate = date;
    loadTransaksi();
  }

  void setStatusFilter(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<TransaksiModel> get filteredTransaksi {
    return _transaksiList.where((trx) {
      if (_selectedStatus != 'semua' && trx.status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchNomor = trx.nomorTransaksi.toLowerCase().contains(q);
        final matchKasir = trx.namaKasir.toLowerCase().contains(q);
        final matchMenu = trx.details.any((d) => d.namaMenu.toLowerCase().contains(q));
        if (!matchNomor && !matchKasir && !matchMenu) return false;
      }
      return true;
    }).toList();
  }

  // Summary Metrics (based on Selesai transactions)
  List<TransaksiModel> get completedTransactions {
    return _transaksiList.where((t) => t.status == 'selesai').toList();
  }

  int get totalTransaksiCount => completedTransactions.length;

  double get totalOmset =>
      completedTransactions.fold(0.0, (sum, t) => sum + t.totalHarga);

  int get totalItemTerjual => completedTransactions.fold(
      0, (sum, t) => sum + t.details.fold(0, (subSum, d) => subSum + d.qty));

  double get totalCash => completedTransactions
      .where((t) => t.metodeBayar == 'cash')
      .fold(0.0, (sum, t) => sum + t.totalHarga);

  double get totalQris => completedTransactions
      .where((t) => t.metodeBayar == 'qris')
      .fold(0.0, (sum, t) => sum + t.totalHarga);

  // Rekap Menu Terjual (Penjualannya menu apa saja)
  List<RekapMenuItem> get rekapMenuTerjual {
    final Map<String, RekapMenuItem> map = {};
    for (final trx in completedTransactions) {
      for (final item in trx.details) {
        final key = item.menuId.isNotEmpty ? item.menuId : item.namaMenu;
        if (!map.containsKey(key)) {
          map[key] = RekapMenuItem(
            menuId: item.menuId,
            namaMenu: item.namaMenu,
            totalQty: item.qty,
            totalSubtotal: item.subtotal,
          );
        } else {
          final existing = map[key]!;
          map[key] = RekapMenuItem(
            menuId: existing.menuId,
            namaMenu: existing.namaMenu,
            totalQty: existing.totalQty + item.qty,
            totalSubtotal: existing.totalSubtotal + item.subtotal,
          );
        }
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.totalQty.compareTo(a.totalQty));
    return list;
  }

  // Rekap Pengurangan Bahan BOM (Perkiraan Uji Coba Stok Akhir)
  List<RekapBahanBOMItem> get rekapBahanBOM {
    final Map<String, RekapBahanBOMItem> map = {};

    for (final menuRekap in rekapMenuTerjual) {
      final recipes = _menuResepMap[menuRekap.menuId] ?? [];
      for (final r in recipes) {
        final bId = (r['bahan_id'] ?? '').toString();
        final bNama = (r['nama_bahan'] ?? 'Bahan').toString();
        final bSatuan = (r['satuan'] ?? '').toString();
        final takaran = double.tryParse(r['jumlah_terpakai']?.toString() ?? '0') ?? 0.0;
        final usage = takaran * menuRekap.totalQty;

        if (!map.containsKey(bId)) {
          map[bId] = RekapBahanBOMItem(
            bahanId: bId,
            namaBahan: bNama,
            satuan: bSatuan,
            estimasiTerpakai: usage,
            sumberMenu: ['${menuRekap.totalQty}x ${menuRekap.namaMenu}'],
          );
        } else {
          final existing = map[bId]!;
          final updatedSumber = List<String>.from(existing.sumberMenu)
            ..add('${menuRekap.totalQty}x ${menuRekap.namaMenu}');
          map[bId] = RekapBahanBOMItem(
            bahanId: bId,
            namaBahan: existing.namaBahan,
            satuan: existing.satuan,
            estimasiTerpakai: existing.estimasiTerpakai + usage,
            sumberMenu: updatedSumber,
          );
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => a.namaBahan.compareTo(b.namaBahan));
    return list;
  }

  Future<void> loadInitialData() async {
    await Future.wait([
      _loadRecipes(),
      loadTransaksi(),
    ]);
  }

  Future<void> _loadRecipes() async {
    try {
      final resp = await http.get(
        Uri.parse(ApiEndpoints.menu),
        headers: auth.authHeaders,
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        final Map<String, List<Map<String, dynamic>>> map = {};
        for (final m in data) {
          final menuId = (m['id'] ?? '').toString();
          final rawResep = m['resep'] as List? ?? [];
          map[menuId] = rawResep.cast<Map<String, dynamic>>();
        }
        _menuResepMap = map;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading recipes for BOM calculation: $e');
    }
  }

  Future<void> loadTransaksi() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String url = ApiEndpoints.transaksi;
      if (_selectedDate != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        url += '?tanggal=$dateStr';
      }

      final resp = await http.get(
        Uri.parse(url),
        headers: auth.authHeaders,
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        _transaksiList = data.map((json) => TransaksiModel.fromJson(json)).toList();
      } else {
        _errorMessage = 'Gagal memuat transaksi (${resp.statusCode})';
      }
    } catch (e) {
      _errorMessage = 'Koneksi ke server bermasalah: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> batalkanTransaksi(String transaksiId) async {
    try {
      final resp = await http.post(
        Uri.parse(ApiEndpoints.voidTransaksi(transaksiId)),
        headers: auth.authHeaders,
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        await loadTransaksi();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
