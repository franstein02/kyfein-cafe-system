import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kyfein_frontend/core/theme/app_theme.dart';
import 'package:kyfein_frontend/features/attendance/presentation/screens/admin_jadwal_screen.dart';
import 'package:kyfein_frontend/features/attendance/providers/attendance_provider.dart';
import 'package:kyfein_frontend/features/auth/providers/auth_provider.dart';

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

class _FakeAttendanceProvider extends AttendanceProvider {
  _FakeAttendanceProvider({
    List<Map<String, dynamic>>? jadwal,
    List<Map<String, dynamic>>? requestOff,
    List<Map<String, dynamic>>? initialTemplates,
  })  : _jadwalList = jadwal ?? [],
        _requestOffList = requestOff ?? [],
        _templates = initialTemplates ??
            [
              {
                'id': 'tpl-1',
                'shift': 'shift_1',
                'nama': 'Shift 1',
                'jam_mulai': '07:30:00',
                'jam_selesai': '15:30:00',
                'updated_at': '2026-11-14T10:00:00',
              },
              {
                'id': 'tpl-2',
                'shift': 'shift_2',
                'nama': 'Shift 2',
                'jam_mulai': '15:30:00',
                'jam_selesai': '23:00:00',
                'updated_at': '2026-11-14T10:00:00',
              },
            ];

  final List<Map<String, dynamic>> _jadwalList;
  final List<Map<String, dynamic>> _requestOffList;
  final List<Map<String, dynamic>> _templates;

  String? lastUpdatedShift;
  String? lastUpdatedNama;
  String? lastUpdatedMulai;
  String? lastUpdatedSelesai;

  @override
  List<Map<String, dynamic>> get karyawan => [
        {
          'id': 'k-1',
          'nama': 'Dila',
          'email': 'dila@kyfein.com',
          'role': 'karyawan',
          'divisi': 'kasir',
          'status_aktif': true,
        },
        {
          'id': 'k-2',
          'nama': 'Budi',
          'email': 'budi@kyfein.com',
          'role': 'karyawan',
          'divisi': 'bar',
          'status_aktif': true,
        },
      ];

  @override
  List<Map<String, dynamic>> get shiftTemplates => _templates;

  @override
  List<Map<String, dynamic>> get allJadwal => _jadwalList;

  @override
  List<Map<String, dynamic>> get jadwalMendatang => _jadwalList;

  @override
  List<Map<String, dynamic>> get requestOff => _requestOffList;

  @override
  List<Map<String, dynamic>> get tukarShift => [];

  @override
  List<Map<String, dynamic>> get izinTelat => [];

  @override
  List<Map<String, dynamic>> get izinTidakMasuk => [];

  @override
  String? get error => null;

  @override
  Future<void> loadAdminJadwalData() async {
    notifyListeners();
  }

