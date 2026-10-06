class ApiEndpoints {
  // Base API URL & WebSocket URL (Supports environment overrides via --dart-define)
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://kasir.cafe-kyfein.com/api/v1');
  static const String wsUrl = String.fromEnvironment('WS_BASE_URL', defaultValue: 'wss://kasir.cafe-kyfein.com/api/v1/kds/ws');

  // Auth
  static const String login = '$baseUrl/auth/login';
  static const String me = '$baseUrl/auth/me';

  // Karyawan
  static const String karyawan = '$baseUrl/karyawan';

  // Master Data
  static const String kategoriMenu = '$baseUrl/master/kategori-menu';
  static const String menu = '$baseUrl/master/menu';
  static const String bahan = '$baseUrl/master/bahan';

  // Transaksi POS
  static const String transaksi = '$baseUrl/transaksi';
  static const String laporanShiftAktif = '$baseUrl/transaksi/shift-aktif/laporan';
  static String voidTransaksi(String id) => '$baseUrl/transaksi/$id/void';

  // Stok Opname
  static const String opname = '$baseUrl/stok/opname';
  static const String barangKeluar = '$baseUrl/stok/barang-keluar';

  // Absensi
  static const String absenMasuk = '$baseUrl/absensi/masuk';
  static String absenPulang(String id) => '$baseUrl/absensi/$id/pulang';

  // Jadwal
  static const String jadwal = '$baseUrl/jadwal';
  static const String tukarShift = '$baseUrl/jadwal/tukar-shift';
  static const String jadwalUntukTukar = '$baseUrl/jadwal/tukar-shift/jadwal-tersedia';
  static const String requestOff = '$baseUrl/jadwal/request-off';

  // Layar KDS
  static String kdsOrders(String area) => '$baseUrl/kds/orders/$area';
  static String kdsWs(String area) => '$wsUrl/$area';

  // Reporting
  static const String profitHarian = '$baseUrl/reporting/profit-harian';
  static const String pengeluaran = '$baseUrl/reporting/pengeluaran';
}
