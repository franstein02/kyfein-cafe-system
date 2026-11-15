import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/constants/api_endpoints.dart';
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
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

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
        '${ApiEndpoints.kdsOrders}/$targetArea?include_selesai=true',
      );
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
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

  void connectWebSocket(String area) {
    disconnectWebSocket();
    try {
      final base = ApiConfig.baseUrl;
      final wsBase = base.startsWith('https://')
          ? base.replaceFirst('https://', 'wss://')
          : base.replaceFirst('http://', 'ws://');
      final wsUrl = '$wsBase/kds/ws/$area';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      notifyListeners();

      _wsSub = _channel!.stream.listen(
        (rawMessage) {
          try {
            final data = jsonDecode(rawMessage.toString()) as Map<String, dynamic>;
            final item = KdsOrderItem.fromJson(data);
            if (item.id.isEmpty) return;

            final idx = _orders.indexWhere((o) => o.id == item.id);
            if (idx >= 0) {
              _orders[idx] = _orders[idx].copyWith(statusItem: item.statusItem);
            } else {
              _orders.insert(0, item);
            }
            notifyListeners();
          } catch (_) {}
        },
        onError: (_) {
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
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
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
  }

  Future<bool> updateStatusItem(String detailId, String newStatus) async {
    try {
      final uri = Uri.parse(
        '${ApiEndpoints.kdsOrders}/detail/$detailId/status?status_item=$newStatus',
      );
      final resp = await http.put(
        uri,
        headers: _headers,
        body: jsonEncode({'status_item': newStatus}),
      );
      if (resp.statusCode == 200) {
        final idx = _orders.indexWhere((o) => o.id == detailId);
        if (idx >= 0) {
          _orders[idx] = _orders[idx].copyWith(statusItem: newStatus);
          notifyListeners();
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    disconnectWebSocket();
    super.dispose();
  }
}

