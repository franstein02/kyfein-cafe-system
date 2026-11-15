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
  })  : _jadwalList = jadwal ?? [],
        _requestOffList = requestOff ?? [];

  final List<Map<String, dynamic>> _jadwalList;
  final List<Map<String, dynamic>> _requestOffList;

  final List<Map<String, dynamic>> _templates = [
    {
      'id': 'tpl-1',
      'shift': 'shift_1',
      'jam_mulai': '07:30:00',
      'jam_selesai': '15:30:00',
      'updated_at': '2026-11-14T10:00:00',
    },
    {
      'id': 'tpl-2',
      'shift': 'shift_2',
      'jam_mulai': '15:30:00',
      'jam_selesai': '23:00:00',
      'updated_at': '2026-11-14T10:00:00',
    },
  ];

  String? lastUpdatedShift;
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
  Future<http.Response> updateShiftTemplate({
    required String shift,
    required String jamMulai,
    required String jamSelesai,
  }) async {
    lastUpdatedShift = shift;
    lastUpdatedMulai = jamMulai;
    lastUpdatedSelesai = jamSelesai;
    final idx = _templates.indexWhere((t) => t['shift'] == shift);
    final updated = {
      'id': idx >= 0 ? _templates[idx]['id'] : 'tpl-new',
      'shift': shift,
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

    expect(find.text('Template Jam Kerja Shift'), findsOneWidget);
    expect(find.text('Shift 1 (Pagi / Siang)'), findsOneWidget);
    expect(find.text('Shift 2 (Sore / Malam)'), findsOneWidget);
    expect(find.text('Aktif di DB: 07:30 – 15:30'), findsOneWidget);
    expect(find.text('Aktif di DB: 15:30 – 23:00'), findsOneWidget);

    // 4. Simpan Template Shift 1
    await tester.tap(find.text('Simpan Template').first);
    await tester.pumpAndSettle();

    expect(fakeAtt.lastUpdatedShift, 'shift_1');
    expect(fakeAtt.lastUpdatedMulai, '07:30:00');
    expect(fakeAtt.lastUpdatedSelesai, '15:30:00');
    expect(
      find.text('Template Shift 1 berhasil disimpan ke database'),
      findsOneWidget,
    );
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
    expect(find.text('Shift Lengkap (1 & 2)'), findsOneWidget);
    expect(find.text('Sebagian (1 Shift)'), findsOneWidget);
    expect(find.text('Request Off'), findsOneWidget);

    var displayedMonth = DateTime(today.year, today.month, 1);

    // Navigasi jika partialDate pindah bulan (mis. akhir bulan)
    if (partialDate.month != displayedMonth.month) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      displayedMonth = DateTime(partialDate.year, partialDate.month, 1);
    }

    // Ketuk tanggal partial -> muncul status sebagian & Shift 2 Belum dijadwalkan
    await tester.tap(find.descendant(
      of: find.byType(Dialog),
      matching: find.text('${partialDate.day}'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sebagian (1 Shift)'), findsNWidgets(2));
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

    // Ketuk tanggal lengkap -> status menjadi Shift 1 & 2 Lengkap + warna hijau terpilih (#15803D)
    await tester.tap(completeDayFinder);
    await tester.pumpAndSettle();

    expect(find.text('Shift 1 & 2 Lengkap'), findsOneWidget);
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
      find.text('Shift 1 & Shift 2 sudah lengkap (2 jadwal)'),
      findsOneWidget,
    );
  });
}