  @override
  Future<http.Response> createShiftTemplate({
    required String nama,
    String? shift,
    required String jamMulai,
    required String jamSelesai,
  }) async {
    final slug = (shift ?? nama.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'))
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final created = {
      'id': 'tpl-${_templates.length + 1}',
      'shift': slug,
      'nama': nama,
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'updated_at': '2026-11-16T12:00:00',
    };
    _templates.add(created);
    _templates.sort((a, b) =>
        (a['jam_mulai'] ?? '').toString().compareTo((b['jam_mulai'] ?? '').toString()));
    notifyListeners();
    return http.Response(jsonEncode(created), 201);
  }

  @override
  Future<http.Response> updateShiftTemplate({
    required String shift,
    String? nama,
    required String jamMulai,
    required String jamSelesai,
  }) async {
    lastUpdatedShift = shift;
    lastUpdatedNama = nama;
    lastUpdatedMulai = jamMulai;
    lastUpdatedSelesai = jamSelesai;
    final idx = _templates.indexWhere((t) => t['shift'] == shift);
    final existingNama = idx >= 0 ? (_templates[idx]['nama'] ?? shift) : shift;
    final updated = {
      'id': idx >= 0 ? _templates[idx]['id'] : 'tpl-new',
      'shift': shift,
      'nama': nama ?? existingNama,
      'jam_mulai': jamMulai,
      'jam_selesai': jamSelesai,
      'updated_at': '2026-11-14T12:00:00',
    };
    if (idx >= 0) {
      _templates[idx] = updated;
    } else {
      _templates.add(updated);
    }
    notifyListeners();
    return http.Response(jsonEncode(updated), 200);
  }

  @override
  Future<http.Response> deleteShiftTemplate(String shift) async {
    _templates.removeWhere((t) => t['shift'] == shift);
    notifyListeners();
    return http.Response(jsonEncode({'status': 'deleted', 'shift': shift}), 200);
  }
}

void main() {
  testWidgets(
      'AdminJadwalScreen reads ShiftTemplate from DB, switches shifts dynamically, and saves template without overflow on 360x800',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeAtt = _FakeAttendanceProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _FakeAuthProvider(),
          ),
          ChangeNotifierProvider<AttendanceProvider>.value(value: fakeAtt),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminJadwalScreen(initialSection: 0),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Form Atur Jadwal Shift menampilkan jam dari template DB (07:30 - 15:30)
    expect(find.text('Shift 1 (07:30 – 15:30)'), findsOneWidget);
    expect(find.text('Mengikuti template DB (07:30 – 15:30)'), findsOneWidget);

    // 2. Pilih Shift 2 -> form otomatis update ke template Shift 2 (15:30 - 23:00)
    await tester.tap(find.text('Shift 1 (07:30 – 15:30)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift 2 (15:30 – 23:00)').last);
    await tester.pumpAndSettle();
    expect(find.text('Mengikuti template DB (15:30 – 23:00)'), findsOneWidget);

    // 3. Klik tombol Atur Template -> masuk ke menu Template Jam Kerja Shift
    await tester.tap(find.text('Atur Template'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Template Shift Baru'), findsOneWidget);
    expect(find.text('Shift 1'), findsOneWidget);
    expect(find.text('Shift 2'), findsOneWidget);
    expect(find.text('Aktif di DB: 07:30 – 15:30'), findsOneWidget);
    expect(find.text('Aktif di DB: 15:30 – 23:00'), findsOneWidget);

    // 4. Tambah template baru (Middle Shift) melalui dialog
    await tester.tap(find.text('Tambah Template Shift Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Template Shift'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Middle Shift');
    await tester.tap(find.text('Tambah Template'));
    await tester.pumpAndSettle();

    expect(find.text('Template Middle Shift berhasil ditambahkan'), findsOneWidget);
    expect(find.text('Middle Shift'), findsOneWidget);
    expect(find.text('Aktif di DB: 12:00 – 20:00'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(AdminJadwalScreen)))
        .clearSnackBars();
    await tester.pumpAndSettle();

    // 5. Ubah nama Middle Shift -> Shift 3
    final editMidBtn = find.byIcon(Icons.edit_outlined).at(1);
    await tester.ensureVisible(editMidBtn);
    await tester.pumpAndSettle();
    await tester.tap(editMidBtn);
    await tester.pumpAndSettle();
    expect(find.text('Ubah Nama Template Shift'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Shift 3');
    await tester.tap(find.text('Simpan Nama'));
    await tester.pumpAndSettle();

    expect(find.text('Nama template diubah menjadi Shift 3'), findsOneWidget);
    expect(fakeAtt.lastUpdatedNama, 'Shift 3');
    expect(find.text('Shift 3'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(AdminJadwalScreen)))
        .clearSnackBars();
    await tester.pumpAndSettle();

    // 6. Kembali ke tab Atur Jadwal Shift -> Shift 3 muncul di dropdown & auto-isi jam 12:00 - 20:00
    final backToJadwalBtn = find.text('Kembali ke Atur Jadwal Shift');
    await tester.ensureVisible(backToJadwalBtn);
    await tester.pumpAndSettle();
    await tester.tap(backToJadwalBtn);
    await tester.pumpAndSettle();

    final shiftDropdownFinder = find.text('Shift 2 (15:30 – 23:00)');
    await tester.ensureVisible(shiftDropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(shiftDropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift 3 (12:00 – 20:00)').last);
    await tester.pumpAndSettle();
    expect(find.text('Mengikuti template DB (12:00 – 20:00)'), findsOneWidget);

    // 7. Kembali ke Atur Template, simpan Shift 1, lalu hapus Shift 3
    await tester.ensureVisible(find.text('Atur Template'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atur Template'));
    await tester.pumpAndSettle();

    final saveFirstBtn = find.text('Simpan Template').first;
    await tester.ensureVisible(saveFirstBtn);
    await tester.pumpAndSettle();
    await tester.tap(saveFirstBtn);
    await tester.pumpAndSettle();

    expect(fakeAtt.lastUpdatedShift, 'shift_1');
    expect(fakeAtt.lastUpdatedMulai, '07:30:00');
    expect(fakeAtt.lastUpdatedSelesai, '15:30:00');
    expect(
      find.text('Template Shift 1 berhasil disimpan ke database'),
      findsOneWidget,
    );
    ScaffoldMessenger.of(tester.element(find.byType(AdminJadwalScreen)))
        .clearSnackBars();
    await tester.pumpAndSettle();

    // Hapus Shift 3 (posisi index 1 karena diurut jam_mulai: 07:30, 12:00, 15:30)
    final delMidBtn = find.byIcon(Icons.delete_outline_rounded).at(1);
    await tester.ensureVisible(delMidBtn);
    await tester.pumpAndSettle();
    await tester.tap(delMidBtn);
    await tester.pumpAndSettle();
    expect(find.text('Hapus Template Shift?'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Template Shift 3 berhasil dihapus'), findsOneWidget);
    expect(fakeAtt.shiftTemplates.length, 2);
  });

  testWidgets(
      'Custom schedule calendar marks complete (green) and partial (amber) dates and updates form indicator cleanly on 360x800',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final partialDate = today.add(const Duration(days: 1));
    final completeDate = today.add(const Duration(days: 2));
    final offDate = today.add(const Duration(days: 3));

    final partialStr = DateFormat('yyyy-MM-dd').format(partialDate);
    final completeStr = DateFormat('yyyy-MM-dd').format(completeDate);
    final offStr = DateFormat('yyyy-MM-dd').format(offDate);

    final fakeAtt = _FakeAttendanceProvider(
      jadwal: [
        {
          'id': 'j-1',
          'karyawan_id': 'k-1',
          'tanggal': partialStr,
          'shift': 'shift_1',
          'area_kerja': 'kasir',
          'jam_mulai': '07:30:00',
          'jam_selesai': '15:30:00',
        },
        {
          'id': 'j-2',
          'karyawan_id': 'k-1',
          'tanggal': completeStr,
          'shift': 'shift_1',
          'area_kerja': 'kasir',
          'jam_mulai': '07:30:00',
          'jam_selesai': '15:30:00',
        },
        {
          'id': 'j-3',
          'karyawan_id': 'k-2',
          'tanggal': completeStr,
          'shift': 'shift_2',
          'area_kerja': 'bar',
          'jam_mulai': '15:30:00',
          'jam_selesai': '23:00:00',
        },
      ],
      requestOff: [
        {
          'id': 'off-1',
          'karyawan_id': 'k-1',
          'tanggal': offStr,
          'alasan': 'Acara keluarga',
        },
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _FakeAuthProvider(),
          ),
          ChangeNotifierProvider<AttendanceProvider>.value(value: fakeAtt),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminJadwalScreen(initialSection: 0),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Awalnya tanggal = hari ini (kosong)
    expect(find.text('Belum ada jadwal shift pada tanggal ini'), findsOneWidget);

    // Buka kalender kustom dari picker Tanggal Shift
    await tester.tap(find.textContaining('Hari Ini · '));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Pilih Tanggal Shift'), findsOneWidget);
    expect(find.text('Semua Terjadwal'), findsOneWidget);
    expect(find.text('Sebagian Terjadwal'), findsOneWidget);
    expect(find.text('Request Off'), findsOneWidget);

    var displayedMonth = DateTime(today.year, today.month, 1);

    // Navigasi jika partialDate pindah bulan (mis. akhir bulan)
    if (partialDate.month != displayedMonth.month) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      displayedMonth = DateTime(partialDate.year, partialDate.month, 1);
    }

    // Ketuk tanggal partial -> muncul status sebagian (1/2 Karyawan) & Shift 2 Belum dijadwalkan
    await tester.tap(find.descendant(
      of: find.byType(Dialog),
      matching: find.text('${partialDate.day}'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sebagian (1/2 Karyawan)'), findsOneWidget);
    expect(find.text('Belum dijadwalkan'), findsOneWidget);

    // Navigasi jika completeDate berada di bulan berikutnya
    if (completeDate.month != displayedMonth.month) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      displayedMonth = DateTime(completeDate.year, completeDate.month, 1);
    }

    // Pastikan sel tanggal lengkap memiliki warna hijau sebelum dipilih (#DCFCE7)
    final completeDayFinder = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('${completeDate.day}'),
    );
    final completeCellBeforeTap = tester.widget<Container>(
      find
          .ancestor(of: completeDayFinder, matching: find.byType(Container))
          .first,
    );
    final decoBefore = completeCellBeforeTap.decoration! as BoxDecoration;
    expect(decoBefore.color, const Color(0xFFDCFCE7));

    // Ketuk tanggal lengkap -> status menjadi Semua Karyawan Lengkap (2/2) + warna hijau terpilih (#15803D)
    await tester.tap(completeDayFinder);
    await tester.pumpAndSettle();

    expect(find.text('Semua Karyawan Lengkap (2/2)'), findsOneWidget);
    expect(find.textContaining('Dila (Kasir 07:30–15:30)'), findsOneWidget);
    expect(find.textContaining('Budi (Bar 15:30–23:00)'), findsOneWidget);

    final completeCellAfterTap = tester.widget<Container>(
      find
          .ancestor(of: completeDayFinder, matching: find.byType(Container))
          .first,
    );
    final decoAfter = completeCellAfterTap.decoration! as BoxDecoration;
    expect(decoAfter.color, const Color(0xFF15803D));

    // Pilih tanggal & verifikasi banner pada form berubah jadi lengkap (hijau)
    await tester.tap(find.text('Pilih Tanggal'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(
      find.text('Semua 2 karyawan sudah mendapat shift (2 jadwal)'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Dynamic 3-template calendar marks complete (green) when all employees covered even if Middle is unused, and partial (amber) when someone unscheduled on 360x800',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final partialOneOfTwoDate = today.add(const Duration(days: 1));
    final allCoveredWithoutMiddleDate = today.add(const Duration(days: 2));
    final oneOffMiddleDate = today.add(const Duration(days: 3));

    final partialStr = DateFormat('yyyy-MM-dd').format(partialOneOfTwoDate);
    final fullNoMiddleStr =
        DateFormat('yyyy-MM-dd').format(allCoveredWithoutMiddleDate);
    final offMiddleStr = DateFormat('yyyy-MM-dd').format(oneOffMiddleDate);

    final fakeAtt = _FakeAttendanceProvider(
      initialTemplates: [
        {
          'id': 'tpl-1',
          'shift': 'shift_1',
          'nama': 'Shift 1',
          'jam_mulai': '07:00:00',
          'jam_selesai': '15:00:00',
        },
        {
          'id': 'tpl-mid',
          'shift': 'middle',
          'nama': 'Middle',
          'jam_mulai': '08:00:00',
          'jam_selesai': '23:00:00',
        },
        {
          'id': 'tpl-2',
          'shift': 'shift_2',
          'nama': 'Shift 2',
          'jam_mulai': '15:00:00',
          'jam_selesai': '23:00:00',
        },
      ],
      jadwal: [
        // Hari +1: baru 1 dari 2 karyawan terjadwal -> Kuning (Sebagian)
        {
          'id': 'j-a1',
          'karyawan_id': 'k-1',
          'tanggal': partialStr,
          'shift': 'shift_1',
          'area_kerja': 'kasir',
          'jam_mulai': '07:00:00',
          'jam_selesai': '15:00:00',
        },
        // Hari +2: kedua karyawan sudah mendapat shift (Middle tidak terpakai) -> Tetap Hijau!
        {
          'id': 'j-b1',
          'karyawan_id': 'k-1',
          'tanggal': fullNoMiddleStr,
          'shift': 'shift_1',
          'area_kerja': 'kasir',
          'jam_mulai': '07:00:00',
          'jam_selesai': '15:00:00',
        },
        {
          'id': 'j-b2',
          'karyawan_id': 'k-2',
          'tanggal': fullNoMiddleStr,
          'shift': 'shift_2',
          'area_kerja': 'bar',
          'jam_mulai': '15:00:00',
          'jam_selesai': '23:00:00',
        },
        // Hari +3: k-1 request off, k-2 masuk Middle -> Hijau + ada Request Off!
        {
          'id': 'j-c1',
          'karyawan_id': 'k-2',
          'tanggal': offMiddleStr,
          'shift': 'middle',
          'area_kerja': 'kasir',
          'jam_mulai': '08:00:00',
          'jam_selesai': '23:00:00',
        },
      ],
      requestOff: [
        {
          'id': 'off-mid-1',
          'karyawan_id': 'k-1',
          'tanggal': offMiddleStr,
          'alasan': 'Request libur',
        },
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _FakeAuthProvider(),
          ),
          ChangeNotifierProvider<AttendanceProvider>.value(value: fakeAtt),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminJadwalScreen(initialSection: 0),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Hari Ini · '));
    await tester.pumpAndSettle();

    expect(find.text('Semua Terjadwal'), findsOneWidget);
    expect(find.text('Sebagian Terjadwal'), findsOneWidget);

    var displayedMonth = DateTime(today.year, today.month, 1);
    if (partialOneOfTwoDate.month != displayedMonth.month) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      displayedMonth =
          DateTime(partialOneOfTwoDate.year, partialOneOfTwoDate.month, 1);
    }

    // Tanggal +1: baru 1/2 karyawan terjadwal -> Amber
    final partialFinder = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('${partialOneOfTwoDate.day}'),
    );
    await tester.tap(partialFinder);
    await tester.pumpAndSettle();
    expect(find.text('Sebagian (1/2 Karyawan)'), findsOneWidget);

    if (allCoveredWithoutMiddleDate.month != displayedMonth.month) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      displayedMonth = DateTime(allCoveredWithoutMiddleDate.year,
          allCoveredWithoutMiddleDate.month, 1);
    }

    // Tanggal +2: kedua karyawan sudah dapat shift meski Middle kosong -> warna Hijau (#DCFCE7)
    final fullNoMidFinder = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('${allCoveredWithoutMiddleDate.day}'),
    );
    final cellNoMidBefore = tester.widget<Container>(
      find
          .ancestor(of: fullNoMidFinder, matching: find.byType(Container))
          .first,
    );
    expect((cellNoMidBefore.decoration! as BoxDecoration).color,
        const Color(0xFFDCFCE7));

    await tester.tap(fullNoMidFinder);
    await tester.pumpAndSettle();
    expect(find.text('Semua Karyawan Lengkap (2/2)'), findsOneWidget);

    if (oneOffMiddleDate.month != displayedMonth.month) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
    }

    // Tanggal +3: 1 Request Off + 1 Middle -> Hijau
    await tester.tap(find.descendant(
      of: find.byType(Dialog),
      matching: find.text('${oneOffMiddleDate.day}'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Semua Karyawan Lengkap (2/2)'), findsOneWidget);

    await tester.tap(find.text('Pilih Tanggal'));
    await tester.pumpAndSettle();

    expect(
      find.text('Semua 2 karyawan lengkap (1 jadwal, 1 request off)'),
      findsOneWidget,
    );
  });
}

