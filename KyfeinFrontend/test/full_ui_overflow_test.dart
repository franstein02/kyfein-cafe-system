import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kyfein_frontend/core/theme/app_theme.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/admin_absensi_screen.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/admin_jadwal_screen.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/kasir_absensi_screen.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/kasir_jadwal_screen.dart';
import 'package:kyfein_frontend/features/attendance/providers/attendance_provider.dart';
import 'package:kyfein_frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:kyfein_frontend/features/auth/providers/auth_provider.dart';
import 'package:kyfein_frontend/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:kyfein_frontend/features/dashboard/providers/dashboard_provider.dart';
import 'package:kyfein_frontend/features/kds/presentation/screens/kds_screen.dart';
import 'package:kyfein_frontend/features/kds/providers/kds_provider.dart';
import 'package:kyfein_frontend/features/master_data/presentation/screens/master_data_screen.dart';
import 'package:kyfein_frontend/features/master_data/providers/master_data_provider.dart';
import 'package:kyfein_frontend/features/notifications/providers/notification_provider.dart';
import 'package:kyfein_frontend/features/pos/presentation/screens/pos_screen.dart';
import 'package:kyfein_frontend/features/pos/presentation/screens/transaksi_screen.dart';
import 'package:kyfein_frontend/features/pos/providers/pos_provider.dart';
import 'package:kyfein_frontend/features/reporting/presentation/screens/reporting_screen.dart';
import 'package:kyfein_frontend/features/reporting/providers/reporting_provider.dart';
import 'package:kyfein_frontend/features/stok/presentation/screens/catat_opname_screen.dart';
import 'package:kyfein_frontend/features/stok/presentation/screens/stok_gudang_screen.dart';
import 'package:kyfein_frontend/features/stok/presentation/screens/stok_opname_hub_screen.dart';

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider({
    this.fakeRole = 'admin',
    this.fakeDivisi,
    this.fakeNama = 'Frans Admin',
  });

  final String fakeRole;
  final String? fakeDivisi;
  final String fakeNama;

  @override
  String? get role => fakeRole;

  @override
  String? get divisi => fakeDivisi;

  @override
  String? get nama => fakeNama;

  @override
  String? get karyawanId => 'usr-1';

  @override
  String? get token => 'mock-jwt-token';

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer mock-jwt-token',
      };
}

class _FakeDashboardProvider extends DashboardProvider {
  _FakeDashboardProvider({
    this.fakeShiftAktif,
  });

  final ShiftAktif? fakeShiftAktif;

  @override
  bool get isLoading => false;

  @override
  ShiftAktif? get shiftAktif => fakeShiftAktif;

  @override
  List<StokMenipis> get stokMenipis => const [];

  @override
  List<PendingApproval> get pendingApprovals => const [];

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadDashboard() async {}
}

class _FakeKdsProvider extends KdsProvider {
  bool _connected = false;
  String _area = 'kitchen';
  final List<KdsOrderItem> _items = [
    KdsOrderItem(
      id: 'det-1',
      transaksiId: 'trx-1',
      nomorTransaksi: 'TRX-20261116-0001',
      menuId: 'm-1',
      kodeMenu: 'NAS01',
      namaMenu: 'Nasi Goreng Spesial',
      areaProduksi: 'kitchen',
      qty: 2,
      catatan: 'Pedas sedang, tanpa acar',
      statusItem: 'menunggu',
      waktuTransaksi: DateTime(2026, 11, 16, 10, 30),
    ),
    KdsOrderItem(
      id: 'det-2',
      transaksiId: 'trx-2',
      nomorTransaksi: 'TRX-20261116-0002',
      menuId: 'm-2',
      kodeMenu: 'ESP01',
      namaMenu: 'Iced Americano Long Name Variant Check',
      areaProduksi: 'bar',
      qty: 1,
      catatan: 'Less sugar',
      statusItem: 'diproses',
      waktuTransaksi: DateTime(2026, 11, 16, 10, 45),
    ),
    KdsOrderItem(
      id: 'det-3',
      transaksiId: 'trx-3',
      nomorTransaksi: 'TRX-20261116-0003',
      menuId: 'm-1',
      kodeMenu: 'NAS01',
      namaMenu: 'Rice Bowl Chicken Teriyaki',
      areaProduksi: 'kitchen',
      qty: 1,
      statusItem: 'selesai',
      waktuTransaksi: DateTime(2026, 11, 16, 10, 15),
    ),
  ];

  @override
  bool get isLoading => false;

  @override
  bool get isConnected => _connected;

  @override
  String get selectedArea => _area;

  @override
  List<KdsOrderItem> get orders => _area == 'all'
      ? _items
      : _items.where((o) => o.areaProduksi == _area).toList();

  @override
  List<KdsOrderItem> get menungguOrders =>
      orders.where((o) => o.statusItem == 'menunggu').toList();

  @override
  List<KdsOrderItem> get diprosesOrders =>
      orders.where((o) => o.statusItem == 'diproses').toList();

  @override
  List<KdsOrderItem> get selesaiOrders =>
      orders.where((o) => o.statusItem == 'selesai').toList();

  @override
  Future<void> initArea(String area) async {
    _area = area;
    _connected = true;
    notifyListeners();
  }

  @override
  Future<void> loadOrders({String? area}) async {
    if (area != null) _area = area;
    notifyListeners();
  }

  @override
  Future<bool> updateStatusItem(String detailId, String newStatus) async {
    final idx = _items.indexWhere((o) => o.id == detailId);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(statusItem: newStatus);
      notifyListeners();
    }
    return true;
  }

  @override
  void dispose() {
    // WebSocket tidak dibuka di test widget, tetap panggil super.dispose().
    super.dispose();
  }
}

class _StubHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _StubHttpClient();
}

