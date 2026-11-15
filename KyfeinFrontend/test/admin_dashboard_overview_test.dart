import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kyfein_frontend/core/theme/app_theme.dart';
import 'package:kyfein_frontend/features/auth/providers/auth_provider.dart';
import 'package:kyfein_frontend/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:kyfein_frontend/features/dashboard/providers/dashboard_provider.dart';
import 'package:kyfein_frontend/features/notifications/providers/notification_provider.dart';

class _FakeAuthProvider extends AuthProvider {
  @override
  String? get role => 'admin';

  @override
  String? get nama => 'Frans';

  @override
  String? get token => 'fake-token';

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;
}

class _FakeDashboardProvider extends DashboardProvider {
  String _preset = 'hari_ini';
  String _mode = 'auto';
  String? lastAppliedPreset;
  String? lastChartMode;

  final DashboardOverviewData _sampleOverview = DashboardOverviewData(
    filter: 'hari_ini',
    periodeMulai: '2026-11-14',
    periodeSelesai: '2026-11-14',
    chartGranularity: 'hari',
    chartPeriodeMulai: '2026-11-08',
    chartPeriodeSelesai: '2026-11-14',
    periodePerilakuMulai: '2026-10-16',
    periodePerilakuSelesai: '2026-11-14',
    totalPenjualan: 1250000,
    totalHppTeoritis: 450000,
    pengeluaranBulananProRata: 100000,
    pengeluaranMendadak: 50000,
    totalPengeluaran: 150000,
    netProfit: 650000,
    marginProfitPersen: 52.0,
    jumlahTransaksi: 25,
    jumlahTransaksiDibatalkan: 1,
    rataRataTransaksi: 50000,
    totalCash: 750000,
    totalQris: 500000,
    perubahanPenjualanPersen: 15.4,
    grafikPenjualan: [
      SalesChartPoint(
        label: '8 Nov',
        tanggal: '2026-11-08',
        totalPenjualan: 120000,
        totalHpp: 50000,
        totalPengeluaran: 100000,
        netProfit: -30000,
        jumlahTransaksi: 3,
      ),
      SalesChartPoint(
        label: '9 Nov',
        tanggal: '2026-11-09',
        totalPenjualan: 800000,
        totalHpp: 300000,
        totalPengeluaran: 100000,
        netProfit: 400000,
        jumlahTransaksi: 16,
      ),
      SalesChartPoint(
        label: '10 Nov',
        tanggal: '2026-11-10',
        totalPenjualan: 950000,
        totalHpp: 350000,
        totalPengeluaran: 100000,
        netProfit: 500000,
        jumlahTransaksi: 19,
      ),
      SalesChartPoint(
        label: '11 Nov',
        tanggal: '2026-11-11',
        totalPenjualan: 700000,
        totalHpp: 250000,
        totalPengeluaran: 100000,
        netProfit: 350000,
        jumlahTransaksi: 14,
      ),
      SalesChartPoint(
        label: '12 Nov',
        tanggal: '2026-11-12',
        totalPenjualan: 1100000,
        totalHpp: 400000,
        totalPengeluaran: 100000,
        netProfit: 600000,
        jumlahTransaksi: 22,
      ),
      SalesChartPoint(
        label: '13 Nov',
        tanggal: '2026-11-13',
        totalPenjualan: 1080000,
        totalHpp: 390000,
        totalPengeluaran: 100000,
        netProfit: 590000,
        jumlahTransaksi: 21,
      ),
      SalesChartPoint(
        label: '14 Nov',
        tanggal: '2026-11-14',
        totalPenjualan: 1250000,
        totalHpp: 450000,
        totalPengeluaran: 150000,
        netProfit: 650000,
        jumlahTransaksi: 25,
      ),
    ],
    ringkasanDisiplinTotalHadir: 18,
    ringkasanDisiplinTepatWaktu: 13,
    ringkasanDisiplinTelat: 5,
    ringkasanDisiplinAlpha: 1,
    tingkatKetepatanTimPersen: 72.2,
    perilakuKaryawan: [
      EmployeeBehaviorItem(
        karyawanId: 'k-1',
        nama: 'Riko',
        divisi: 'kasir',
        totalShiftTerjadwal: 8,
        totalHadir: 7,
        tepatWaktuCount: 3,
        telatCount: 4,
        totalMenitTelat: 85,
        rataMenitTelat: 21.3,
        izinTelatCount: 1,
        izinTidakMasukCount: 0,
        lupaAbsenPulangCount: 1,
        tanpaKeteranganCount: 1,
        tukarShiftCount: 0,
        tingkatKetepatanPersen: 42.9,
        kategoriPerilaku: 'perlu_perhatian',
        ringkasanPerilaku:
            'Sering telat (4x · 85 mnt) · Tanpa keterangan 1x · Lupa absen pulang 1x',
      ),
      EmployeeBehaviorItem(
        karyawanId: 'k-2',
        nama: 'Dila',
        divisi: 'bar',
        totalShiftTerjadwal: 6,
        totalHadir: 6,
        tepatWaktuCount: 5,
        telatCount: 1,
        totalMenitTelat: 12,
        rataMenitTelat: 12.0,
        izinTelatCount: 0,
        izinTidakMasukCount: 0,
        lupaAbsenPulangCount: 0,
        tanpaKeteranganCount: 0,
        tukarShiftCount: 1,
        tingkatKetepatanPersen: 83.3,
        kategoriPerilaku: 'waspada',
        ringkasanPerilaku: 'Telat 1x (12 mnt)',
      ),
      EmployeeBehaviorItem(
        karyawanId: 'k-3',
        nama: 'Siti',
        divisi: 'kitchen',
        totalShiftTerjadwal: 5,
        totalHadir: 5,
        tepatWaktuCount: 5,
        telatCount: 0,
        totalMenitTelat: 0,
        rataMenitTelat: 0,
        izinTelatCount: 0,
        izinTidakMasukCount: 0,
        lupaAbsenPulangCount: 0,
        tanpaKeteranganCount: 0,
        tukarShiftCount: 0,
        tingkatKetepatanPersen: 100.0,
        kategoriPerilaku: 'disiplin',
        ringkasanPerilaku: 'Disiplin (5/5 shift tepat waktu)',
      ),
    ],
  );

