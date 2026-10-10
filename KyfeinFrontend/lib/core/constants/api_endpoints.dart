// ── API Configuration ────────────────────────────────────────────────────────
// 
// FOR WEB (flutter run -d web-server):
//   Uses localhost — backend must be running on the same machine.
//
// FOR ANDROID APK (physical device or emulator):
//   Change [androidBaseUrl] to your backend server's local IP on the cafe WiFi.
//   Find it by running `ipconfig` on the server machine → IPv4 Address.
//   Example: 'http://192.168.1.50:8000/api/v1'
//
// FOR ANDROID EMULATOR (on dev machine, same as web):
//   Use 'http://10.0.2.2:8000/api/v1' — emulator maps 10.0.2.2 to host's localhost.
//
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Base API URL & WebSocket URL (Supports environment overrides via --dart-define)
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://kasir.cafe-kyfein.com/api/v1');
  static const String _envWsUrl = String.fromEnvironment('WS_BASE_URL', defaultValue: 'wss://kasir.cafe-kyfein.com/api/v1/kds/ws');

  // ── Change these to match your deployment ────────────────────────────────
  
  /// Backend running on the same machine as Flutter web server (localhost).
  static const String _webBaseUrl = 'http://127.0.0.1:8000/api/v1';
  static const String _webWsUrl   = 'ws://127.0.0.1:8000/ws';

  /// Backend IP reachable from Android device on the cafe's local WiFi.
  /// Run `ipconfig` on the server machine and use its IPv4 address.
  static const String _androidBaseUrl = 'http://192.168.90.177:8000/api/v1';
  static const String _androidWsUrl   = 'ws://192.168.90.177:8000/ws';

  // ── Resolved at runtime ───────────────────────────────────────────────────
  static const bool _useLocalConfig = true; // Set to true for local testing

  static String get baseUrl {
    if (_useLocalConfig) {
      return kIsWeb ? _webBaseUrl : _androidBaseUrl;
    }
    return _envBaseUrl;
  }

  static String get wsUrl {
    if (_useLocalConfig) {
      return kIsWeb ? _webWsUrl : _androidWsUrl;
    }
    return _envWsUrl;
  }
}

class ApiEndpoints {
  // ── Auth ──────────────────────────────────────────────
  static String get login => '${ApiConfig.baseUrl}/auth/login';
  static String get googleLogin => '${ApiConfig.baseUrl}/auth/google';
  static String get me    => '${ApiConfig.baseUrl}/auth/me';
  static String get fcmToken => '${ApiConfig.baseUrl}/auth/fcm-token';

  // ── Karyawan ──────────────────────────────────────────
  static String get karyawan => '${ApiConfig.baseUrl}/karyawan';
  static String karyawanById(String id) => '${ApiConfig.baseUrl}/karyawan/$id';

  // ── Master Data ───────────────────────────────────────
  static String get kategoriMenu => '${ApiConfig.baseUrl}/master/kategori-menu';
  static String get menu         => '${ApiConfig.baseUrl}/master/menu';
  static String get bahan        => '${ApiConfig.baseUrl}/master/bahan';

  // ── Transaksi POS ─────────────────────────────────────
  static String get transaksi        => '${ApiConfig.baseUrl}/transaksi';
  static String get laporanShiftAktif => '${ApiConfig.baseUrl}/transaksi/shift-aktif/laporan';
  static String voidTransaksi(String id) => '${ApiConfig.baseUrl}/transaksi/$id/void';

  // ── Stok Opname ───────────────────────────────────────
  static String get opname       => '${ApiConfig.baseUrl}/stok/opname';
  static String get barangKeluar => '${ApiConfig.baseUrl}/stok/barang-keluar';
  static String get stokMenipis  => '${ApiConfig.baseUrl}/stok/menipis';

  // ── Absensi ───────────────────────────────────────────
  static String get absenMasuk => '${ApiConfig.baseUrl}/absensi/masuk';
  static String absenPulang(String id) => '${ApiConfig.baseUrl}/absensi/$id/pulang';

  // ── Jadwal & Shift ────────────────────────────────────
  static String get jadwal             => '${ApiConfig.baseUrl}/jadwal';
  static String get shiftAktif         => '${ApiConfig.baseUrl}/jadwal/shift-aktif';
  static String get tukarShift         => '${ApiConfig.baseUrl}/jadwal/tukar-shift';
  static String get jadwalUntukTukar   => '${ApiConfig.baseUrl}/jadwal/tukar-shift/jadwal-tersedia';
  static String get requestOff         => '${ApiConfig.baseUrl}/jadwal/request-off';

  // ── Approvals ─────────────────────────────────────────
  static String get pendingApprovals => '${ApiConfig.baseUrl}/jadwal/approvals/pending';
  static String approveSwapShift(String id) => '${ApiConfig.baseUrl}/jadwal/tukar-shift/$id/approve';
  static String rejectSwapShift(String id)  => '${ApiConfig.baseUrl}/jadwal/tukar-shift/$id/reject';
  static String approveIzin(String id) => '${ApiConfig.baseUrl}/jadwal/izin/$id/approve';
  static String rejectIzin(String id)  => '${ApiConfig.baseUrl}/jadwal/izin/$id/reject';

  // ── KDS ───────────────────────────────────────────────
  static String kdsOrders(String area) => '${ApiConfig.baseUrl}/kds/orders/$area';
  static String kdsWs(String area)     => '${ApiConfig.wsUrl}/$area';

  // ── Reporting ─────────────────────────────────────────
  static String get profitHarian => '${ApiConfig.baseUrl}/reporting/profit-harian';
  static String get pengeluaran  => '${ApiConfig.baseUrl}/reporting/pengeluaran';

  // ── Manajemen Role (admin) ────────────────────────────
  static String get manajemenRole => '${ApiConfig.baseUrl}/karyawan/manajemen-role';
  static String promoteKaryawan(String id)   => '${ApiConfig.baseUrl}/karyawan/$id/promote';
  static String nonaktifkanAkun(String id)   => '${ApiConfig.baseUrl}/karyawan/$id/nonaktifkan';
}
