import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kyfein_frontend/core/theme/app_theme.dart';
import 'package:kyfein_frontend/features/auth/providers/auth_provider.dart';
import 'package:kyfein_frontend/features/dashboard/providers/dashboard_provider.dart';
import 'package:kyfein_frontend/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:kyfein_frontend/features/master_data/providers/master_data_provider.dart';
import 'package:kyfein_frontend/features/master_data/presentation/widgets/kelola_karyawan_view.dart';
import 'package:kyfein_frontend/features/notifications/providers/notification_provider.dart';

class _FakeAuthProvider extends AuthProvider {
  final String _mockRole;
  final String? _mockDivisi;
  final String _mockNama;

  _FakeAuthProvider({
    required String role,
    String? divisi,
    required String nama,
  })  : _mockRole = role,
        _mockDivisi = divisi,
        _mockNama = nama;

  @override
  String? get role => _mockRole;

  @override
  String? get divisi => _mockDivisi;

  @override
  String get divisiEfektif {
    if (_mockDivisi == 'bar' || _mockDivisi == 'kitchen' || _mockDivisi == 'kasir') {
      return _mockDivisi!;
    }
    return 'kasir';
  }

  @override
  String? get nama => _mockNama;

  @override
  String? get token => null;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;
}

class _FakeDashboardProvider extends DashboardProvider {
  @override
  bool get isLoading => false;

  @override
  Future<void> refresh() async {}
}

class _FakeMasterDataProvider extends MasterDataProvider {
  final List<MasterKaryawan> _fakeList = [
    MasterKaryawan(
      id: '1',
      nama: 'Dila',
      email: 'fransciescos@gmail.com',
      nomorHp: '081299900001',
      role: 'karyawan',
      divisi: 'kasir',
      statusAktif: true,
    ),
    MasterKaryawan(
      id: '2',
      nama: 'Siti (Kitchen)',
      email: 'akunsuppdl@gmail.com',
      nomorHp: '081299900003',
      role: 'karyawan',
      divisi: 'kitchen',
      statusAktif: true,
    ),
  ];

  @override
  bool get isLoading => false;

  @override
  List<MasterKaryawan> get karyawanList => _fakeList;

  @override
  Future<void> loadData() async {
    notifyListeners();
  }

  @override
  Future<String?> createKaryawan(Map<String, dynamic> data) async {
    _fakeList.add(
      MasterKaryawan(
        id: '3',
        nama: data['nama'].toString(),
        email: data['email'].toString(),
        nomorHp: data['nomor_hp']?.toString(),
        role: 'karyawan',
        divisi: data['divisi']?.toString() ?? 'kasir',
        statusAktif: true,
      ),
    );
    notifyListeners();
    return null;
  }

  @override
  Future<String?> updateKaryawan(String id, Map<String, dynamic> data) async {
    final idx = _fakeList.indexWhere((k) => k.id == id);
    if (idx != -1) {
      final old = _fakeList[idx];
      _fakeList[idx] = MasterKaryawan(
        id: old.id,
        nama: (data['nama'] ?? old.nama).toString(),
        email: (data['email'] ?? old.email).toString(),
        nomorHp: data.containsKey('nomor_hp') ? data['nomor_hp']?.toString() : old.nomorHp,
        role: old.role,
        divisi: (data['divisi'] ?? old.divisi)?.toString(),
        statusAktif: (data['status_aktif'] as bool?) ?? old.statusAktif,
      );
    }
    notifyListeners();
    return null;
  }
}

void main() {
  testWidgets('KelolaKaryawanView renders on 360x800 without overflow and dialogs dispose safely',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeProv = _FakeMasterDataProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _FakeAuthProvider(role: 'admin', nama: 'Frans'),
          ),
          ChangeNotifierProvider<MasterDataProvider>.value(value: fakeProv),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: KelolaKaryawanView(showHeader: true),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Open Add Karyawan dialog and test Batal cancellation
    await tester.tap(find.text('Tambah Karyawan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nama Lengkap'), 'Batal User');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Batal User'), findsNothing);

    // 2. Open Add Karyawan dialog, test inline validation, then create Kitchen employee
    await tester.tap(find.text('Tambah Karyawan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat Akun'));
    await tester.pumpAndSettle();
    expect(find.text('Nama lengkap wajib diisi'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Kitchen').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nama Lengkap'), 'Chef Rina');
    await tester.enterText(find.widgetWithText(TextField, 'Email Login'), 'rina@kyfein.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password (Min. 8 karakter)'), 'password123');
    await tester.tap(find.text('Buat Akun'));
    await tester.pumpAndSettle();

    expect(fakeProv.karyawanList.any((k) => k.nama == 'Chef Rina' && k.divisi == 'kitchen'), isTrue);
    await tester.scrollUntilVisible(
      find.text('Chef Rina'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chef Rina'), findsOneWidget);

    // 3. Edit existing karyawan and change divisi -> bar
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bar / Barista').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
  });

  testWidgets('Admin mobile drawer navigates to Kelola Karyawan and opens/closes dialog cleanly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeProv = _FakeMasterDataProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _FakeAuthProvider(role: 'admin', nama: 'Frans'),
          ),
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => _FakeDashboardProvider(),
          ),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider<MasterDataProvider>.value(value: fakeProv),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Pastikan Kelola Karyawan tidak lagi muncul di luar sub-menu Master Data
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Kelola Karyawan'),
      ),
      findsNothing,
    );

    // Expand Master Data lalu pilih sub-menu Kelola Karyawan
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Master Data'),
      ),
    );
    await tester.pumpAndSettle();

    final subMenuKelola = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Kelola Karyawan'),
    );
    expect(subMenuKelola, findsOneWidget);
    await tester.tap(subMenuKelola);
    await tester.pumpAndSettle();

    expect(find.text('Tambah Akun Karyawan Baru'), findsOneWidget);
    await tester.tap(find.text('Tambah Akun Karyawan Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Karyawan Baru'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();
  });

  testWidgets('Kitchen dashboard hides POS menus and shows Kitchen focus',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _FakeAuthProvider(role: 'karyawan', divisi: 'kitchen', nama: 'Siti'),
          ),
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => _FakeDashboardProvider(),
          ),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
          ChangeNotifierProvider<MasterDataProvider>(
            create: (_) => _FakeMasterDataProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('KITCHEN'), findsOneWidget);
    expect(find.text('Ruang Kerja Kitchen'), findsOneWidget);
    expect(find.text('Laporan Shift Aktif'), findsNothing);
    expect(find.text('Buka POS'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Layar Pesanan KDS'), findsOneWidget);
    expect(find.text('Stok & Opname Kitchen'), findsOneWidget);
    expect(find.text('Jadwal & Absensi'), findsOneWidget);
    expect(find.text('Kasir POS'), findsNothing);
  });
}