  @override
  bool get isLoading => false;

  @override
  bool get isOverviewLoading => false;

  @override
  String get selectedPreset => _preset;

  @override
  String get chartMode => _mode;

  @override
  DashboardOverviewData? get overview => _sampleOverview;

  @override
  AdminSummary? get adminSummary => AdminSummary(
        totalPenjualan: _sampleOverview.totalPenjualan,
        profitHarian: _sampleOverview.netProfit,
        jumlahTransaksi: _sampleOverview.jumlahTransaksi,
        pendingApprovals: 0,
      );

  @override
  Future<void> refresh() async {}

  @override
  Future<void> applyOverviewPreset(String preset) async {
    _preset = preset;
    lastAppliedPreset = preset;
    notifyListeners();
  }

  @override
  Future<void> setChartMode(String mode) async {
    _mode = mode;
    lastChartMode = mode;
    notifyListeners();
  }
}

void main() {
  Widget buildApp(_FakeDashboardProvider fakeDash) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => _FakeAuthProvider(),
        ),
        ChangeNotifierProvider<DashboardProvider>.value(value: fakeDash),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DashboardScreen(),
      ),
    );
  }

  testWidgets(
      'Admin Dashboard renders sales summary, profit, interactive chart, and employee behavior cleanly on 360x800',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeDash = _FakeDashboardProvider();
    await tester.pumpWidget(buildApp(fakeDash));
    await tester.pumpAndSettle();

    // 1. Verifikasi KPI Penjualan, Keuntungan Bersih, HPP & Biaya, Transaksi
    expect(find.text('Total Penjualan'), findsOneWidget);
    expect(find.text('Keuntungan Bersih'), findsOneWidget);
    expect(find.text('HPP & Biaya Ops'), findsOneWidget);
    expect(find.text('Transaksi Selesai'), findsOneWidget);
    expect(find.textContaining('+15.4% vs sblmnya'), findsOneWidget);
    expect(find.textContaining('Margin 52.0%'), findsOneWidget);

    // 2. Scroll ke Grafik Penjualan & Profit agar terlihat utuh di tengah layar
    final scrollViewFinder = find.byType(CustomScrollView);
    await tester.drag(scrollViewFinder, const Offset(0, -320));
    await tester.pumpAndSettle();
    expect(find.text('Grafik Penjualan & Profit'), findsOneWidget);

    await tester.tap(find.text('Profit'));
    await tester.pumpAndSettle();
    expect(find.text('Rugi / Minus (-)'), findsOneWidget);

    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();

    // 3. Test filter Per Jam Hari Ini & preset 7 Hari
    await tester.tap(find.text('Per Jam Hari Ini'));
    await tester.pumpAndSettle();
    expect(fakeDash.lastChartMode, 'jam');

    await tester.drag(scrollViewFinder, const Offset(0, 320));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 Hari'));
    await tester.pumpAndSettle();
    expect(fakeDash.lastAppliedPreset, '7_hari');

    // 4. Scroll ke Perilaku & Kedisiplinan Karyawan dan cek kategori + filter
    await tester.drag(scrollViewFinder, const Offset(0, -550));
    await tester.pumpAndSettle();
    await tester.drag(scrollViewFinder, const Offset(0, -450));
    await tester.pumpAndSettle();

    expect(find.text('Perilaku & Kedisiplinan Karyawan'), findsOneWidget);
    expect(find.text('Sering Telat'), findsOneWidget);
    expect(find.text('Riko'), findsOneWidget);
    expect(find.text('Telat 4x (85 mnt)'), findsOneWidget);
    expect(find.text('Lupa pulang 1x'), findsOneWidget);
    expect(find.text('Disiplin'), findsOneWidget);

    await tester.tap(find.text('Perlu Perhatian (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Riko'), findsOneWidget);
    expect(find.text('Siti'), findsNothing);

    await tester.ensureVisible(find.text('Disiplin (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disiplin (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Siti'), findsOneWidget);
    expect(find.text('Riko'), findsNothing);
  });

  testWidgets(
      'Admin Dashboard renders side-by-side analytics without overflow on desktop 1280x800',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeDash = _FakeDashboardProvider();
    await tester.pumpWidget(buildApp(fakeDash));
    await tester.pumpAndSettle();

    expect(find.text('Grafik Penjualan & Profit'), findsOneWidget);
    expect(find.text('Perilaku & Kedisiplinan Karyawan'), findsOneWidget);
    expect(find.text('Sering Telat'), findsOneWidget);
  });
}
