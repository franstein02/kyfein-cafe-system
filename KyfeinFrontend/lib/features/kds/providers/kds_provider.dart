import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/firebase_http_adapter.dart';
import '../../../core/services/rtdb_service.dart';
import '../../auth/providers/auth_provider.dart';

class KdsOrderItem {
  final String id;
  final String transaksiId;
  final String nomorTransaksi;
  final String menuId;
  final String kodeMenu;
  final String namaMenu;
  final String areaProduksi;
  final int qty;
  final String? catatan;
  final String statusItem; // menunggu | diproses | selesai
  final DateTime? waktuTransaksi;

  KdsOrderItem({
    required this.id,
    required this.transaksiId,
    required this.nomorTransaksi,
    required this.menuId,
    required this.kodeMenu,
    required this.namaMenu,
    required this.areaProduksi,
    required this.qty,
    this.catatan,
    required this.statusItem,
    this.waktuTransaksi,
  });

  factory KdsOrderItem.fromJson(Map<String, dynamic> j) {
    final rawTime = (j['waktu_transaksi'] ?? j['waktu'])?.toString();
    return KdsOrderItem(
      id: (j['id'] ?? j['detail_id'] ?? '').toString(),
      transaksiId: (j['transaksi_id'] ?? '').toString(),
      nomorTransaksi: (j['nomor_transaksi'] ?? '-').toString(),
      menuId: (j['menu_id'] ?? '').toString(),
      kodeMenu: (j['kode_menu'] ?? '').toString(),
      namaMenu: (j['nama_menu'] ?? '-').toString(),
      areaProduksi: (j['area_produksi'] ?? 'kitchen').toString(),
      qty: int.tryParse((j['qty'] ?? 1).toString()) ?? 1,
      catatan: j['catatan']?.toString(),
      statusItem: (j['status_item'] ?? 'menunggu').toString(),
      waktuTransaksi: rawTime != null ? DateTime.tryParse(rawTime) : null,
    );
  }

  KdsOrderItem copyWith({String? statusItem}) => KdsOrderItem(
        id: id,
        transaksiId: transaksiId,
        nomorTransaksi: nomorTransaksi,
        menuId: menuId,
        kodeMenu: kodeMenu,
        namaMenu: namaMenu,
        areaProduksi: areaProduksi,
        qty: qty,
        catatan: catatan,
        statusItem: statusItem ?? this.statusItem,
        waktuTransaksi: waktuTransaksi,
      );
}

class KdsProvider with ChangeNotifier {
  AuthProvider? _auth;

  bool _isLoading = false;
  bool _isConnected = false;
  String _selectedArea = 'kitchen'; // kitchen | bar | all
  List<KdsOrderItem> _orders = [];
  StreamSubscription? _rtdbSub;

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get selectedArea => _selectedArea;
  List<KdsOrderItem> get orders => _orders;

  List<KdsOrderItem> get menungguOrders =>
      _orders.where((o) => o.statusItem == 'menunggu').toList();
  List<KdsOrderItem> get diprosesOrders =>
      _orders.where((o) => o.statusItem == 'diproses').toList();
  List<KdsOrderItem> get selesaiOrders =>
      _orders.where((o) => o.statusItem == 'selesai').toList();

  void updateAuth(AuthProvider auth) {
    _auth = auth;
  }

  Map<String, String> get _headers => _auth?.authHeaders ?? {};

  Future<void> initArea(String area) async {
    _selectedArea = area;
    await loadOrders(area: area);
    connectWebSocket(area);
  }

  Future<void> loadOrders({String? area}) async {
    final targetArea = area ?? _selectedArea;
    _selectedArea = targetArea;
    _isLoading = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        '${ApiEndpoints.kdsOrders(targetArea)}?include_selesai=true',
      );
      final resp = await FirebaseHttpAdapter.get(uri, headers: _headers);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _orders = list
            .map((e) => KdsOrderItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mendengarkan perubahan node `transaksi_detail` di Firebase RTDB secara realtime.
  void connectWebSocket(String area) {
    disconnectWebSocket();
    try {
      _isConnected = true;
      notifyListeners();
      _rtdbSub = RtdbService.watchNode('transaksi_detail').listen(
        (_) => loadOrders(area: area),
        onError: (_) {
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (_) {
      _isConnected = false;
      notifyListeners();
    }
  }

  void disconnectWebSocket() {
    _rtdbSub?.cancel();
    _rtdbSub = null;
    _isConnected = false;
  }

  Future<bool> updateStatusItem(String detailId, String newStatus) async {
    try {
      await RtdbService.updateRecord(
        'transaksi_detail',
        detailId,
        {'status_item': newStatus},
      );
      final idx = _orders.indexWhere((o) => o.id == detailId);
      if (idx >= 0) {
        _orders[idx] = _orders[idx].copyWith(statusItem: newStatus);
        notifyListeners();
      }
      return true;
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    disconnectWebSocket();
    super.dispose();
  }
}