class _StubHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _StubHttpClientRequest(method, url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubHttpClientRequest implements HttpClientRequest {
  _StubHttpClientRequest(this.method, this.url);

  @override
  final String method;
  final Uri url;

  @override
  final HttpHeaders headers = _StubHttpHeaders();

  @override
  Encoding encoding = utf8;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = true;

  @override
  bool bufferOutput = true;

  final List<int> _body = [];

  @override
  void add(List<int> data) => _body.addAll(data);

  @override
  void write(Object? object) {
    if (object != null) _body.addAll(utf8.encode(object.toString()));
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _body.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    if (url.path.toLowerCase().endsWith('.png') ||
        url.path.contains('/foto/')) {
      // Valid 1x1 transparent PNG
      const pngBytes = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      return _StubHttpClientResponse(200, pngBytes);
    }
    if (method == 'PUT' && url.path.contains('/absensi/izin-telat/it-conflict/approval')) {
      _simulatePendingConflictIzinTelat = false;
      return _StubHttpClientResponse(
        409,
        utf8.encode(jsonEncode({
          'detail': 'Pengajuan izin telat ini sudah diproses (bukan pending)',
        })),
      );
    }
    final jsonBody = _mockJsonForUri(method, url);
    return _StubHttpClientResponse(200, utf8.encode(jsonEncode(jsonBody)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _StubHttpClientResponse(this.statusCode, this._bytes);

  @override
  final int statusCode;
  final List<int> _bytes;

  @override
  int get contentLength => _bytes.length;

  @override
  final HttpHeaders headers = _StubHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _map.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  List<String>? operator [](String name) => _map[name.toLowerCase()];

  @override
  String? value(String name) => _map[name.toLowerCase()]?.firstOrNull;

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _map.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

bool _simulatePendingConflictIzinTelat = false;
bool _simulateIncomingTukarShift = false;
bool _simulateOpnameHarianSesi = false;

dynamic _mockJsonForUri(String method, Uri uri) {
  final path = uri.path;
  const today = '2026-11-16';

  if (path.endsWith('/karyawan') || path.endsWith('/karyawan/')) {
    return [
      {
        'id': 'usr-1',
        'nama': 'Frans Admin',
        'email': 'frans@kyfein.com',
        'nomor_hp': '0811111111',
        'role': 'admin',
        'divisi': null,
        'status_aktif': true,
      },
      {
        'id': 'usr-2',
        'nama': 'Dila Kasir',
        'email': 'dila@kyfein.com',
        'nomor_hp': '0822222222',
        'role': 'karyawan',
        'divisi': 'kasir',
        'status_aktif': true,
      },
      {
        'id': 'usr-3',
        'nama': 'Siti Kitchen',
        'email': 'siti@kyfein.com',
        'nomor_hp': '0833333333',
        'role': 'karyawan',
        'divisi': 'kitchen',
        'status_aktif': true,
      },
    ];
  }

  if (path.contains('/jadwal/shift-template')) {
    return [
      {
        'id': 'tpl-1',
        'shift': 'shift_1',
        'nama': 'Shift 1',
        'jam_mulai': '08:00:00',
        'jam_selesai': '16:00:00',
        'updated_at': '${today}T08:00:00',
      },
      {
        'id': 'tpl-mid',
        'shift': 'middle_shift',
        'nama': 'Middle Shift',
        'jam_mulai': '12:00:00',
        'jam_selesai': '20:00:00',
        'updated_at': '${today}T08:00:00',
      },
      {
        'id': 'tpl-2',
        'shift': 'shift_2',
        'nama': 'Shift 2',
        'jam_mulai': '16:00:00',
        'jam_selesai': '23:00:00',
        'updated_at': '${today}T08:00:00',
      },
    ];
  }

  if (path.endsWith('/jadwal') || path.endsWith('/jadwal/')) {
    return [
      {
        'id': 'jdw-1',
        'karyawan_id': 'usr-2',
        'tanggal': today,
        'shift': 'shift_1',
        'area_kerja': 'kasir',
        'jam_mulai': '08:00:00',
        'jam_selesai': '16:00:00',
        'created_at': '${today}T07:00:00',
      },
      {
        'id': 'jdw-2',
        'karyawan_id': 'usr-3',
        'tanggal': today,
        'shift': 'middle_shift',
        'area_kerja': 'kitchen',
        'jam_mulai': '12:00:00',
        'jam_selesai': '20:00:00',
        'created_at': '${today}T07:00:00',
      },
    ];
  }

  if (path.endsWith('/jadwal/shift-aktif') ||
      path.endsWith('/jadwal/shift-aktif/')) {
    return {
      'id': 'jdw-1',
      'tanggal': today,
      'area_kerja': 'kasir',
      'shift': 'middle_shift',
      'shift_nama': 'Middle Shift',
      'jam_mulai': '12:00',
      'jam_selesai': '20:00',
      'karyawan_id': 'usr-2',
      'absensi': null,
    };
  }

  if (path.contains('/absensi/status')) {
    return {
      'has_shift': true,
      'shift_id': 'jdw-1',
      'shift': 'middle_shift',
      'area_kerja': 'kasir',
      'jam_mulai': '12:00',
      'jam_selesai': '20:00',
      'sudah_masuk': false,
      'sudah_pulang': false,
      'absensi': null,
      'izin_telat': null,
      'izin_tidak_masuk': null,
    };
  }

  if (path.contains('/master/konfigurasi-lokasi')) {
    return {
      'id': 'lok-1',
      'latitude': -6.200000,
      'longitude': 106.800000,
      'radius_meter': 100.0,
      'updated_at': '${today}T08:00:00',
    };
  }

  if (path.contains('/absensi/izin-telat')) {
    if (_simulatePendingConflictIzinTelat) {
      return [
        {
          'id': 'it-conflict',
          'karyawan_id': 'usr-2',
          'jadwal_shift_id': 'jdw-1',
          'alasan': 'Ban bocor',
          'status': 'pending',
          'diajukan_at': '${today}T08:56:00',
        },
      ];
    }
    return [];
  }

  if (path.contains('/absensi/izin-tidak-masuk') ||
      path.contains('/jadwal/request-off')) {
    return [];
  }

  if (path.contains('/jadwal/tukar-shift')) {
    if (_simulateIncomingTukarShift) {
      return [
        {
          'id': 'ts-in-1',
          'shift_a_id': 'jdw-1',
          'shift_b_id': 'jdw-2',
          'karyawan_pengaju_id': 'usr-2',
          'karyawan_target_id': 'usr-1',
          'status': 'pending',
          'status_target': 'pending',
          'alasan': 'Ada acara keluarga pagi',
          'diajukan_at': '${today}T08:00:00',
          'nama_pengaju': 'Dila Barista',
          'nama_target': 'Budi Staff',
          'tanggal_shift': today,
          'info_shift_a': '$today · SHIFT 1 (BAR) · 08:00–16:00',
          'info_shift_b': '$today · SHIFT 2 (BAR) · 16:00–23:00',
        },
      ];
    }
    return [];
  }

  if (path.endsWith('/absensi') || path.endsWith('/absensi/')) {
    return [
      {
        'id': 'abs-1',
        'karyawan_id': 'usr-2',
        'jadwal_shift_id': 'jdw-1',
        'jam_masuk': '${today}T12:03:00',
        'jam_pulang': null,
        'menit_telat': 3,
        'status_pulang': null,
      },
    ];
  }

  if (path.contains('/master/kategori-menu')) {
    return [
      {
        'id': 'kat-1',
        'nama': 'Coffee',
        'area_produksi': 'bar',
        'status_aktif': true,
      },
      {
        'id': 'kat-2',
        'nama': 'Main Course',
        'area_produksi': 'kitchen',
        'status_aktif': true,
      },
    ];
  }

  if (path.contains('/master/menu')) {
    return [
      {
        'id': 'menu-1',
        'nama': 'Espresso Latte Signature',
        'kode_menu': 'ESP01',
        'harga': 28000,
        'kategori_id': 'kat-1',
        'status_aktif': true,
        'resep': [
          {
            'id': 'r-1',
            'bahan_id': 'b-1',
            'nama_bahan': 'Kopi Arabica',
            'satuan': 'gram',
            'jumlah_terpakai': 18,
          }
        ],
      },
      {
        'id': 'menu-2',
        'nama': 'Nasi Goreng Kampung',
        'kode_menu': 'NGK01',
        'harga': 35000,
        'kategori_id': 'kat-2',
        'status_aktif': true,
        'resep': [],
      },
    ];
  }

  if (path.contains('/master/bahan/stok-menipis')) {
    return [
      {
        'id': 'b-1',
        'nama': 'Kopi Arabica',
        'satuan': 'gram',
        'satuan_dasar': 'gram',
        'isi_per_kemasan': 1000,
        'stok_minimum': 5,
        'batas_stok_minimum': 5,
        'total_stok': 200,
      },
    ];
  }

  if (path.contains('/master/bahan')) {
    return [
      {
        'id': 'b-1',
        'nama': 'Bean',
        'satuan': 'gr',
        'area': 'bar',
        'isi_per_kemasan': 1000,
        'stok_minimum': 50,
        'harga_rata_rata': 200,
      },
      {
        'id': 'b-kitchen-1',
        'nama': 'Beras Putih',
        'satuan': 'gram',
        'area': 'kitchen',
        'isi_per_kemasan': 5000,
        'stok_minimum': 4,
        'harga_rata_rata': 14.5,
      },
      {
        'id': 'b-kitchen-2',
        'nama': 'Ayam Fillet',
        'satuan': 'gram',
        'area': 'kitchen',
        'isi_per_kemasan': 1000,
        'stok_minimum': 5,
        'harga_rata_rata': 44.0,
      },
      {
        'id': 'b-kitchen-3',
        'nama': 'Daging Kambing',
        'satuan': 'gram',
        'area': 'kitchen',
        'isi_per_kemasan': 1000,
        'stok_minimum': 3,
        'harga_rata_rata': 130.0,
      },
      {
        'id': 'b-kitchen-4',
        'nama': 'Telur Ayam',
        'satuan': 'pcs',
        'area': 'kitchen',
        'isi_per_kemasan': 15,
        'stok_minimum': 4,
        'harga_rata_rata': 1800.0,
      },
      {
        'id': 'b-kitchen-5',
        'nama': 'Minyak Goreng',
        'satuan': 'ml',
        'area': 'kitchen',
        'isi_per_kemasan': 2000,
        'stok_minimum': 5,
        'harga_rata_rata': 18.5,
      },
      {
        'id': 'b-kitchen-6',
        'nama': 'Sosis Sapi',
        'satuan': 'gram',
        'area': 'kitchen',
        'isi_per_kemasan': 1000,
        'stok_minimum': 4,
        'harga_rata_rata': 60.0,
      },
    ];
  }

  if (path.contains('/master/kategori-pengeluaran')) {
    return [
      {'id': 'kp-1', 'nama': 'Listrik & Air', 'status_aktif': true},
      {'id': 'kp-2', 'nama': 'Belanja Harian', 'status_aktif': true},
    ];
  }

  if (path.contains('/transaksi/shift-aktif/laporan')) {
    return {
      'jadwal_shift_id': 'jdw-1',
      'karyawan_id': 'usr-2',
      'tanggal': today,
      'shift': 'middle_shift',
      'total_transaksi': 4,
      'total_penjualan': 125000,
      'total_cash': 75000,
      'total_qris': 50000,
      'shift_locked_by_opname': false,
    };
  }

  if (path.endsWith('/transaksi') || path.endsWith('/transaksi/')) {
    if (method == 'POST') {
      return {
        'id': 'trx-qris-1',
        'nomor_transaksi': 'TRX-20261118-QRIS1',
        'kasir_id': 'usr-2',
        'nama_kasir': 'Dila Kasir',
        'jadwal_shift_id': 'jdw-1',
        'metode_bayar': 'qris',
        'total_harga': 28000,
        'uang_diterima': 28000,
        'kembalian': null,
        'foto_bukti_qris_id': null,
        'status': 'selesai',
        'waktu_transaksi': '${today}T10:00:00',
        'details': [],
      };
    }
    return [
      {
        'id': 'trx-1',
        'nomor_transaksi': 'TRX-20261116-0001',
        'kasir_id': 'usr-2',
        'nama_kasir': 'Dila Kasir',
        'jadwal_shift_id': 'jdw-1',
        'metode_bayar': 'cash',
        'total_harga': 63000,
        'uang_diterima': 100000,
        'kembalian': 37000,
        'status': 'selesai',
        'waktu_transaksi': '${today}T13:00:00',
        'details': [
          {
            'id': 'det-1',
            'menu_id': 'menu-1',
            'nama_menu': 'Espresso Latte Signature',
            'qty': 1,
            'harga_satuan': 28000,
            'subtotal': 28000,
            'status_item': 'selesai',
            'area_produksi': 'bar',
          },
          {
            'id': 'det-2',
            'menu_id': 'menu-2',
            'nama_menu': 'Nasi Goreng Kampung',
            'qty': 1,
            'harga_satuan': 35000,
            'subtotal': 35000,
            'status_item': 'menunggu',
            'area_produksi': 'kitchen',
          },
        ],
      },
    ];
  }

  if (path.contains('/stok/stok-gudang')) {
    return [
      {
        'id': 'sg-1',
        'bahan_id': 'b-1',
        'nama_bahan': 'Kopi Arabica',
        'jumlah_kemasan_besar': 2,
        'jumlah_satuan_kecil': 500,
        'updated_at': '${today}T09:00:00',
        'bahan': {
          'id': 'b-1',
          'nama': 'Kopi Arabica',
          'satuan': 'gram',
          'area': 'bar',
          'isi_per_kemasan': 1000,
          'stok_minimum': 5,
          'harga_rata_rata': 150,
        },
        'harga_rata_rata': 150,
        'harga_rata_rata_per_kemasan': 150000,
        'nilai_persediaan': 375000,
        'bom_pemakaian': [
          {
            'menu_id': 'menu-1',
            'kode_menu': 'MNM01',
            'nama_menu': 'Espresso Latte Signature',
            'area_produksi': 'bar',
            'jumlah_terpakai': 18,
            'biaya_per_porsi': 2700,
            'estimasi_porsi': 138,
          },
          {
            'menu_id': 'menu-3',
            'kode_menu': 'MNM02',
            'nama_menu': 'Americano Iced',
            'area_produksi': 'bar',
            'jumlah_terpakai': 15,
            'biaya_per_porsi': 2250,
            'estimasi_porsi': 166,
          },
        ],
      },
    ];
  }

  if (path.contains('/stok/opname/harian')) {
    if (!_simulateOpnameHarianSesi) {
      return {
        'tanggal': today,
        'sesi': [],
        'items': [],
        'perbandingan_shift': [],
      };
    }
    return {
      'tanggal': today,
      'sesi': [
        {
          'id': 'op-1',
          'jadwal_shift_id': 'jdw-s1',
          'shift_key': 'shift_1',
          'shift_label': 'Shift 1',
          'titik': 'bar',
          'tipe': 'awal_shift',
          'metode': 'hitung_manual',
          'karyawan_nama': 'Bar 1',
          'waktu_opname': '${today}T08:05:00',
          'items_count': 1,
        },
      ],
      'items': [
        {
          'bahan_id': 'b-uht',
          'nama_bahan': 'Susu UHT',
          'satuan': 'ml',
          'titik': 'bar',
          'stok_awal': 1000,
          'transfer_masuk': 0,
          'pemakaian_bom': 45,
          'ekspektasi_stok': 955,
          'stok_akhir': 900,
          'selisih': 100,
          'selisih_vs_bom': -55,
          'diagnosa': 'Indikasi Tumpah / Susut / Over-portion',
          'status': 'lengkap',
        },
      ],
      'perbandingan_shift': [
        {
          'bahan_id': 'b-uht',
          'nama_bahan': 'Susu UHT',
          'satuan': 'ml',
          'titik': 'bar',
          'shift_1': {
            'shift_key': 'shift_1',
            'shift_label': 'Shift 1',
            'karyawan_nama': 'Bar 1',
            'stok_awal': 1000,
            'transfer_masuk': 0,
            'pemakaian_bom': 45,
            'ekspektasi_stok': 955,
            'stok_akhir': 900,
            'pemakaian_aktual': 100,
            'selisih_vs_bom': -55,
            'status_audit': 'lebih_boros',
            'diagnosa': 'Indikasi Tumpah / Susut / Over-portion',
          },
          'shift_2': {
            'shift_key': 'shift_2',
            'shift_label': 'Shift 2',
            'karyawan_nama': 'Bar 2',
            'stok_awal': 880,
            'transfer_masuk': 0,
            'pemakaian_bom': 80,
            'ekspektasi_stok': 800,
            'stok_akhir': 800,
            'pemakaian_aktual': 80,
            'selisih_vs_bom': 0,
            'status_audit': 'sesuai',
            'diagnosa': 'Sesuai Ekspektasi BOM',
          },
          'selisih_akhir_s1_vs_awal_s2': -20,
          'selisih_stok_akhir_s1_vs_s2': -100,
          'selisih_pemakaian_s1_vs_s2': -20,
          'selisih_varians_s1_vs_s2': 55,
          'status_handover': 'kurang',
          'catatan_perbandingan':
              'Selisih serah terima S1→S2 kurang -20 ml (Akhir S1: 900 vs Awal S2: 880)',
        },
      ],
    };
  }

  if (path.contains('/stok/opname/audit')) {
    return {
      'tanggal': today,
      'summary': {
        'total_transaksi': 3,
        'total_item_terjual': 5,
        'total_bahan_diaudit': 1,
        'bahan_sesuai': 0,
        'bahan_selisih': 1,
        'bahan_belum_lengkap': 0,
        'bahan_indikasi_tumpah': 1,
        'bahan_surplus': 0,
        'total_shift_dibandingkan': 1,
        'handover_selisih_count': 1,
      },
      'items': [
        {
          'bahan_id': 'b-uht',
          'nama_bahan': 'Susu UHT',
          'satuan': 'ml',
          'titik': 'bar',
          'stok_awal': 1000,
          'transfer_masuk': 0,
          'stok_akhir': 900,
          'pemakaian_fisik': 100,
          'pemakaian_bom': 45,
          'ekspektasi_stok': 955,
          'selisih_stok_akhir_vs_ekspektasi': -55,
          'varians': -55,
          'persentase_selisih': -122.22,
          'status_audit': 'lebih_boros',
          'diagnosa': 'Indikasi Tumpah / Susut / Over-portion',
          'penjelasan_diagnosa':
              'Stok akhir aktual (900 ml) kurang 55 ml dari ekspektasi sistem (955 ml). Pemakaian aktual 100 vs BOM 45 ml — indikasi tumpah, susut, atau takaran berlebih.',
          'detail_menu': [
            {
              'menu_id': 'menu-1',
              'nama_menu': 'Espresso Latte Signature',
              'qty_terjual': 3,
              'takaran': 15,
              'subtotal_bom': 45,
            },
          ],
        },
      ],
      'perbandingan_shift': [
        {
          'bahan_id': 'b-uht',
          'nama_bahan': 'Susu UHT',
          'satuan': 'ml',
          'titik': 'bar',
          'shift_1': {
            'shift_key': 'shift_1',
            'shift_label': 'Shift 1',
            'karyawan_nama': 'Bar 1',
            'stok_awal': 1000,
            'transfer_masuk': 0,
            'pemakaian_bom': 45,
            'ekspektasi_stok': 955,
            'stok_akhir': 900,
            'pemakaian_aktual': 100,
            'selisih_vs_bom': -55,
            'status_audit': 'lebih_boros',
            'diagnosa': 'Indikasi Tumpah / Susut / Over-portion',
          },
          'shift_2': {
            'shift_key': 'shift_2',
            'shift_label': 'Shift 2',
            'karyawan_nama': 'Bar 2',
            'stok_awal': 880,
            'transfer_masuk': 0,
            'pemakaian_bom': 80,
            'ekspektasi_stok': 800,
            'stok_akhir': 800,
            'pemakaian_aktual': 80,
            'selisih_vs_bom': 0,
            'status_audit': 'sesuai',
            'diagnosa': 'Sesuai Ekspektasi BOM',
          },
          'selisih_akhir_s1_vs_awal_s2': -20,
          'selisih_stok_akhir_s1_vs_s2': -100,
          'selisih_pemakaian_s1_vs_s2': -20,
          'selisih_varians_s1_vs_s2': 55,
          'status_handover': 'kurang',
          'catatan_perbandingan':
              'Selisih serah terima S1→S2 kurang -20 ml (Akhir S1: 900 vs Awal S2: 880)',
        },
      ],
    };
  }

  if (path.contains('/reporting/profit-periode')) {
    return {
      'filter': 'harian',
      'periode_mulai': today,
      'periode_selesai': today,
      'jumlah_transaksi': 12,
      'jumlah_transaksi_dibatalkan': 1,
      'total_cash': 400000,
      'total_qris': 350000,
      'total_penjualan': 750000,
      'total_hpp_teoritis': 250000,
      'laba_kotor': 500000,
      'gross_margin_persen': 66.67,
      'pengeluaran_bulanan_pro_rata': 50000,
      'pengeluaran_mendadak': 30000,
      'total_operasional': 80000,
      'net_profit': 420000,
      'net_margin_persen': 56.0,
      'menu_tanpa_resep': [],
      'jumlah_barang_masuk': 2,
      'total_belanja_barang_masuk': 564000,
      'total_pengeluaran_kas': 644000,
      'arus_kas_bersih': 106000,
      'nilai_aset_stok_gudang': 42000000,
      'nilai_aset_stok_titik': 1233500,
      'nilai_aset_stok_saat_ini': 43233500,
      'jumlah_barang_keluar': 3,
      'jumlah_sesi_opname': 2,
      'jumlah_stok_menipis': 1,
      'total_shift_terjadwal': 5,
      'total_hadir': 4,
      'total_tepat_waktu': 2,
      'total_terlambat': 2,
      'total_menit_telat': 35,
      'total_izin_telat': 1,
      'total_izin_tidak_masuk': 0,
      'total_tanpa_keterangan': 1,
      'total_lupa_absen_pulang': 1,
      'tingkat_ketepatan_persen': 50.0,
      'absensi_per_karyawan': [
        {
          'karyawan_id': 'usr-bar1',
          'nama': 'Bar 1',
          'divisi': 'bar',
          'total_shift_terjadwal': 3,
          'total_hadir': 2,
          'tepat_waktu_count': 0,
          'telat_count': 2,
          'total_menit_telat': 35,
          'rata_menit_telat': 17.5,
          'izin_telat_count': 1,
          'izin_tidak_masuk_count': 0,
          'lupa_absen_pulang_count': 1,
          'tanpa_keterangan_count': 1,
          'tukar_shift_count': 1,
          'tingkat_ketepatan_persen': 0.0,
          'kategori_perilaku': 'perlu_perhatian',
          'ringkasan_perilaku': 'Telat 2x (total 35 mnt, rata-rata 17.5 mnt) · Alpha 1x · Lupa absen pulang 1x',
          'riwayat_shift': [
            {
              'jadwal_shift_id': 'js-1',
              'tanggal': today,
              'shift': 'shift_1',
              'area_kerja': 'bar',
              'jam_mulai': '08:00',
              'jam_selesai': '16:00',
              'jam_masuk': '${today}T08:20:00',
              'jam_pulang': '${today}T16:05:00',
              'menit_telat': 20,
              'status_kehadiran': 'terlambat',
              'lupa_absen_pulang': false,
              'keterangan': 'Izin telat (disetujui): Ban bocor',
            },
            {
              'jadwal_shift_id': 'js-2',
              'tanggal': '2026-11-15',
              'shift': 'shift_1',
              'area_kerja': 'bar',
              'jam_mulai': '08:00',
              'jam_selesai': '16:00',
              'jam_masuk': null,
              'jam_pulang': null,
              'menit_telat': 0,
              'status_kehadiran': 'alpha',
              'lupa_absen_pulang': false,
              'keterangan': 'Tidak hadir tanpa keterangan',
            },
          ],
        },
        {
          'karyawan_id': 'usr-kasir1',
          'nama': 'Dila Kasir',
          'divisi': 'kasir',
          'total_shift_terjadwal': 2,
          'total_hadir': 2,
          'tepat_waktu_count': 2,
          'telat_count': 0,
          'total_menit_telat': 0,
          'rata_menit_telat': 0.0,
          'izin_telat_count': 0,
          'izin_tidak_masuk_count': 0,
          'lupa_absen_pulang_count': 0,
          'tanpa_keterangan_count': 0,
          'tukar_shift_count': 0,
          'tingkat_ketepatan_persen': 100.0,
          'kategori_perilaku': 'disiplin',
          'ringkasan_perilaku': 'Disiplin (2/2 shift tepat waktu)',
          'riwayat_shift': [],
        },
      ],
    };
  }

  if (path.contains('/reporting/pengeluaran/breakdown')) {
    return {
      'filter': 'harian',
      'periode_mulai': today,
      'periode_selesai': today,
      'total_pengeluaran': 80000,
      'total_belanja_bahan': 564000,
      'total_semua_pengeluaran': 644000,
      'items': [
        {
          'kategori_id': 'kp-1',
          'nama_kategori': 'Listrik & Air',
          'total_nominal': 50000,
          'persentase': 62.5,
        },
      ],
      'items_dengan_bahan': [
        {
          'kategori_id': 'stok-gudang',
          'nama_kategori': 'Belanja Stok Bahan (Gudang)',
          'total_nominal': 564000,
          'persentase': 87.58,
        },
        {
          'kategori_id': 'kp-1',
          'nama_kategori': 'Listrik & Air',
          'total_nominal': 50000,
          'persentase': 7.76,
        },
      ],
    };
  }

  if (path.contains('/reporting/hpp-menu')) {
    return {
      'total_menu': 2,
      'total_menu_beresep': 2,
      'total_menu_tanpa_resep': 0,
      'rata_rata_margin_persen': 60.6,
      'jumlah_menu_margin_tipis': 0,
      'items': [
        {
          'menu_id': 'mn-1',
          'kode_menu': 'MNM03',
          'nama_menu': 'Americano',
          'kategori_nama': 'Minuman',
          'area_produksi': 'bar',
          'status_aktif': true,
          'harga_jual': 8000,
          'hpp_saat_ini': 3880,
          'laba_kotor': 4120,
          'margin_persen': 51.5,
          'hpp_terjual_rata_rata': 3600,
          'selisih_hpp_vs_rata_terjual': 280,
          'qty_terjual': 4,
          'punya_resep': true,
          'resep_items': [
            {
              'bahan_id': 'b-1',
              'nama_bahan': 'Bean',
              'satuan': 'gr',
              'area': 'bar',
              'jumlah_terpakai': 18,
              'harga_rata_rata': 200,
              'subtotal_hpp': 3600,
              'persentase_kontribusi': 92.8,
            },
            {
              'bahan_id': 'b-cup',
              'nama_bahan': 'Cup',
              'satuan': 'pcs',
              'area': 'bar',
              'jumlah_terpakai': 1,
              'harga_rata_rata': 280,
              'subtotal_hpp': 280,
              'persentase_kontribusi': 7.2,
            },
          ],
        },
        {
          'menu_id': 'mn-2',
          'kode_menu': 'MKN01',
          'nama_menu': 'Nasi Goreng',
          'kategori_nama': 'Makanan',
          'area_produksi': 'kitchen',
          'status_aktif': true,
          'harga_jual': 25000,
          'hpp_saat_ini': 7575,
          'laba_kotor': 17425,
          'margin_persen': 69.7,
          'qty_terjual': 0,
          'punya_resep': true,
          'resep_items': [],
        },
      ],
      'bahan_monitor': [
        {
          'bahan_id': 'b-1',
          'nama_bahan': 'Bean',
          'satuan': 'gr',
          'area': 'bar',
          'harga_rata_rata': 200,
          'harga_beli_terakhir': 220,
          'selisih_terakhir_vs_avg': 20,
          'tanggal_beli_terakhir': today,
          'jumlah_menu_terkait': 12,
        },
        {
          'bahan_id': 'b-kitchen-1',
          'nama_bahan': 'Beras Putih',
          'satuan': 'gram',
          'area': 'kitchen',
          'harga_rata_rata': 14.5,
          'harga_beli_terakhir': 14.0,
          'selisih_terakhir_vs_avg': -0.5,
          'tanggal_beli_terakhir': today,
          'jumlah_menu_terkait': 3,
        },
      ],
    };
  }

  if (path.contains('/stok/barang-masuk') && method == 'GET') {
    return {
      'total_transaksi': 1,
      'total_item_masuk': 3,
      'total_nilai_pembelian': 664000,
      'items': [
        {
          'id': 'bm-1',
          'waktu': '${today}T08:30:00',
          'karyawan_id': 'usr-1',
          'nama_karyawan': 'Frans Admin',
          'catatan': 'Restock simulasi harga bar & kitchen',
          'jumlah_item': 3,
          'total_nilai': 664000,
          'details': [
            {
              'id': 'bmd-1',
              'bahan_id': 'b-uht',
              'nama_bahan': 'UHT',
              'satuan': 'ml',
              'area': 'bar',
              'isi_per_kemasan': 1000,
              'jumlah_kemasan_besar': 10,
              'jumlah_satuan_kecil': 0,
              'total_satuan_kecil': 10000,
              'harga_total': 252000,
              'harga_per_satuan_kecil': 25.2,
              'harga_per_kemasan': 25200,
              'harga_rata_rata_saat_ini': 24.64,
              'selisih_vs_avg': 0.56,
            },
            {
              'id': 'bmd-2',
              'bahan_id': 'b-skm',
              'nama_bahan': 'SKM',
              'satuan': 'gram',
              'area': 'bar',
              'isi_per_kemasan': 1000,
              'jumlah_kemasan_besar': 8,
              'jumlah_satuan_kecil': 0,
              'total_satuan_kecil': 8000,
              'harga_total': 312000,
              'harga_per_satuan_kecil': 39.0,
              'harga_per_kemasan': 39000,
              'harga_rata_rata_saat_ini': 40.09,
              'selisih_vs_avg': -1.09,
            },
            {
              'id': 'bmd-3',
              'bahan_id': 'b-bumbu',
              'nama_bahan': 'Bumbu Kebuli & Samin',
              'satuan': 'gram',
              'area': 'kitchen',
              'isi_per_kemasan': 500,
              'jumlah_kemasan_besar': 2,
              'jumlah_satuan_kecil': 0,
              'total_satuan_kecil': 1000,
              'harga_total': 100000,
              'harga_per_satuan_kecil': 100.0,
              'harga_per_kemasan': 50000,
              'harga_rata_rata_saat_ini': 100.0,
              'selisih_vs_avg': 0.0,
            },
          ],
        },
      ],
    };
  }

  if (path.contains('/reporting/pengeluaran')) {
    return [
      {
        'id': 'pg-1',
        'tipe': 'mendadak',
        'kategori_id': null,
        'nama_pengeluaran': 'Es Batu Tambahan',
        'nama_kategori': 'Es Batu Tambahan',
        'nominal': 30000,
        'tanggal': today,
        'keterangan': '3 kantong es kristal',
      },
      {
        'id': 'pg-2',
        'tipe': 'bulanan',
        'kategori_id': 'kp-1',
        'nama_kategori': 'Listrik Cafe',
        'nominal': 300000,
        'bulan': '2026-11-01',
        'keterangan': 'Tagihan listrik bulanan cafe',
        'pro_rata_harian': 10000,
        'jumlah_hari_bulan': 30,
        'sumber': 'operasional',
        'editable': true,
      },
      {
        'id': 'bm-pg-1',
        'tipe': 'belanja_bahan',
        'kategori_id': 'stok-gudang',
        'nama_kategori': 'Belanja Stok Bahan (Gudang)',
        'nominal': 564000,
        'tanggal': today,
        'keterangan': 'Restock simulasi harga (2 item bahan)',
        'sumber': 'barang_masuk',
        'jumlah_item': 2,
        'editable': false,
      },
    ];
  }

  if (path.contains('/reporting/dashboard-overview')) {
    return {
      'preset': '7_hari',
      'periode_mulai': '2026-11-10',
      'periode_selesai': today,
      'total_penjualan': 4500000,
      'total_hpp_teoritis': 1500000,
      'pengeluaran_bulanan_pro_rata': 350000,
      'pengeluaran_mendadak': 150000,
      'total_pengeluaran': 500000,
      'net_profit': 2500000,
      'jumlah_transaksi': 90,
      'jumlah_transaksi_dibatalkan': 2,
      'total_cash': 2500000,
      'total_qris': 2000000,
      'profit_margin_persen': 55.5,
      'sales_change_persen': 12.0,
      'profit_change_persen': 8.5,
      'granularitas': 'hari',
      'sales_chart': [
        {
          'label': '10 Nov',
          'key': '2026-11-10',
          'penjualan': 600000,
          'net_profit': 350000,
          'transaksi': 12,
        },
        {
          'label': '16 Nov',
          'key': today,
          'penjualan': 750000,
          'net_profit': 420000,
          'transaksi': 15,
        },
      ],
      'behavior_periode_mulai': '2026-10-18',
      'behavior_periode_selesai': today,
      'employee_behavior': [],
    };
  }

  return {};
}

Future<void> _pumpAppScreen(
  WidgetTester tester, {
  required Size size,
  required Widget child,
  String role = 'admin',
  String? divisi,
  ShiftAktif? shiftAktif,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  final List<FlutterErrorDetails> errors = [];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };

  try {
    final auth = _FakeAuthProvider(
      fakeRole: role,
      fakeDivisi: divisi,
      fakeNama: role == 'admin' ? 'Frans Admin' : 'Budi Staff',
    );
    await tester.pumpWidget(
      MultiProvider(
        key: UniqueKey(),
        providers: [
          ChangeNotifierProvider<NotificationProvider>(
            create: (_) => NotificationProvider(),
          ),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => _FakeDashboardProvider(fakeShiftAktif: shiftAktif)
              ..updateAuth(auth),
          ),
          ChangeNotifierProvider<PosProvider>(
            create: (_) => PosProvider()..updateAuth(auth),
          ),
          ChangeNotifierProvider<MasterDataProvider>(
            create: (_) => MasterDataProvider()..updateAuth(auth),
          ),
          ChangeNotifierProvider<AttendanceProvider>(
            create: (_) => AttendanceProvider()..updateAuth(auth),
          ),
          ChangeNotifierProvider<ReportingProvider>(
            create: (_) => ReportingProvider()..updateAuth(auth),
          ),
          ChangeNotifierProvider<KdsProvider>(
            create: (_) => _FakeKdsProvider()..updateAuth(auth),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previousOnError;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  expect(
    errors,
    isEmpty,
    reason: errors.isEmpty ? null : errors.map((e) => e.toString()).join('\n'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues({'jwt_token': 'mock-jwt-token'});
    HttpOverrides.global = _StubHttpOverrides();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => call.method == 'read' ? 'mock-jwt-token' : null,
    );
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('LoginScreen renders without overflow on mobile and desktop',
      (tester) async {
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      child: const LoginScreen(),
    );
    await _pumpAppScreen(
      tester,
      size: const Size(1280, 800),
      child: const LoginScreen(),
    );
  });

  testWidgets('DashboardScreen Kasir & Bar render cleanly on mobile 360x800',
      (tester) async {
    final kasirShift = ShiftAktif(
      id: 'jdw-1',
      shift: 'middle_shift',
      shiftNama: 'Middle Shift',
      areaKerja: 'kasir',
      jamMulai: '12:00',
      jamSelesai: '20:00',
      opnameAwalSubmit: true,
      sudahAbsenMasuk: true,
    );
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'karyawan',
      divisi: 'kasir',
      shiftAktif: kasirShift,
      child: const DashboardScreen(),
    );
    expect(find.text('MIDDLE SHIFT'), findsOneWidget);

    final barShift = ShiftAktif(
      id: 'jdw-2',
      shift: 'shift_2',
      shiftNama: 'Shift 2',
      areaKerja: 'bar',
      jamMulai: '16:00',
      jamSelesai: '23:00',
      opnameAwalSubmit: false,
      sudahAbsenMasuk: true,
    );
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'karyawan',
      divisi: 'bar',
      shiftAktif: barShift,
      child: const DashboardScreen(),
    );
    expect(find.text('SHIFT 2'), findsOneWidget);
  });

  testWidgets('AdminAbsensiScreen & KasirJadwalScreen & KasirAbsensiScreen render without overflow',
      (tester) async {
    for (final sec in [0, 1]) {
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        child: AdminAbsensiScreen(initialSection: sec),
      );
      if (sec == 0) {
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -220));
        await tester.pumpAndSettle();
        final pickBtn = find.text('Pilih Lokasi Lewat Peta');
        expect(pickBtn, findsOneWidget);
        await tester.tap(pickBtn);
        await tester.pumpAndSettle();
        expect(find.text('Pilih Titik Lokasi Cafe di Peta'), findsOneWidget);
        await tester.tap(find.text('Gunakan Lokasi Ini'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await _pumpAppScreen(
        tester,
        size: const Size(1280, 800),
        child: AdminAbsensiScreen(initialSection: sec),
      );
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        role: 'karyawan',
        divisi: 'kasir',
        child: KasirJadwalScreen(initialSection: sec),
      );
    }

    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'karyawan',
      divisi: 'kasir',
      child: const KasirAbsensiScreen(),
    );
  });

  testWidgets('MasterDataScreen all 4 sections render without overflow on 360x800 and 1280x800',
      (tester) async {
    for (final sec in [0, 1, 2, 3]) {
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        child: MasterDataScreen(initialSection: sec),
      );
      await _pumpAppScreen(
        tester,
        size: const Size(1280, 800),
        child: MasterDataScreen(initialSection: sec),
      );
    }
  });

  testWidgets('ReportingScreen all 6 sections render without overflow on 360x800 and 1280x800',
      (tester) async {
    for (final sec in [0, 1, 2, 3, 4, 5]) {
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        child: ReportingScreen(initialSection: sec),
      );
      if (sec == 0) {
        expect(
          find.text('Laporan Keuangan Cafe (Standar Laba Rugi, Arus Kas & Aset)'),
          findsOneWidget,
        );
      }
      if (sec == 1) {
        expect(find.text('Rekap Barang Masuk & Harga'), findsOneWidget);
        expect(find.text('Restock simulasi harga bar & kitchen'), findsOneWidget);
        expect(find.text('Bumbu Kebuli & Samin'), findsOneWidget);
      }
      if (sec == 3) {
        expect(find.text('Nama / Keperluan Pengeluaran'), findsOneWidget);
        expect(find.text('Kategori Pengeluaran'), findsNothing);
        expect(find.text('Es Batu Tambahan'), findsOneWidget);
      }
      if (sec == 5) {
        // Test expand rincian BOM & switch ke Harga AVG Bahan di 360x800
        final lihatBom = find.textContaining('Lihat Rincian BOM');
        if (lihatBom.evaluate().isNotEmpty) {
          await tester.ensureVisible(lihatBom.first);
          await tester.pumpAndSettle();
          await tester.tap(lihatBom.first);
          await tester.pumpAndSettle();
        }
        final avgTab = find.textContaining('Harga AVG Bahan');
        if (avgTab.evaluate().isNotEmpty) {
          await tester.ensureVisible(avgTab.first);
          await tester.pumpAndSettle();
          await tester.tap(avgTab.first);
          await tester.pumpAndSettle();
        }
      }
      await _pumpAppScreen(
        tester,
        size: const Size(1280, 800),
        child: ReportingScreen(initialSection: sec),
      );
    }
  });

  testWidgets('PosScreen, TransaksiScreen, and KdsScreen render without overflow on 360x800 and 1280x800',
      (tester) async {
    final activeKasir = ShiftAktif(
      id: 'jdw-1',
      shift: 'shift_1',
      areaKerja: 'kasir',
      jamMulai: '08:00',
      jamSelesai: '16:00',
      opnameAwalSubmit: true,
      sudahAbsenMasuk: true,
    );

    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'karyawan',
      divisi: 'kasir',
      shiftAktif: activeKasir,
      child: const PosScreen(),
    );
    await _pumpAppScreen(
      tester,
      size: const Size(1280, 800),
      role: 'karyawan',
      divisi: 'kasir',
      shiftAktif: activeKasir,
      child: const PosScreen(),
    );

    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      child: const TransaksiScreen(),
    );
    await _pumpAppScreen(
      tester,
      size: const Size(1280, 800),
      child: const TransaksiScreen(),
    );

    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      child: const KdsScreen(areaProduksi: 'all'),
    );
    await _pumpAppScreen(
      tester,
      size: const Size(1280, 800),
      child: const KdsScreen(areaProduksi: 'all'),
    );
  });

  testWidgets('StokGudangScreen, CatatOpnameScreen, StokOpnameHubScreen render without overflow',
      (tester) async {
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      child: const StokGudangScreen(),
    );
    final rekapBtn = find.text('Rekap Masuk & Harga');
    expect(rekapBtn, findsOneWidget);
    await tester.tap(rekapBtn);
    await tester.pumpAndSettle();
    expect(find.text('Restock simulasi harga bar & kitchen'), findsOneWidget);
    expect(find.text('UHT'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kitchen'));
    await tester.pumpAndSettle();
    expect(find.text('UHT'), findsNothing);
    expect(find.text('Bumbu Kebuli & Samin'), findsOneWidget);

    await _pumpAppScreen(
      tester,
      size: const Size(1280, 800),
      child: const StokGudangScreen(),
    );

    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      child: const CatatOpnameScreen(initialSection: 0),
    );
    await _pumpAppScreen(
      tester,
      size: const Size(1280, 800),
      child: const CatatOpnameScreen(initialSection: 0),
    );

    for (final sec in [0, 1]) {
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        child: StokOpnameHubScreen(initialSection: sec),
      );
      await _pumpAppScreen(
        tester,
        size: const Size(1280, 800),
        child: StokOpnameHubScreen(initialSection: sec),
      );
    }
  });

  testWidgets(
      'CatatOpnameScreen auto-selects Bar/Kitchen without area switcher and scrolls smoothly when keyboard opens on 360x800',
      (tester) async {
    // 1. Admin tetap bisa melihat pemilih Area Operasional
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'admin',
      child: const CatatOpnameScreen(initialSection: 0),
    );
    expect(find.text('Area Operasional:'), findsOneWidget);

    // 2. Karyawan Kitchen: otomatis ke Kitchen tanpa pilihan area & bisa scroll saat keyboard muncul
    final kitchenAuth = _FakeAuthProvider(
      fakeRole: 'karyawan',
      fakeDivisi: 'kitchen',
      fakeNama: 'Kitchen 1',
    );
    final kitchenOnDutyShift = ShiftAktif(
      id: 'jdw-kitchen-1',
      shift: 'shift_1',
      areaKerja: 'kitchen',
      jamMulai: '08:00',
      jamSelesai: '16:00',
      opnameAwalSubmit: false,
      sudahAbsenMasuk: true,
    );
    final errors = <FlutterErrorDetails>[];
    final prevErr = FlutterError.onError;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    FlutterError.onError = (details) => errors.add(details);
    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: kitchenAuth),
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) => _FakeDashboardProvider(fakeShiftAktif: kitchenOnDutyShift)
                ..updateAuth(kitchenAuth),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CatatOpnameScreen(initialSection: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Area Kitchen'), findsOneWidget);
      expect(find.text('Area Operasional:'), findsNothing);
      expect(find.text('Bean'), findsNothing);

      // Saat keyboard terbuka (viewInsets.bottom = 340), harus bisa scroll dari atas sampai item paling bawah & catatan
      final scrollFinder = find.byType(CustomScrollView).first;
      await tester.dragUntilVisible(
        find.text('Beras Putih'),
        scrollFinder,
        const Offset(0, -140),
      );
      await tester.pumpAndSettle();
      expect(find.text('Beras Putih'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Sosis Sapi'),
        scrollFinder,
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sosis Sapi'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('Catatan Opname (Opsional):'),
        scrollFinder,
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      expect(find.text('Catatan Opname (Opsional):'), findsOneWidget);
      expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n'));
    } finally {
      FlutterError.onError = prevErr;
      tester.view.resetViewInsets();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    // 3. Karyawan Bar (on-duty): otomatis ke Bar tanpa pilihan area
    final barOnDutyShift = ShiftAktif(
      id: 'jdw-bar-1',
      shift: 'shift_1',
      areaKerja: 'bar',
      jamMulai: '08:00',
      jamSelesai: '16:00',
      opnameAwalSubmit: false,
      sudahAbsenMasuk: true,
    );
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'karyawan',
      divisi: 'bar',
      shiftAktif: barOnDutyShift,
      child: const CatatOpnameScreen(initialSection: 0),
    );
    expect(find.text('Area Bar'), findsOneWidget);
    expect(find.text('Area Operasional:'), findsNothing);
    expect(find.text('Bean'), findsOneWidget);
    expect(find.text('Beras Putih'), findsNothing);
  });

  testWidgets(
      'Dashboard approval handles 409 Conflict cleanly by removing stale card and showing info SnackBar',
      (tester) async {
    _simulatePendingConflictIzinTelat = true;
    final errors = <FlutterErrorDetails>[];
    final prevErr = FlutterError.onError;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    FlutterError.onError = (details) => errors.add(details);

    try {
      final auth = _FakeAuthProvider(
        fakeRole: 'admin',
        fakeNama: 'Frans Admin',
      );
      final dashProv = DashboardProvider()..updateAuth(auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<DashboardProvider>.value(value: dashProv),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approval Menunggu (1)'), findsOneWidget);
      expect(find.textContaining('Ban bocor'), findsOneWidget);

      final approveBtn = find.byTooltip('Approve').first;
      await tester.ensureVisible(approveBtn);
      await tester.pumpAndSettle();
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Approval Menunggu (0)'), findsOneWidget);
      expect(find.text('Tidak ada approval menunggu'), findsOneWidget);
      expect(find.textContaining('Ban bocor'), findsNothing);
      expect(
        find.text('Pengajuan izin telat ini sudah diproses (bukan pending)'),
        findsOneWidget,
      );
      expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n'));
    } finally {
      _simulatePendingConflictIzinTelat = false;
      FlutterError.onError = prevErr;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets(
      'Pengeluaran Mendadak uses free-text input without Kategori dropdown while Bulanan shows Kategori dropdown',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final prevErr = FlutterError.onError;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    FlutterError.onError = (details) => errors.add(details);

    try {
      final auth = _FakeAuthProvider(
        fakeRole: 'admin',
        fakeNama: 'Frans Admin',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) => _FakeDashboardProvider()..updateAuth(auth),
            ),
            ChangeNotifierProvider<ReportingProvider>(
              create: (_) => ReportingProvider()..updateAuth(auth),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ReportingScreen(initialSection: 3),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nama / Keperluan Pengeluaran'), findsOneWidget);
      expect(find.text('Kategori Pengeluaran'), findsNothing);
      expect(find.text('Es Batu Tambahan'), findsOneWidget);

      final tipeDropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(tipeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(tipeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pengeluaran Bulanan (Pro-Rata Bulanan)').last);
      await tester.pumpAndSettle();

      expect(find.text('Kategori Pengeluaran'), findsOneWidget);
      expect(find.text('Nama / Keperluan Pengeluaran'), findsNothing);
      // Pengeluaran bulanan terkunci otomatis bulan ini (tanpa dropdown Bulan/Tahun)
      expect(find.text('Periode Bulan (Otomatis Bulan Ini)'), findsOneWidget);
      expect(find.text('Maks. 1x / Kategori'), findsOneWidget);
      expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n'));
    } finally {
      FlutterError.onError = prevErr;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets(
      'KdsScreen separates Kitchen and Bar orders and transitions status cleanly on 360x800',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final prevErr = FlutterError.onError;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    FlutterError.onError = (details) => errors.add(details);

    try {
      final auth = _FakeAuthProvider(
        fakeRole: 'admin',
        fakeNama: 'Frans Admin',
      );
      final kdsProv = _FakeKdsProvider()..updateAuth(auth);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) => _FakeDashboardProvider()..updateAuth(auth),
            ),
            ChangeNotifierProvider<KdsProvider>.value(value: kdsProv),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const KdsScreen(areaProduksi: 'kitchen'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kitchen hanya menampilkan item kitchen ('Nasi Goreng Spesial'), bukan item bar
      expect(find.textContaining('Nasi Goreng Spesial'), findsOneWidget);
      expect(find.textContaining('Iced Americano Long Name Variant Check'), findsNothing);

      // Mulai proses item kitchen -> buka dropdown status dan pindah ke tab Diproses
      await tester.tap(find.text('Mulai Proses (Diproses)').first);
      await tester.pumpAndSettle();
      expect(find.text('Menunggu (0)'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      expect(find.text('Diproses (1)').last, findsOneWidget);
      await tester.tap(find.text('Diproses (1)').last);
      await tester.pumpAndSettle();
      expect(find.text('Tandai Selesai'), findsOneWidget);

      // Beralih ke area Bar -> hanya menampilkan item bar ('Iced Americano Long Name Variant Check')
      await tester.tap(find.text('Bar (Minuman)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nasi Goreng Spesial'), findsNothing);
      expect(find.textContaining('Iced Americano Long Name Variant Check'), findsOneWidget);
      expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n'));
    } finally {
      FlutterError.onError = prevErr;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets(
      'PosScreen static QRIS payment requires confirmation checkbox and submits without photo on 360x800',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final prevErr = FlutterError.onError;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    FlutterError.onError = (details) => errors.add(details);

    try {
      final auth = _FakeAuthProvider(
        fakeRole: 'karyawan',
        fakeDivisi: 'kasir',
        fakeNama: 'Dila Kasir',
      );
      final activeKasir = ShiftAktif(
        id: 'jdw-1',
        shift: 'shift_1',
        areaKerja: 'kasir',
        jamMulai: '08:00',
        jamSelesai: '16:00',
        opnameAwalSubmit: true,
        sudahAbsenMasuk: true,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<NotificationProvider>(
              create: (_) => NotificationProvider(),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) => _FakeDashboardProvider(fakeShiftAktif: activeKasir)
                ..updateAuth(auth),
            ),
            ChangeNotifierProvider<PosProvider>(
              create: (_) => PosProvider()..updateAuth(auth),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PosScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tambah item ke keranjang -> buka sheet keranjang -> tekan Bayar
      await tester.tap(find.text('Espresso Latte Signature').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 item'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Bayar'));
      await tester.pumpAndSettle();

      // Pilih QRIS
      await tester.tap(find.text('QRIS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('QRIS Statis Cafe'), findsOneWidget);
      expect(find.text('Dana QRIS sudah masuk & terverifikasi'), findsOneWidget);

      // Sebelum dicentang, tombol Konfirmasi Pembayaran nonaktif
      final submitFinder = find.widgetWithText(ElevatedButton, 'Konfirmasi Pembayaran');
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNull);

      // Centang konfirmasi mutasi -> tombol aktif & submit sukses tanpa foto
      await tester.tap(find.text('Dana QRIS sudah masuk & terverifikasi'));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(submitFinder).onPressed, isNotNull);

      await tester.ensureVisible(submitFinder);
      await tester.pumpAndSettle();
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('TRX-20261118-QRIS1'), findsOneWidget);
      expect(errors, isEmpty, reason: errors.map((e) => e.toString()).join('\n'));
    } finally {
      FlutterError.onError = prevErr;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets(
      'StokOpnameHubScreen displays Shift 1 vs Shift 2 comparison and BOM expected vs actual without overflow on 360x800',
      (tester) async {
    _simulateOpnameHarianSesi = true;
    try {
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        role: 'admin',
        child: const StokOpnameHubScreen(initialSection: 0),
      );
      expect(find.textContaining('Sesi Opname Tercatat (1 Sesi)'), findsOneWidget);
      expect(find.textContaining('Selisih Opname Shift 1 vs Shift 2'), findsOneWidget);

      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        role: 'admin',
        child: const StokOpnameHubScreen(initialSection: 1),
      );
      expect(find.textContaining('Selisih Opname Shift 1 vs Shift 2'), findsOneWidget);
      expect(find.textContaining('Selisih S1→S2: -20 ml'), findsOneWidget);
      expect(find.textContaining('Ekspektasi'), findsWidgets);
      expect(find.textContaining('955 ml'), findsWidgets);
      expect(find.textContaining('900 ml'), findsWidgets);
      expect(find.textContaining('-55 ml'), findsWidgets);
    } finally {
      _simulateOpnameHarianSesi = false;
    }
  });

  testWidgets(
      'KasirJadwalScreen displays incoming Tukar Shift target confirmation card with Setujui & Tolak buttons on 360x800',
      (tester) async {
    _simulateIncomingTukarShift = true;
    try {
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        role: 'karyawan',
        divisi: 'bar',
        child: const KasirJadwalScreen(initialSection: 1),
      );
      expect(find.text('Permintaan Tukar Shift Masuk (1)'), findsOneWidget);
      expect(find.text('Setujui Tukar'), findsOneWidget);
      expect(find.text('Tolak'), findsOneWidget);
    } finally {
      _simulateIncomingTukarShift = false;
    }
  });

  testWidgets(
      'Off-shift & unclocked-in karyawan are locked out of POS, KDS, Stok Gudang, Opname, and Rekap Stok on 360x800',
      (tester) async {
    // 1. Off-shift / libur (shiftAktif = null)
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'karyawan',
      divisi: 'kasir',
      shiftAktif: null,
      child: const DashboardScreen(),
    );
    expect(find.text('Off-Shift / Tidak Ada Jadwal Hari Ini'), findsOneWidget);
    expect(find.text('POS Kasir (Terkunci)'), findsOneWidget);

    for (final lockedPage in const [
      PosScreen(),
      KdsScreen(areaProduksi: 'bar'),
      StokGudangScreen(),
      CatatOpnameScreen(initialSection: 0),
      StokOpnameHubScreen(initialSection: 0),
    ]) {
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        role: 'karyawan',
        divisi: 'kasir',
        shiftAktif: null,
        child: lockedPage,
      );
      expect(find.text('Sedang Off-Shift / Libur'), findsOneWidget);
    }

    // 2. Punya shift tapi BELUM Absen Masuk -> semua fitur operasional tetap terkunci
    final belumAbsenShift = ShiftAktif(
      id: 'jdw-no-abs',
      shift: 'shift_1',
      shiftNama: 'Shift 1',
      areaKerja: 'bar',
      jamMulai: '08:00',
      jamSelesai: '16:00',
      opnameAwalSubmit: false,
      sudahAbsenMasuk: false,
    );
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'karyawan',
      divisi: 'bar',
      shiftAktif: belumAbsenShift,
      child: const StokOpnameHubScreen(initialSection: 0),
    );
    expect(find.text('Absen Masuk Diperlukan'), findsOneWidget);
    expect(find.text('Buka Absensi Masuk'), findsOneWidget);
  });

  testWidgets(
      'Sub-menu screens omit redundant header dropdowns and Dashboard mobile AppBar hosts Refresh button on 360x800',
      (tester) async {
    for (final screen in const [
      StokOpnameHubScreen(initialSection: 0),
      ReportingScreen(initialSection: 0),
      MasterDataScreen(initialSection: 0),
      AdminJadwalScreen(initialSection: 0),
      AdminAbsensiScreen(initialSection: 1),
      KasirJadwalScreen(initialSection: 0),
      CatatOpnameScreen(initialSection: 0),
    ]) {
      await _pumpAppScreen(
        tester,
        size: const Size(360, 800),
        role: 'admin',
        child: screen,
      );
      expect(
        find.byType(DropdownButton<int>),
        findsNothing,
        reason: 'Redundant submenu DropdownButton<int> found in $screen',
      );
    }

    // Mobile Dashboard AppBar hosts the centralized Refresh icon button next to Notifications
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'admin',
      child: const DashboardScreen(),
    );
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets(
      'StokGudangScreen displays AVG price, valuation, and expandable per-BOM cost on 360x800',
      (tester) async {
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'admin',
      child: const StokGudangScreen(),
    );

    expect(find.text('Estimasi Nilai Persediaan Gudang (AVG)'), findsOneWidget);
    expect(find.text('AVG / gram'), findsOneWidget);
    expect(find.text('Rp 150'), findsOneWidget);
    expect(find.text('AVG / kemasan'), findsOneWidget);
    expect(find.textContaining('150.000'), findsOneWidget);
    expect(find.text('Nilai Stok'), findsOneWidget);
    expect(find.text('Biaya & Takaran Per BOM (2 Menu)'), findsOneWidget);

    await tester.tap(find.text('Biaya & Takaran Per BOM (2 Menu)'));
    await tester.pumpAndSettle();

    expect(find.text('MNM01 · Espresso Latte Signature'), findsOneWidget);
    expect(find.textContaining('Takaran: 18 gram / porsi'), findsOneWidget);
    expect(find.text('Rp 2.700'), findsOneWidget);
    expect(find.text('MNM02 · Americano Iced'), findsOneWidget);
  });

  testWidgets(
      'ReportingScreen Laporan Absensi displays per-employee late minutes, alpha count, and expandable shift logs on 360x800',
      (tester) async {
    await _pumpAppScreen(
      tester,
      size: const Size(360, 800),
      role: 'admin',
      child: const ReportingScreen(initialSection: 2),
    );

    expect(find.text('Rekap Kehadiran Per Karyawan'), findsOneWidget);
    expect(find.text('Bar 1'), findsOneWidget);
    expect(find.text('Dila Kasir'), findsOneWidget);
    expect(find.text('35 mnt (2×)'), findsOneWidget);
    expect(find.text('1 kali'), findsWidgets);
    expect(find.text('Rincian Log Shift (2 Shift)'), findsOneWidget);

    await tester.ensureVisible(find.text('Rincian Log Shift (2 Shift)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rincian Log Shift (2 Shift)'));
    await tester.pumpAndSettle();

    expect(find.text('Telat +20 mnt'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
  });
}

