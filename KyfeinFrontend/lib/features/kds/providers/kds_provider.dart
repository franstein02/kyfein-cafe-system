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
  bool _realtimeActive = false;
  bool _disposed = false;
  String _selectedArea = 'kitchen'; // kitchen | bar | all
  String? _errorMessage;
  List<KdsOrderItem> _orders = [];
  final Set<String> _updatingDetailIds = {};
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get selectedArea => _selectedArea;
  String? get errorMessage => _errorMessage;
  List<KdsOrderItem> get orders => _orders;
  bool isUpdatingDetail(String id) => _updatingDetailIds.contains(id);

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
    _realtimeActive = true;
    _selectedArea = area;
    await loadOrders(area: area);
    if (_disposed) return;
    connectWebSocket(area);
    _startFallbackPolling();
  }

  Future<void> loadOrders({String? area}) =>
      _loadOrdersInternal(area: area, silent: false);

  Future<void> _loadOrdersInternal({String? area, bool silent = false}) async {
    final targetArea = area ?? _selectedArea;
    _selectedArea = targetArea;
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final uri = Uri.parse(
        '${ApiEndpoints.kdsOrders(targetArea)}?include_selesai=true',
      );
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (_disposed || _selectedArea != targetArea) return;
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _orders = list
            .map((e) => KdsOrderItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _errorMessage = null;
      } else if (!silent) {
        _errorMessage = 'Gagal memuat antrian KDS (${resp.statusCode})';
      }
    } catch (_) {
      if (!silent) {
        _errorMessage = 'Tidak bisa terhubung ke server KDS';
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  void _startFallbackPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_disposed || !_realtimeActive) return;
      // Poll secara aktif saat WebSocket tidak tersambung agar pesanan tetap masuk
      if (!_isConnected) {
        _loadOrdersInternal(area: _selectedArea, silent: true);
      }
    });
  }

  void _scheduleReconnect(String area) {
    _reconnectTimer?.cancel();
    if (_disposed || !_realtimeActive) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed || !_realtimeActive || _isConnected) return;
      if (_selectedArea == area) {
        connectWebSocket(area);
      }
    });
  }

  void _handleWsDisconnected(String area) {
    _pingTimer?.cancel();
    _pingTimer = null;
    if (_isConnected) {
      _isConnected = false;
      if (!_disposed) notifyListeners();
    }
    _scheduleReconnect(area);
  }

  void connectWebSocket(String area) {
    disconnectWebSocket();
    try {
      final wsUrl = ApiEndpoints.kdsWs(area);
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      if (!_disposed) notifyListeners();

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {}
      });

      _wsSub = _channel!.stream.listen(
        (rawMessage) {
          if (_disposed || _selectedArea != area) return;
          try {
            final data = jsonDecode(rawMessage.toString()) as Map<String, dynamic>;
            final event = (data['event'] ?? '').toString();
            final detailId = (data['id'] ?? data['detail_id'] ?? '').toString();
            if (event == 'order_cancelled') {
              final trxId = (data['transaksi_id'] ?? '').toString();
              _orders.removeWhere(
                (o) =>
                    (detailId.isNotEmpty && o.id == detailId) ||
                    (trxId.isNotEmpty && o.transaksiId == trxId),
              );
              notifyListeners();
              return;
            }

            final item = KdsOrderItem.fromJson(data);
            if (item.id.isEmpty) return;
            if (_selectedArea != 'all' && item.areaProduksi != _selectedArea) {
              return;
            }

            final idx = _orders.indexWhere((o) => o.id == item.id);
            if (idx >= 0) {
              _orders[idx] = _orders[idx].copyWith(statusItem: item.statusItem);
            } else {
              _orders.insert(0, item);
            }
            notifyListeners();
          } catch (_) {}
        },
        onError: (_) => _handleWsDisconnected(area),
        onDone: () => _handleWsDisconnected(area),
      );
    } catch (_) {
      _handleWsDisconnected(area);
    }
  }

  void stopRealtime() {
    _realtimeActive = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    disconnectWebSocket();
  }

  void disconnectWebSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
  }

  Future<bool> updateStatusItem(String detailId, String newStatus) async {
    if (_updatingDetailIds.contains(detailId)) return false;
    _updatingDetailIds.add(detailId);
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse(
        '${ApiEndpoints.kdsDetailStatus(detailId)}?status_item=$newStatus',
      );
      final resp = await http
          .put(
            uri,
            headers: _headers,
            body: jsonEncode({'status_item': newStatus}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final idx = _orders.indexWhere((o) => o.id == detailId);
        if (idx >= 0) {
          _orders[idx] = _orders[idx].copyWith(statusItem: newStatus);
        }
        return true;
      }
      try {
        final decoded = jsonDecode(resp.body);
        _errorMessage = decoded['detail']?.toString() ??
            'Gagal memperbarui status pesanan (${resp.statusCode})';
      } catch (_) {
        _errorMessage = 'Gagal memperbarui status pesanan (${resp.statusCode})';
      }
    } catch (_) {
      _errorMessage = 'Tidak bisa terhubung ke server';
    } finally {
      _updatingDetailIds.remove(detailId);
      if (!_disposed) {
        notifyListeners();
      }
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    stopRealtime();
    super.dispose();
  }
}

