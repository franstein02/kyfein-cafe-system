import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kyfein_frontend/core/constants/api_endpoints.dart';
import 'package:kyfein_frontend/core/widgets/page_refresh_scope.dart';
import 'package:kyfein_frontend/features/attendance/providers/attendance_provider.dart';
import 'package:kyfein_frontend/features/auth/providers/auth_provider.dart';
import 'package:kyfein_frontend/features/dashboard/providers/dashboard_provider.dart';

const _brown = Color(0xFF1B4332);
const _cream = Color(0xFFF6F8F6);
const _textDim = Color(0xFF7A7A7A);

enum _DateScheduleStatus { none, partial, complete }

_DateScheduleStatus _computeScheduleStatus(
  List<Map<String, dynamic>> entries, [
  List<String> expectedShifts = const ['shift_1', 'shift_2'],
  Set<String> activeKaryawanIds = const {},
  List<Map<String, dynamic>> requestOff = const [],
]) {
  if (entries.isEmpty) return _DateScheduleStatus.none;
  if (activeKaryawanIds.isNotEmpty) {
    final scheduledIds = entries
        .map((j) => (j['karyawan_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final offIds = requestOff
        .map((r) => (r['karyawan_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final coveredIds = {...scheduledIds, ...offIds};
    return activeKaryawanIds.every(coveredIds.contains)
        ? _DateScheduleStatus.complete
        : _DateScheduleStatus.partial;
  }
  final shifts = entries
      .map((j) => (j['shift'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toSet();
  final requiredShifts =
      expectedShifts.isNotEmpty ? expectedShifts : const ['shift_1', 'shift_2'];
  if (requiredShifts.every(shifts.contains)) {
    return _DateScheduleStatus.complete;
  }
  return _DateScheduleStatus.partial;
}

String _defaultShiftTitleFromKey(String shiftKey) {
  final parts = shiftKey
      .split('_')
      .where((p) => p.trim().isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
      .toList();
  return parts.isEmpty ? 'Shift' : parts.join(' ');
}

class AdminJadwalScreen extends StatefulWidget {
  final int initialSection;

  const AdminJadwalScreen({super.key, this.initialSection = 0});

  @override
  State<AdminJadwalScreen> createState() => _AdminJadwalScreenState();
}

class _AdminJadwalScreenState extends State<AdminJadwalScreen> {
  late int _currentSection;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  List<Map<String, dynamic>> _karyawan = [];
  List<Map<String, dynamic>> _shiftTemplates = [];
  List<Map<String, dynamic>> _jadwal = [];
  List<Map<String, dynamic>> _allJadwal = [];
  List<Map<String, dynamic>> _requestOff = [];
  List<Map<String, dynamic>> _tukar = [];
  List<Map<String, dynamic>> _izinTelat = [];
  List<Map<String, dynamic>> _izinTidakMasuk = [];

  // Form Penugasan Shift
  String? _karyawanId;
  DateTime _tanggal = DateTime.now();
  String _shift = 'shift_1';
  String _area = 'kasir';
  TimeOfDay _jamMulai = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _jamSelesai = const TimeOfDay(hour: 16, minute: 0);
  bool _jamCustomEdited = false;

  // Draft editor Template Shift
  String? _savingTemplateShift;
  final Map<String, TimeOfDay> _tplMulaiDraft = {
    'shift_1': const TimeOfDay(hour: 8, minute: 0),
    'shift_2': const TimeOfDay(hour: 16, minute: 0),
  };
  final Map<String, TimeOfDay> _tplSelesaiDraft = {
    'shift_1': const TimeOfDay(hour: 16, minute: 0),
    'shift_2': const TimeOfDay(hour: 23, minute: 0),
  };

  // Filter Jadwal Mendatang per Hari (null = Semua Hari, 'yyyy-MM-dd' = per hari)
  String? _filterTanggalJadwal =
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<String, String> get _headers => context.read<AuthProvider>().authHeaders;

  String get _tanggalStr => DateFormat('yyyy-MM-dd').format(_tanggal);

  List<Map<String, dynamic>> get _requestOffPadaTanggal => _requestOff
      .where((r) => (r['tanggal'] ?? '').toString() == _tanggalStr)
      .toList();

  bool _isKaryawanRequestOff(String? kId, String tglStr) {
    if (kId == null) return false;
    return _requestOff.any(
      (r) =>
          r['karyawan_id'].toString() == kId &&
          (r['tanggal'] ?? '').toString() == tglStr,
    );
  }

  bool _isKaryawanSudahDijadwalkan(String? kId, String tglStr) {
    if (kId == null) return false;
    return _allJadwal.any(
      (j) =>
          j['karyawan_id'].toString() == kId &&
          (j['tanggal'] ?? '').toString() == tglStr,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAll();
    });
  }

  @override
  void didUpdateWidget(covariant AdminJadwalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() {
        _currentSection = widget.initialSection.clamp(0, 2);
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _fmtTodShort(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTimeOfDay(dynamic val, TimeOfDay fallback) {
    final s = (val ?? '').toString().trim();
    final parts = s.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return fallback;
  }

  List<Map<String, dynamic>> get _effectiveTemplates {
    if (_shiftTemplates.isNotEmpty) return _shiftTemplates;
    return const [
      {
        'id': 'default_shift_1',
        'shift': 'shift_1',
        'nama': 'Shift 1',
        'jam_mulai': '08:00:00',
        'jam_selesai': '16:00:00',
      },
      {
        'id': 'default_shift_2',
        'shift': 'shift_2',
        'nama': 'Shift 2',
        'jam_mulai': '16:00:00',
        'jam_selesai': '23:00:00',
      },
    ];
  }

  List<String> get _expectedShiftKeys => _effectiveTemplates
      .map((t) => (t['shift'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toList();

  Set<String> get _activeKaryawanIds => _karyawan
      .where((k) =>
          k['status_aktif'] != false &&
          (k['role'] ?? 'karyawan').toString() == 'karyawan')
      .map((k) => (k['id'] ?? '').toString())
      .where((id) => id.isNotEmpty)
      .toSet();

  String _shiftDisplayName(String shiftKey) {
    for (final t in _effectiveTemplates) {
      if ((t['shift'] ?? '').toString() == shiftKey) {
        final nama = (t['nama'] ?? '').toString().trim();
        if (nama.isNotEmpty) return nama;
      }
    }
    return _defaultShiftTitleFromKey(shiftKey);
  }

  (TimeOfDay, TimeOfDay) _templateTimesFor(String shiftKey) {
    final defMulai = shiftKey == 'shift_2'
        ? const TimeOfDay(hour: 16, minute: 0)
        : const TimeOfDay(hour: 8, minute: 0);
    final defSelesai = shiftKey == 'shift_2'
        ? const TimeOfDay(hour: 23, minute: 0)
        : const TimeOfDay(hour: 16, minute: 0);
    final match = _effectiveTemplates
        .where((t) => (t['shift'] ?? '').toString() == shiftKey)
        .toList();
    if (match.isEmpty) return (defMulai, defSelesai);
    final row = match.first;
    return (
      _parseTimeOfDay(row['jam_mulai'], defMulai),
      _parseTimeOfDay(row['jam_selesai'], defSelesai),
    );
  }

  String _shiftOptionLabel(String shiftKey) {
    final title = _shiftDisplayName(shiftKey);
    final (mulai, selesai) = _templateTimesFor(shiftKey);
    return '$title (${_fmtTodShort(mulai)} – ${_fmtTodShort(selesai)})';
  }

  String _short(dynamic t) {
    final s = (t ?? '').toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  String _formatHariTanggal(String tglStr, {bool short = false}) {
    final dt = DateTime.tryParse(tglStr);
    if (dt == null) return tglStr;
    const hariFull = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const hariShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const bulanShort = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final h = short ? hariShort[dt.weekday - 1] : hariFull[dt.weekday - 1];
    final b = bulanShort[dt.month - 1];
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (short) {
      return tglStr == todayStr ? 'Hari Ini ($h, ${dt.day} $b)' : '$h, ${dt.day} $b';
    }
    return tglStr == todayStr
        ? 'Hari Ini · $h, ${dt.day} $b ${dt.year}'
        : '$h, ${dt.day} $b ${dt.year}';
  }

  List<String> get _pilihanTanggalFilter {
    final setTanggal = <String>{};
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      setTanggal.add(
          DateFormat('yyyy-MM-dd').format(now.add(Duration(days: i))));
    }
    for (final j in _jadwal) {
      final t = (j['tanggal'] ?? '').toString();
      if (t.isNotEmpty) setTanggal.add(t);
    }
    if (_filterTanggalJadwal != null && _filterTanggalJadwal!.isNotEmpty) {
      setTanggal.add(_filterTanggalJadwal!);
    }
    final list = setTanggal.toList()..sort();
    return list;
  }

  int _jumlahJadwalPadaTanggal(String tglStr) =>
      _jadwal.where((j) => (j['tanggal'] ?? '').toString() == tglStr).length;

  String _namaKaryawan(dynamic id) {
    final k = _karyawan.firstWhere(
      (e) => e['id'].toString() == id.toString(),
      orElse: () => {},
    );
    return (k['nama'] ?? k['nama_lengkap'] ?? k['email'] ?? 'Karyawan')
        .toString();
  }

  String _infoShiftById(dynamic shiftId) {
    final s = _allJadwal.firstWhere(
      (j) => j['id'].toString() == shiftId.toString(),
      orElse: () => {},
    );
    if (s.isEmpty) return 'Shift ID: $shiftId';
    final tgl = s['tanggal'] ?? '-';
    final sh = (s['shift'] ?? '').toString().replaceAll('_', ' ').toUpperCase();
    final area = (s['area_kerja'] ?? '').toString().toUpperCase();
    return '$tgl · $sh ($area) · ${_short(s['jam_mulai'])}–${_short(s['jam_selesai'])}';
  }

  String _errorMsg(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      final detail = d['detail'];
      if (detail is String) return detail;
      return 'Gagal (${r.statusCode})';
    } catch (_) {
      return 'Gagal (${r.statusCode})';
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Load data ──────────────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final att = context.read<AttendanceProvider>();
    await att.loadAdminJadwalData();
    if (!mounted) return;
    setState(() {
      _karyawan = att.karyawan;
      _shiftTemplates = att.shiftTemplates;
      _allJadwal = att.allJadwal;
      _jadwal = att.jadwalMendatang;
      _requestOff = att.requestOff;
      _tukar = att.tukarShift;
      _izinTelat = att.izinTelat;
      _izinTidakMasuk = att.izinTidakMasuk;
      _loadError = att.error;

      _syncTemplateDrafts();

      if (!_jamCustomEdited) {
        final (m, s) = _templateTimesFor(_shift);
        _jamMulai = m;
        _jamSelesai = s;
      }

      if (_filterTanggalJadwal != null &&
          _jadwal.isNotEmpty &&
          !_jadwal.any(
              (j) => (j['tanggal'] ?? '').toString() == _filterTanggalJadwal)) {
        _filterTanggalJadwal = _jadwal.first['tanggal'].toString();
      }
      _loading = false;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _simpan() async {
    if (_karyawanId == null) {
      _snack('Pilih karyawan dulu');
      return;
    }
    if (_isKaryawanRequestOff(_karyawanId, _tanggalStr)) {
      _snack(
          'Tidak dapat menyimpan: ${_namaKaryawan(_karyawanId)} sedang mengajukan Request Off pada tanggal $_tanggalStr');
      return;
    }
    final mulai = _jamMulai.hour * 60 + _jamMulai.minute;
    final selesai = _jamSelesai.hour * 60 + _jamSelesai.minute;
    if (selesai <= mulai) {
      _snack('Jam selesai harus setelah jam mulai');
      return;
    }

    setState(() => _saving = true);
    try {
      final resp = await http
          .post(
            Uri.parse('${ApiEndpoints.jadwal}/'),
            headers: _headers,
            body: jsonEncode({
              'karyawan_id': _karyawanId,
              'tanggal': _tanggalStr,
              'shift': _shift,
              'area_kerja': _area,
              'jam_mulai': _fmtTime(_jamMulai),
              'jam_selesai': _fmtTime(_jamSelesai),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _filterTanggalJadwal = _tanggalStr;
        _jamCustomEdited = false;
        _snack('Jadwal berhasil disimpan');
        await _loadAll();
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _prosesApproval({
    required String url,
    required String status,
    required String approvedMsg,
    required String rejectedMsg,
  }) async {
    try {
      final resp = await http
          .put(
            Uri.parse(url),
            headers: _headers,
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _snack(status == 'disetujui' ? approvedMsg : rejectedMsg);
        await _loadAll();
        if (mounted) {
          try {
            await context.read<DashboardProvider>().refresh();
          } catch (_) {}
        }
      } else if (resp.statusCode == 409 || resp.statusCode == 404) {
        _snack(_errorMsg(resp));
        await _loadAll();
        if (mounted) {
          try {
            await context.read<DashboardProvider>().refresh();
          } catch (_) {}
        }
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    }
  }

  Future<void> _prosesTukar(String id, String status) => _prosesApproval(
        url: ApiEndpoints.approvalTukarShift(id),
        status: status,
        approvedMsg: 'Tukar shift disetujui',
        rejectedMsg: 'Tukar shift ditolak',
      );

  Future<void> _prosesIzinTelat(String id, String status) => _prosesApproval(
        url: ApiEndpoints.approvalIzinTelat(id),
        status: status,
        approvedMsg: 'Izin terlambat disetujui',
        rejectedMsg: 'Izin terlambat ditolak',
      );

  Future<void> _prosesIzinTidakMasuk(String id, String status) => _prosesApproval(
        url: ApiEndpoints.approvalIzinTidakMasuk(id),
        status: status,
        approvedMsg: 'Izin tidak masuk disetujui',
        rejectedMsg: 'Izin tidak masuk ditolak',
      );

  Future<void> _hapusRequestOff(String id) async {
    try {
      final resp = await http
          .delete(
            Uri.parse('${ApiEndpoints.requestOff}/$id'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _snack('Request off dihapus');
        await _loadAll();
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    }
  }

  Future<void> _lihatFotoBukti(String? fotoId) async {
    if (fotoId == null || fotoId.isEmpty) {
      _snack('Tidak ada lampiran foto');
      return;
    }
    try {
      final resp = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/foto/$fotoId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && mounted) {
        final Uint8List bytes = resp.bodyBytes;
        await showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('Foto Bukti Izin',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        _snack('Gagal memuat foto (${resp.statusCode})');
      }
    } catch (_) {
      _snack('Gagal mengambil foto dari server');
    }
  }

  void _syncTemplateDrafts() {
    final templates = _effectiveTemplates;
    final keys = templates
        .map((t) => (t['shift'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    _tplMulaiDraft.removeWhere((k, _) => !keys.contains(k));
    _tplSelesaiDraft.removeWhere((k, _) => !keys.contains(k));
    for (final shiftKey in keys) {
      final (m, s) = _templateTimesFor(shiftKey);
      _tplMulaiDraft[shiftKey] = m;
      _tplSelesaiDraft[shiftKey] = s;
    }
    if (keys.isNotEmpty && !keys.contains(_shift)) {
      _shift = keys.first;
    }
  }

  List<Map<String, dynamic>> _jadwalPadaTanggal(String tglStr) =>
      _allJadwal.where((j) => (j['tanggal'] ?? '').toString() == tglStr).toList();

  _DateScheduleStatus _statusJadwalTanggal(String tglStr) =>
      _computeScheduleStatus(_jadwalPadaTanggal(tglStr), _expectedShiftKeys);

  Future<DateTime?> _openScheduleCalendar({
    required String title,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => _ScheduleCalendarDialog(
        title: title,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        allJadwal: _allJadwal,
        requestOff: _requestOff,
        shiftTemplates: _effectiveTemplates,
        activeKaryawanIds: _activeKaryawanIds,
        namaKaryawan: _namaKaryawan,
        formatHariTanggal: _formatHariTanggal,
        shortTime: _short,
      ),
    );
  }

  Future<void> _pickTanggal() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final last =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 365));
    final d = await _openScheduleCalendar(
      title: 'Pilih Tanggal Shift',
      initialDate: _tanggal,
      firstDate: first,
      lastDate: last,
    );
    if (d != null) setState(() => _tanggal = d);
  }

  Future<void> _pickFilterTanggalJadwal() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 7));
    final last =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 365));
    final initDt = (_filterTanggalJadwal != null
            ? DateTime.tryParse(_filterTanggalJadwal!)
            : null) ??
        now;
    final d = await _openScheduleCalendar(
      title: 'Filter Tanggal Jadwal',
      initialDate: initDt,
      firstDate: first,
      lastDate: last,
    );
    if (d != null) {
      setState(() {
        _filterTanggalJadwal = DateFormat('yyyy-MM-dd').format(d);
      });
    }
  }

  void _geserFilterHari(int deltaHari) {
    final baseDt = (_filterTanggalJadwal != null
            ? DateTime.tryParse(_filterTanggalJadwal!)
            : null) ??
        DateTime.now();
    final nextDt = baseDt.add(Duration(days: deltaHari));
    setState(() {
      _filterTanggalJadwal = DateFormat('yyyy-MM-dd').format(nextDt);
    });
  }

  Future<void> _pickJam(bool mulai) async {
    final t = await showTimePicker(
      context: context,
      initialTime: mulai ? _jamMulai : _jamSelesai,
    );
    if (t != null) {
      setState(() {
        _jamCustomEdited = true;
        if (mulai) {
          _jamMulai = t;
        } else {
          _jamSelesai = t;
        }
      });
    }
  }

  Future<void> _pickTemplateJam(String shiftKey, bool mulai) async {
    final init = mulai
        ? (_tplMulaiDraft[shiftKey] ?? const TimeOfDay(hour: 8, minute: 0))
        : (_tplSelesaiDraft[shiftKey] ?? const TimeOfDay(hour: 16, minute: 0));
    final t = await showTimePicker(
      context: context,
      initialTime: init,
    );
    if (t != null) {
      setState(() {
        if (mulai) {
          _tplMulaiDraft[shiftKey] = t;
        } else {
          _tplSelesaiDraft[shiftKey] = t;
        }
      });
    }
  }

  Future<void> _simpanTemplateShift(String shiftKey) async {
    final mulai = _tplMulaiDraft[shiftKey] ?? const TimeOfDay(hour: 8, minute: 0);
    final selesai =
        _tplSelesaiDraft[shiftKey] ?? const TimeOfDay(hour: 16, minute: 0);
    final mulaiMin = mulai.hour * 60 + mulai.minute;
    final selesaiMin = selesai.hour * 60 + selesai.minute;

    if (selesaiMin <= mulaiMin) {
      _snack('Jam selesai harus setelah jam mulai');
      return;
    }

    setState(() => _savingTemplateShift = shiftKey);
    try {
      final att = context.read<AttendanceProvider>();
      final resp = await att.updateShiftTemplate(
        shift: shiftKey,
        jamMulai: _fmtTime(mulai),
        jamSelesai: _fmtTime(selesai),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final label = _shiftDisplayName(shiftKey);
        setState(() {
          _shiftTemplates = att.shiftTemplates;
          _syncTemplateDrafts();
          if (!_jamCustomEdited && _shift == shiftKey) {
            _jamMulai = mulai;
            _jamSelesai = selesai;
          }
        });
        _snack('Template $label berhasil disimpan ke database');
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    } finally {
      if (mounted) setState(() => _savingTemplateShift = null);
    }
  }

  Future<void> _openAddTemplateDialog() async {
    final result = await showDialog<_TemplateFormResult>(
      context: context,
      builder: (_) => const _TemplateFormDialog(
        title: 'Tambah Template Shift',
        submitLabel: 'Tambah Template',
        initialNama: '',
        initialMulai: TimeOfDay(hour: 12, minute: 0),
        initialSelesai: TimeOfDay(hour: 20, minute: 0),
        showTimePickers: true,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _savingTemplateShift = '__creating__');
    try {
      final att = context.read<AttendanceProvider>();
      final resp = await att.createShiftTemplate(
        nama: result.nama,
        jamMulai: _fmtTime(result.jamMulai),
        jamSelesai: _fmtTime(result.jamSelesai),
      );
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        setState(() {
          _shiftTemplates = att.shiftTemplates;
          _syncTemplateDrafts();
        });
        _snack('Template ${result.nama} berhasil ditambahkan');
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    } finally {
      if (mounted) setState(() => _savingTemplateShift = null);
    }
  }

  Future<void> _openRenameTemplateDialog(Map<String, dynamic> tpl) async {
    final shiftKey = (tpl['shift'] ?? '').toString();
    final currentNama = _shiftDisplayName(shiftKey);
    final mulai = _tplMulaiDraft[shiftKey] ?? _templateTimesFor(shiftKey).$1;
    final selesai = _tplSelesaiDraft[shiftKey] ?? _templateTimesFor(shiftKey).$2;

    final result = await showDialog<_TemplateFormResult>(
      context: context,
      builder: (_) => _TemplateFormDialog(
        title: 'Ubah Nama Template Shift',
        submitLabel: 'Simpan Nama',
        initialNama: currentNama,
        initialMulai: mulai,
        initialSelesai: selesai,
        showTimePickers: false,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _savingTemplateShift = shiftKey);
    try {
      final att = context.read<AttendanceProvider>();
      final resp = await att.updateShiftTemplate(
        shift: shiftKey,
        nama: result.nama,
        jamMulai: _fmtTime(mulai),
        jamSelesai: _fmtTime(selesai),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _shiftTemplates = att.shiftTemplates;
          _syncTemplateDrafts();
        });
        _snack('Nama template diubah menjadi ${result.nama}');
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    } finally {
      if (mounted) setState(() => _savingTemplateShift = null);
    }
  }

  Future<void> _hapusTemplateShift(String shiftKey, String nama) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Template Shift?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'Template "$nama" akan dihapus permanen dari database (hanya jika belum dipakai oleh jadwal shift manapun).',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _savingTemplateShift = shiftKey);
    try {
      final att = context.read<AttendanceProvider>();
      final resp = await att.deleteShiftTemplate(shiftKey);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _shiftTemplates = att.shiftTemplates;
          _syncTemplateDrafts();
          if (!_jamCustomEdited) {
            final (m, s) = _templateTimesFor(_shift);
            _jamMulai = m;
            _jamSelesai = s;
          }
        });
        _snack('Template $nama berhasil dihapus');
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    } finally {
      if (mounted) setState(() => _savingTemplateShift = null);
    }
  }

  void _onShiftChanged(String? v) {
    if (v == null) return;
    final (mulai, selesai) = _templateTimesFor(v);
    setState(() {
      _shift = v;
      _jamCustomEdited = false;
      _jamMulai = mulai;
      _jamSelesai = selesai;
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isApproval = _currentSection == 1;
    final isTemplate = _currentSection == 2;
    final standaloneTitle = isTemplate
        ? 'Template Shift'
        : isApproval
            ? 'Approval Izin & Off'
            : 'Atur Jadwal Shift';

    return PageRefreshRegistrar(
      onRefresh: _loadAll,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: buildStandaloneAppBar(
          context,
          title: standaloneTitle,
          onRefresh: _loadAll,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _brown))
            : _loadError != null
                ? Center(child: Text(_loadError!))
                : isTemplate
                    ? _buildTabTemplateShift()
                    : (isApproval ? _buildTabApproval() : _buildTabJadwal()),
      ),
    );
  }

  Widget _wrap(Widget child) => RefreshIndicator(
        color: _brown,
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: child,
            ),
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _title(String t) => Text(t,
      style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A1A)));

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? hintText,
  }) {
    return InputDecorator(
      decoration: _dec(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: hintText != null
              ? Text(
                  hintText,
                  style: const TextStyle(color: _textDim, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _pickerBox(
      String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(label),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _brown),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabJadwal() {
    final offListToday = _requestOffPadaTanggal;
    final selectedIsOff = _isKaryawanRequestOff(_karyawanId, _tanggalStr);

    return _wrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _title('Penugasan Shift & Area Kerja')),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _brown,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text(
                        'Atur Template',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => setState(() => _currentSection = 2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _pickerBox(
                  'Tanggal Shift',
                  _formatHariTanggal(_tanggalStr),
                  Icons.event_rounded,
                  _pickTanggal,
                ),
                const SizedBox(height: 8),
                _buildSelectedDateStatusHint(_tanggalStr),
                if (offListToday.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 18, color: Colors.orange.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Karyawan Request Off pada $_tanggalStr:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...offListToday.map((r) {
                          final alasan = (r['alasan'] ?? '').toString().trim();
                          return Padding(
                            padding: const EdgeInsets.only(left: 26, bottom: 2),
                            child: Text(
                              '• ${_namaKaryawan(r['karyawan_id'])}${alasan.isNotEmpty ? ' ($alasan)' : ' (Tanpa keterangan)'}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange.shade900),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _dropdownField(
                  label: 'Pilih Karyawan',
                  hintText: '-- Pilih Karyawan --',
                  value:
                      _karyawan.any((k) => k['id'].toString() == _karyawanId)
                          ? _karyawanId
                          : null,
                  items: _karyawan.map((k) {
                    final idStr = k['id'].toString();
                    final nama =
                        (k['nama'] ?? k['nama_lengkap'] ?? k['email'] ?? '-')
                            .toString();
                    final divisiRaw = (k['divisi'] ?? 'kasir').toString();
                    final divTag = divisiRaw == 'kitchen'
                        ? 'KITCHEN'
                        : divisiRaw == 'bar'
                            ? 'BAR'
                            : 'KASIR';
                    final isOff = _isKaryawanRequestOff(idStr, _tanggalStr);
                    final isScheduled =
                        _isKaryawanSudahDijadwalkan(idStr, _tanggalStr);

                    String label = '$nama [$divTag]';
                    Color textColor = Colors.black87;
                    if (isOff) {
                      label = '$nama [$divTag] (SEDANG REQUEST OFF)';
                      textColor = Colors.red.shade700;
                    } else if (isScheduled) {
                      label = '$nama [$divTag] (Sudah Dijadwalkan)';
                      textColor = Colors.grey.shade600;
                    }

                    return DropdownMenuItem(
                      value: idStr,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight:
                              isOff ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() {
                    _karyawanId = v;
                    if (v != null) {
                      final match = _karyawan
                          .where((k) => k['id'].toString() == v)
                          .toList();
                      if (match.isNotEmpty) {
                        final div = match.first['divisi']?.toString();
                        if (div == 'kasir' || div == 'bar' || div == 'kitchen') {
                          _area = div!;
                        }
                      }
                    }
                  }),
                ),
                if (selectedIsOff) ...[
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ ${_namaKaryawan(_karyawanId)} sedang mengambil Request Off pada tanggal ini dan tidak dapat dijadwalkan.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;
                    final templateKeys = _expectedShiftKeys;
                    final validShiftValue =
                        templateKeys.contains(_shift) ? _shift : templateKeys.first;
                    final shiftDropdown = _dropdownField(
                      label: 'Shift',
                      value: validShiftValue,
                      items: templateKeys
                          .map(
                            (k) => DropdownMenuItem(
                              value: k,
                              child: Text(
                                _shiftOptionLabel(k),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _onShiftChanged,
                    );
                    final areaDropdown = _dropdownField(
                      label: 'Area Kerja',
                      value: _area,
                      items: const [
                        DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
                        DropdownMenuItem(value: 'bar', child: Text('Bar')),
                        DropdownMenuItem(
                            value: 'kitchen', child: Text('Kitchen')),
                      ],
                      onChanged: (v) => setState(() => _area = v ?? 'kasir'),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          shiftDropdown,
                          const SizedBox(height: 12),
                          areaDropdown,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: shiftDropdown),
                        const SizedBox(width: 12),
                        Expanded(child: areaDropdown),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 420;
                    final boxMulai = _pickerBox(
                        'Jam Mulai',
                        _jamMulai.format(context),
                        Icons.access_time_rounded,
                        () => _pickJam(true));
                    final boxSelesai = _pickerBox(
                        'Jam Selesai',
                        _jamSelesai.format(context),
                        Icons.access_time_filled_rounded,
                        () => _pickJam(false));

                    if (isNarrow) {
                      return Column(
                        children: [
                          boxMulai,
                          const SizedBox(height: 12),
                          boxSelesai,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: boxMulai),
                        const SizedBox(width: 12),
                        Expanded(child: boxSelesai),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final (tplM, tplS) = _templateTimesFor(_shift);
                  final isDifferent = _fmtTodShort(_jamMulai) != _fmtTodShort(tplM) ||
                      _fmtTodShort(_jamSelesai) != _fmtTodShort(tplS);
                  return Row(
                    children: [
                      Icon(
                        isDifferent
                            ? Icons.edit_note_rounded
                            : Icons.schedule_rounded,
                        size: 14,
                        color: _textDim,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isDifferent
                              ? 'Jam disesuaikan manual (Template: ${_fmtTodShort(tplM)} – ${_fmtTodShort(tplS)})'
                              : 'Mengikuti template DB (${_fmtTodShort(tplM)} – ${_fmtTodShort(tplS)})',
                          style: const TextStyle(fontSize: 11.5, color: _textDim),
                        ),
                      ),
                      if (isDifferent)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: _brown,
                          ),
                          onPressed: () => setState(() {
                            _jamCustomEdited = false;
                            _jamMulai = tplM;
                            _jamSelesai = tplS;
                          }),
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: (_saving || selectedIsOff) ? null : _simpan,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      selectedIsOff
                          ? 'Karyawan Sedang Request Off'
                          : 'Simpan Jadwal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildJadwalMendatangSection(),
          const SizedBox(height: 24),
          _title('Daftar Request Off Karyawan (${_requestOff.length})'),
          const SizedBox(height: 12),
          _buildRequestOffCard(),
        ],
      ),
    );
  }

  Widget _buildSelectedDateStatusHint(String tglStr) {
    final entries = _jadwalPadaTanggal(tglStr);
    final offs = _requestOff
        .where((r) => (r['tanggal'] ?? '').toString() == tglStr)
        .toList();
    final activeIds = _activeKaryawanIds;
    final expectedKeys = _expectedShiftKeys;
    final status =
        _computeScheduleStatus(entries, expectedKeys, activeIds, offs);
    final shifts = entries.map((j) => (j['shift'] ?? '').toString()).toSet();

    final Color bgColor;
    final Color borderColor;
    final Color fgColor;
    final IconData icon;
    final String text;

    switch (status) {
      case _DateScheduleStatus.complete:
        bgColor = const Color(0xFFDCFCE7);
        borderColor = const Color(0xFF86EFAC);
        fgColor = const Color(0xFF166534);
        icon = Icons.check_circle_rounded;
        if (activeIds.isNotEmpty) {
          final offCount = activeIds
              .where((id) => offs.any((r) => r['karyawan_id'].toString() == id))
              .length;
          text = offCount > 0
              ? 'Semua ${activeIds.length} karyawan lengkap (${entries.length} jadwal, $offCount request off)'
              : 'Semua ${activeIds.length} karyawan sudah mendapat shift (${entries.length} jadwal)';
        } else if (expectedKeys.length == 2 &&
            expectedKeys.contains('shift_1') &&
            expectedKeys.contains('shift_2')) {
          text = 'Shift 1 & Shift 2 sudah lengkap (${entries.length} jadwal)';
        } else {
          text =
              'Semua ${expectedKeys.length} template shift lengkap (${entries.length} jadwal)';
        }
        break;
      case _DateScheduleStatus.partial:
        bgColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFFCD34D);
        fgColor = const Color(0xFF92400E);
        icon = Icons.timelapse_rounded;
        if (activeIds.isNotEmpty) {
          final coveredIds = {
            ...entries.map((e) => (e['karyawan_id'] ?? '').toString()),
            ...offs.map((r) => (r['karyawan_id'] ?? '').toString()),
          };
          final coveredCount = activeIds.where(coveredIds.contains).length;
          final missingCount = activeIds.length - coveredCount;
          text =
              'Baru $coveredCount/${activeIds.length} karyawan terjadwal — $missingCount belum mendapat shift';
        } else {
          final filledNames = expectedKeys
              .where(shifts.contains)
              .map(_shiftDisplayName)
              .toList();
          final missingNames = expectedKeys
              .where((k) => !shifts.contains(k))
              .map(_shiftDisplayName)
              .toList();
          if (expectedKeys.length == 2 &&
              filledNames.length == 1 &&
              missingNames.length == 1) {
            text =
                'Baru ${filledNames.first} terisi — ${missingNames.first} belum dijadwalkan';
          } else {
            text =
                'Terisi ${filledNames.length}/${expectedKeys.length} shift — Belum: ${missingNames.join(", ")}';
          }
        }
        break;
      case _DateScheduleStatus.none:
        bgColor = const Color(0xFFF3F4F6);
        borderColor = const Color(0xFFE5E7EB);
        fgColor = _textDim;
        icon = Icons.event_available_rounded;
        text = 'Belum ada jadwal shift pada tanggal ini';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: fgColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: status == _DateScheduleStatus.none
                    ? FontWeight.w500
                    : FontWeight.w600,
                color: fgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJadwalMendatangSection() {
    final tanggalChips = _pilihanTanggalFilter;
    final isSemua = _filterTanggalJadwal == null;

    // Kelompokkan jadwal berdasarkan tanggal
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    if (isSemua) {
      for (final j in _jadwal) {
        final t = (j['tanggal'] ?? '').toString();
        grouped.putIfAbsent(t, () => []).add(j);
      }
    } else {
      final tgl = _filterTanggalJadwal!;
      grouped[tgl] = _jadwal
          .where((j) => (j['tanggal'] ?? '').toString() == tgl)
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _title('Jadwal Mendatang')),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _brown,
                backgroundColor: Colors.white,
                side: BorderSide(color: _brown.withValues(alpha: 0.3)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.calendar_today_rounded, size: 15),
              label: const Text('Pilih Hari',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: _pickFilterTanggalJadwal,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Bar Filter Cepat Per Hari (Horizontal Scroll)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Semua Hari (${_jadwal.length})'),
                  selected: isSemua,
                  selectedColor: _brown,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSemua ? Colors.white : _brown,
                  ),
                  checkmarkColor: Colors.white,
                  onSelected: (_) =>
                      setState(() => _filterTanggalJadwal = null),
                ),
              ),
              ...tanggalChips.map((tgl) {
                final selected = _filterTanggalJadwal == tgl;
                final count = _jumlahJadwalPadaTanggal(tgl);
                final status = _statusJadwalTanggal(tgl);

                Color chipBg = Colors.white;
                Color chipFg = count > 0 ? _brown : _textDim;
                Color? borderColor;
                Color? dotColor;

                if (status == _DateScheduleStatus.complete) {
                  chipBg = const Color(0xFFECFDF5);
                  chipFg = const Color(0xFF166534);
                  borderColor = const Color(0xFF86EFAC);
                  dotColor = selected
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFF16A34A);
                } else if (status == _DateScheduleStatus.partial) {
                  chipBg = const Color(0xFFFFFBEB);
                  chipFg = const Color(0xFF92400E);
                  borderColor = const Color(0xFFFCD34D);
                  dotColor = selected
                      ? const Color(0xFFFCD34D)
                      : const Color(0xFFD97706);
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dotColor != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          '${_formatHariTanggal(tgl, short: true)}${count > 0 ? ' ($count)' : ''}',
                        ),
                      ],
                    ),
                    selected: selected,
                    selectedColor: _brown,
                    backgroundColor: chipBg,
                    side: selected || borderColor == null
                        ? null
                        : BorderSide(color: borderColor),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected || count > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? Colors.white : chipFg,
                    ),
                    checkmarkColor: Colors.white,
                    onSelected: (_) =>
                        setState(() => _filterTanggalJadwal = tgl),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Navigasi Hari (< Hari Ini / Tanggal >) saat mode Filter Per Hari aktif
        if (!isSemua) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _brown.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Hari Sebelumnya',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left_rounded, color: _brown),
                  onPressed: () => _geserFilterHari(-1),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickFilterTanggalJadwal,
                    child: Column(
                      children: [
                        Text(
                          _formatHariTanggal(_filterTanggalJadwal!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _brown,
                          ),
                        ),
                        Text(
                          '${grouped[_filterTanggalJadwal!]?.length ?? 0} Shift Terjadwal',
                          style: const TextStyle(fontSize: 11, color: _textDim),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Hari Berikutnya',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right_rounded, color: _brown),
                  onPressed: () => _geserFilterHari(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Konten Jadwal
        if (isSemua && _jadwal.isEmpty)
          _card(
            child: const Row(
              children: [
                Icon(Icons.event_busy_rounded, color: _textDim, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Belum ada jadwal mendatang',
                      style: TextStyle(color: _textDim)),
                ),
              ],
            ),
          )
        else if (!isSemua && (grouped[_filterTanggalJadwal!] ?? []).isEmpty)
          _card(
            child: Row(
              children: [
                const Icon(Icons.event_note_rounded, color: _textDim, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum ada jadwal shift pada ${_formatHariTanggal(_filterTanggalJadwal!)}',
                    style: const TextStyle(color: _textDim),
                  ),
                ),
              ],
            ),
          )
        else
          ...grouped.entries.map((entry) {
            final tgl = entry.key;
            final listHari = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _brown.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.event_rounded,
                              color: _brown, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formatHariTanggal(tgl),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _brown,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _brown.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${listHari.length} Shift',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    ...listHari.map((j) {
                      final shiftLabel =
                          _shiftDisplayName((j['shift'] ?? '').toString())
                              .toUpperCase();
                      final areaLabel =
                          (j['area_kerja'] ?? '').toString().toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _brown.withValues(alpha: 0.08),
                              child: const Icon(Icons.person_rounded,
                                  color: _brown, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _namaKaryawan(j['karyawan_id']),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$shiftLabel · ${_short(j['jam_mulai'])}–${_short(j['jam_selesai'])}',
                                    style: const TextStyle(
                                        fontSize: 12, color: _textDim),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _brown.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                areaLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _brown,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRequestOffCard() {
    if (_requestOff.isEmpty) {
      return _card(
        child: const Row(
          children: [
            Icon(Icons.event_available_rounded,
                color: Color(0xFF10B981), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text('Belum ada pengajuan Request Off mendatang',
                  style: TextStyle(color: _textDim)),
            ),
          ],
        ),
      );
    }
    return _card(
      child: Column(
        children: _requestOff.map((r) {
          final alasan = (r['alasan'] ?? '').toString().trim();
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.event_busy_rounded,
                  color: Colors.orange.shade800, size: 18),
            ),
            title: Text(
              '${_namaKaryawan(r['karyawan_id'])} · ${_formatHariTanggal((r['tanggal'] ?? '').toString(), short: true)}',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              alasan.isNotEmpty
                  ? 'Alasan: $alasan'
                  : 'Tanpa keterangan alasan',
              style: const TextStyle(fontSize: 12, color: _textDim),
            ),
            trailing: IconButton(
              tooltip: 'Hapus / Batalkan Request Off',
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade400),
              onPressed: () => _hapusRequestOff(r['id'].toString()),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabApproval() {
    return _wrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IZIN TERLAMBAT
          _title('Pengajuan Izin Terlambat (${_izinTelat.length})'),
          const SizedBox(height: 12),
          if (_izinTelat.isEmpty)
            _emptyApprovalCard('Tidak ada pengajuan izin terlambat menunggu')
          else
            _card(
              child: Column(
                children: _izinTelat.map((it) {
                  final alasan = (it['alasan'] ?? '-').toString();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                      child: Icon(Icons.alarm_off_rounded,
                          color: Colors.amber.shade800, size: 18),
                    ),
                    title: Text(
                      _namaKaryawan(it['karyawan_id']),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${_infoShiftById(it['jadwal_shift_id'])}\nAlasan: $alasan',
                      style: const TextStyle(fontSize: 12, color: _textDim),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (it['foto_id'] != null)
                          IconButton(
                            tooltip: 'Lihat Foto',
                            icon: const Icon(Icons.image_rounded,
                                color: Colors.blue),
                            onPressed: () =>
                                _lihatFotoBukti(it['foto_id']?.toString()),
                          ),
                        IconButton(
                          tooltip: 'Setujui',
                          icon: const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF10B981)),
                          onPressed: () => _prosesIzinTelat(
                              it['id'].toString(), 'disetujui'),
                        ),
                        IconButton(
                          tooltip: 'Tolak',
                          icon: Icon(Icons.cancel_rounded,
                              color: Colors.red.shade400),
                          onPressed: () =>
                              _prosesIzinTelat(it['id'].toString(), 'ditolak'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 24),

          // 2. IZIN TIDAK MASUK
          _title('Pengajuan Izin Tidak Masuk (${_izinTidakMasuk.length})'),
          const SizedBox(height: 12),
          if (_izinTidakMasuk.isEmpty)
            _emptyApprovalCard('Tidak ada pengajuan izin tidak masuk menunggu')
          else
            _card(
              child: Column(
                children: _izinTidakMasuk.map((itm) {
                  final alasan = (itm['alasan'] ?? '-').toString();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.red.withValues(alpha: 0.12),
                      child: Icon(Icons.sick_rounded,
                          color: Colors.red.shade700, size: 18),
                    ),
                    title: Text(
                      _namaKaryawan(itm['karyawan_id']),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${_infoShiftById(itm['jadwal_shift_id'])}\nAlasan: $alasan',
                      style: const TextStyle(fontSize: 12, color: _textDim),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Lihat Foto Bukti',
                          icon: const Icon(Icons.photo_library_rounded,
                              color: Colors.blue),
                          onPressed: () =>
                              _lihatFotoBukti(itm['foto_id']?.toString()),
                        ),
                        IconButton(
                          tooltip: 'Setujui',
                          icon: const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF10B981)),
                          onPressed: () => _prosesIzinTidakMasuk(
                              itm['id'].toString(), 'disetujui'),
                        ),
                        IconButton(
                          tooltip: 'Tolak',
                          icon: Icon(Icons.cancel_rounded,
                              color: Colors.red.shade400),
                          onPressed: () => _prosesIzinTidakMasuk(
                              itm['id'].toString(), 'ditolak'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 24),

          // 3. TUKAR SHIFT
          _title('Pengajuan Tukar Shift (${_tukar.length})'),
          const SizedBox(height: 12),
          if (_tukar.isEmpty)
            _emptyApprovalCard('Tidak ada pengajuan tukar shift menunggu')
          else
            _card(
              child: Column(
                children: _tukar.map((t) {
                  final shiftA = _allJadwal.firstWhere(
                    (j) => j['id'].toString() == t['shift_a_id'].toString(),
                    orElse: () => {},
                  );
                  final tgl = t['tanggal_shift'] ?? shiftA['tanggal'] ?? '-';
                  final alasan = (t['alasan'] ?? '').toString();
                  final statusTarget =
                      (t['status_target'] ?? 'pending').toString().toLowerCase();
                  final targetSudahSetuju = statusTarget == 'disetujui';
                  final namaPengaju = (t['nama_pengaju'] ??
                          _namaKaryawan(t['karyawan_pengaju_id']))
                      .toString();
                  final namaTarget = (t['nama_target'] ??
                          _namaKaryawan(t['karyawan_target_id']))
                      .toString();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _brown.withValues(alpha: 0.1),
                      child: const Icon(Icons.swap_horiz_rounded,
                          color: _brown, size: 18),
                    ),
                    title: Text(
                      '$namaPengaju  ⇄  $namaTarget',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tanggal: $tgl${alasan.isNotEmpty ? '\nAlasan: $alasan' : ''}',
                          style: const TextStyle(fontSize: 12, color: _textDim),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: targetSudahSetuju
                                ? Colors.green.shade50
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: targetSudahSetuju
                                  ? Colors.green.shade300
                                  : Colors.amber.shade300,
                            ),
                          ),
                          child: Text(
                            targetSudahSetuju
                                ? '✓ Kedua Pihak Setuju ($namaTarget menyetujui)'
                                : '⏳ Menunggu konfirmasi dari $namaTarget',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: targetSudahSetuju
                                  ? Colors.green.shade800
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: targetSudahSetuju
                              ? 'Setujui'
                              : 'Menunggu persetujuan rekan target ($namaTarget)',
                          icon: Icon(
                            Icons.check_circle_rounded,
                            color: targetSudahSetuju
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade400,
                          ),
                          onPressed: targetSudahSetuju
                              ? () =>
                                  _prosesTukar(t['id'].toString(), 'disetujui')
                              : null,
                        ),
                        IconButton(
                          tooltip: 'Tolak',
                          icon: Icon(Icons.cancel_rounded,
                              color: Colors.red.shade400),
                          onPressed: () =>
                              _prosesTukar(t['id'].toString(), 'ditolak'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 24),

          // 4. REQUEST OFF
          _title('Informasi Request Off Karyawan (${_requestOff.length})'),
          const SizedBox(height: 12),
          _buildRequestOffCard(),
        ],
      ),
    );
  }

  (IconData, Color) _styleForTemplate(String shiftKey, int index, TimeOfDay start) {
    if (shiftKey == 'shift_1') {
      return (Icons.wb_sunny_rounded, const Color(0xFFD97706));
    }
    if (shiftKey == 'shift_2') {
      return (Icons.nights_stay_rounded, const Color(0xFF4F46E5));
    }
    if (start.hour < 12) {
      return (Icons.wb_twilight_rounded, const Color(0xFF0D9488));
    }
    if (start.hour < 17) {
      return (Icons.schedule_rounded, _brown);
    }
    return (Icons.dark_mode_rounded, const Color(0xFF7C3AED));
  }

  Widget _buildTabTemplateShift() {
    final templates = _effectiveTemplates;
    final isCreating = _savingTemplateShift == '__creating__';
    final canDelete = _shiftTemplates.length > 1;

    return _wrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.initialSection != 2) ...[
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _brown,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              onPressed: () => setState(() => _currentSection = 0),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text(
                'Kembali ke Atur Jadwal Shift',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: _brown),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Template Shift disimpan langsung di database (tabel shift_template). Anda dapat menambah, mengubah nama & jam kerja, atau menghapus template shift sesuai kebutuhan operasional.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF065F46),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _brown,
                backgroundColor: Colors.white,
                side: const BorderSide(color: _brown, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isCreating ? null : _openAddTemplateDialog,
              icon: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _brown,
                      ),
                    )
                  : const Icon(Icons.add_circle_outline_rounded, size: 19),
              label: const Text(
                'Tambah Template Shift Baru',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < templates.length; i++) ...[
            _buildTemplateShiftCard(
              tpl: templates[i],
              index: i,
              canDelete: canDelete,
            ),
            if (i < templates.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateShiftCard({
    required Map<String, dynamic> tpl,
    required int index,
    required bool canDelete,
  }) {
    final shiftKey = (tpl['shift'] ?? '').toString();
    final title = _shiftDisplayName(shiftKey);
    final (dbMulai, dbSelesai) = _templateTimesFor(shiftKey);
    final draftMulai = _tplMulaiDraft[shiftKey] ?? dbMulai;
    final draftSelesai = _tplSelesaiDraft[shiftKey] ?? dbSelesai;
    final (icon, accentColor) = _styleForTemplate(shiftKey, index, draftMulai);

    final startMin = draftMulai.hour * 60 + draftMulai.minute;
    final endMin = draftSelesai.hour * 60 + draftSelesai.minute;
    final diffMin = endMin - startMin;
    final validDuration = diffMin > 0;
    final durJam = diffMin ~/ 60;
    final durMnt = diffMin % 60;
    final durasiLabel = validDuration
        ? (durMnt > 0 ? '$durJam jam $durMnt mnt' : '$durJam jam')
        : 'Jam tidak valid';

    final isDirty = _fmtTodShort(draftMulai) != _fmtTodShort(dbMulai) ||
        _fmtTodShort(draftSelesai) != _fmtTodShort(dbSelesai);
    final isSavingThis = _savingTemplateShift == shiftKey;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1D1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aktif di DB: ${_fmtTodShort(dbMulai)} – ${_fmtTodShort(dbSelesai)}',
                      style: const TextStyle(fontSize: 12, color: _textDim),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: validDuration
                                ? _brown.withValues(alpha: 0.08)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            durasiLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  validDuration ? _brown : Colors.red.shade700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            shiftKey,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4B5563),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ubah Nama Template',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(6),
                icon: const Icon(Icons.edit_outlined, size: 18, color: _brown),
                onPressed:
                    isSavingThis ? null : () => _openRenameTemplateDialog(tpl),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Hapus Template',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(6),
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red.shade500),
                  onPressed: isSavingThis
                      ? null
                      : () => _hapusTemplateShift(shiftKey, title),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final boxMulai = _pickerBox(
                'Jam Mulai Template',
                draftMulai.format(context),
                Icons.access_time_rounded,
                () => _pickTemplateJam(shiftKey, true),
              );
              final boxSelesai = _pickerBox(
                'Jam Selesai Template',
                draftSelesai.format(context),
                Icons.access_time_filled_rounded,
                () => _pickTemplateJam(shiftKey, false),
              );
              if (isNarrow) {
                return Column(
                  children: [
                    boxMulai,
                    const SizedBox(height: 12),
                    boxSelesai,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: boxMulai),
                  const SizedBox(width: 12),
                  Expanded(child: boxSelesai),
                ],
              );
            },
          ),
          if (!validDuration) ...[
            const SizedBox(height: 8),
            Text(
              'Jam selesai harus lebih lambat dari jam mulai (shift melewati tengah malam belum didukung).',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDirty ? _brown : const Color(0xFF335C49),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (isSavingThis || !validDuration)
                  ? null
                  : () => _simpanTemplateShift(shiftKey),
              icon: isSavingThis
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                isDirty ? 'Simpan Perubahan Template' : 'Simpan Template',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyApprovalCard(String text) {
    return _card(
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: _textDim)),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCalendarDialog extends StatefulWidget {
  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final List<Map<String, dynamic>> allJadwal;
  final List<Map<String, dynamic>> requestOff;
  final List<Map<String, dynamic>> shiftTemplates;
  final Set<String> activeKaryawanIds;
  final String Function(dynamic id) namaKaryawan;
  final String Function(String tglStr, {bool short}) formatHariTanggal;
  final String Function(dynamic t) shortTime;

  const _ScheduleCalendarDialog({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.allJadwal,
    required this.requestOff,
    required this.shiftTemplates,
    this.activeKaryawanIds = const {},
    required this.namaKaryawan,
    required this.formatHariTanggal,
    required this.shortTime,
  });

  @override
  State<_ScheduleCalendarDialog> createState() =>
      _ScheduleCalendarDialogState();
}

class _ScheduleCalendarDialogState extends State<_ScheduleCalendarDialog> {
  static const _bulanIndo = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  static const _hariHeader = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

  late final DateTime _firstDay;
  late final DateTime _lastDay;
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  late final Map<String, List<Map<String, dynamic>>> _jadwalByDate;
  late final Map<String, List<Map<String, dynamic>>> _offByDate;

  List<String> get _expectedShifts {
    final keys = widget.shiftTemplates
        .map((t) => (t['shift'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    return keys.isNotEmpty ? keys : const ['shift_1', 'shift_2'];
  }

  bool get _isTwoDefaultShifts =>
      _expectedShifts.length == 2 &&
      _expectedShifts.contains('shift_1') &&
      _expectedShifts.contains('shift_2');

  String _templateTitle(String shiftKey) {
    for (final t in widget.shiftTemplates) {
      if ((t['shift'] ?? '').toString() == shiftKey) {
        final nama = (t['nama'] ?? '').toString().trim();
        if (nama.isNotEmpty) return nama;
      }
    }
    return _defaultShiftTitleFromKey(shiftKey);
  }

  @override
  void initState() {
    super.initState();
    _firstDay = DateTime(
        widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    _lastDay = DateTime(
        widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);

    var init = DateTime(widget.initialDate.year, widget.initialDate.month,
        widget.initialDate.day);
    if (init.isBefore(_firstDay)) init = _firstDay;
    if (init.isAfter(_lastDay)) init = _lastDay;
    _selectedDate = init;
    _displayedMonth = DateTime(init.year, init.month, 1);

    _jadwalByDate = {};
    for (final j in widget.allJadwal) {
      final tgl = (j['tanggal'] ?? '').toString();
      if (tgl.isNotEmpty) {
        _jadwalByDate.putIfAbsent(tgl, () => []).add(j);
      }
    }

    _offByDate = {};
    for (final r in widget.requestOff) {
      final tgl = (r['tanggal'] ?? '').toString();
      if (tgl.isNotEmpty) {
        _offByDate.putIfAbsent(tgl, () => []).add(r);
      }
    }
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool get _canGoPrevMonth {
    final prevMonthEnd =
        DateTime(_displayedMonth.year, _displayedMonth.month, 0);
    return !prevMonthEnd.isBefore(_firstDay);
  }

  bool get _canGoNextMonth {
    final nextMonthStart =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    return !nextMonthStart.isAfter(_lastDay);
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + delta, 1);
    });
  }

  String _capArea(dynamic raw) {
    final s = (raw ?? '').toString();
    if (s.isEmpty) return '-';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = _fmt(DateTime(now.year, now.month, now.day));
    final selectedStr = _fmt(_selectedDate);
    final selectedEntries = _jadwalByDate[selectedStr] ?? const [];
    final selectedOffs = _offByDate[selectedStr] ?? const [];
    final selectedStatus = _computeScheduleStatus(
      selectedEntries,
      _expectedShifts,
      widget.activeKaryawanIds,
      selectedOffs,
    );

    final firstOfMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final leadingEmpty = firstOfMonth.weekday % 7;
    final totalWeeks = ((leadingEmpty + daysInMonth + 6) ~/ 7);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(selectedStr, selectedEntries, selectedOffs, selectedStatus),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthBar(),
                    const SizedBox(height: 6),
                    _buildWeekdayHeader(),
                    const SizedBox(height: 6),
                    ...List.generate(
                      totalWeeks,
                      (weekIdx) => _buildWeekRow(
                        weekIdx: weekIdx,
                        leadingEmpty: leadingEmpty,
                        daysInMonth: daysInMonth,
                        todayStr: todayStr,
                        selectedStr: selectedStr,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildLegend(),
                    const SizedBox(height: 10),
                    _buildSelectedDatePreview(
                      selectedStr: selectedStr,
                      entries: selectedEntries,
                      offs: selectedOffs,
                      status: selectedStatus,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAEFEA)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textDim,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Batal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context, _selectedDate),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 17),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Pilih Tanggal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    String selectedStr,
    List<Map<String, dynamic>> entries,
    List<Map<String, dynamic>> offs,
    _DateScheduleStatus status,
  ) {
    final expected = _expectedShifts;
    final activeIds = widget.activeKaryawanIds;
    final filledShiftsCount = entries
        .map((e) => (e['shift'] ?? '').toString())
        .where((s) => expected.contains(s))
        .toSet()
        .length;
    final coveredIds = {
      ...entries.map((e) => (e['karyawan_id'] ?? '').toString()),
      ...offs.map((r) => (r['karyawan_id'] ?? '').toString()),
    };
    final coveredCount = activeIds.where(coveredIds.contains).length;

    final String statusLabel;
    final Color badgeBg;
    final Color badgeFg;
    switch (status) {
      case _DateScheduleStatus.complete:
        statusLabel = activeIds.isNotEmpty
            ? 'Semua Karyawan Lengkap ($coveredCount/${activeIds.length})'
            : (_isTwoDefaultShifts
                ? 'Shift 1 & 2 Lengkap'
                : 'Semua ${expected.length} Shift Lengkap');
        badgeBg = const Color(0xFFDCFCE7);
        badgeFg = const Color(0xFF14532D);
        break;
      case _DateScheduleStatus.partial:
        statusLabel = activeIds.isNotEmpty
            ? 'Sebagian ($coveredCount/${activeIds.length} Karyawan)'
            : (_isTwoDefaultShifts
                ? 'Sebagian (1 Shift)'
                : 'Sebagian ($filledShiftsCount/${expected.length} Shift)');
        badgeBg = const Color(0xFFFEF3C7);
        badgeFg = const Color(0xFF92400E);
        break;
      case _DateScheduleStatus.none:
        statusLabel = 'Belum Ada Shift';
        badgeBg = Colors.white.withValues(alpha: 0.16);
        badgeFg = Colors.white;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      color: _brown,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.formatHariTanggal(selectedStr),
                  style: GoogleFonts.outfit(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBar() {
    final monthName = _bulanIndo[_displayedMonth.month - 1];
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _canGoPrevMonth ? () => _changeMonth(-1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          color: _brown,
        ),
        Expanded(
          child: Center(
            child: Text(
              '$monthName ${_displayedMonth.year}',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _canGoNextMonth ? () => _changeMonth(1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: _brown,
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    return Row(
      children: List.generate(7, (idx) {
        final isSunday = idx == 0;
        return Expanded(
          child: Center(
            child: Text(
              _hariHeader[idx],
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isSunday ? const Color(0xFFB91C1C) : _textDim,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWeekRow({
    required int weekIdx,
    required int leadingEmpty,
    required int daysInMonth,
    required String todayStr,
    required String selectedStr,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: List.generate(7, (colIdx) {
          final cellIndex = weekIdx * 7 + colIdx;
          final dayNum = cellIndex - leadingEmpty + 1;
          if (dayNum < 1 || dayNum > daysInMonth) {
            return const Expanded(child: SizedBox(height: 40));
          }

          final date =
              DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
          final dateStr = _fmt(date);
          final disabled =
              date.isBefore(_firstDay) || date.isAfter(_lastDay);
          final entries = _jadwalByDate[dateStr] ?? const [];
          final offs = _offByDate[dateStr] ?? const [];
          final status = _computeScheduleStatus(
            entries,
            _expectedShifts,
            widget.activeKaryawanIds,
            offs,
          );
          final hasOff = offs.isNotEmpty;
          final isToday = dateStr == todayStr;
          final isSelected = !disabled && dateStr == selectedStr;

          Color bgColor = Colors.transparent;
          Color textColor = colIdx == 0
              ? const Color(0xFF991B1B)
              : const Color(0xFF1F2937);
          BoxBorder? border;

          if (disabled) {
            textColor = const Color(0xFFC4C9C6);
            if (status == _DateScheduleStatus.complete) {
              bgColor = const Color(0xFFDCFCE7).withValues(alpha: 0.45);
            } else if (status == _DateScheduleStatus.partial) {
              bgColor = const Color(0xFFFEF3C7).withValues(alpha: 0.45);
            }
          } else {
            if (status == _DateScheduleStatus.complete) {
              bgColor = isSelected
                  ? const Color(0xFF15803D)
                  : const Color(0xFFDCFCE7);
              textColor =
                  isSelected ? Colors.white : const Color(0xFF14532D);
              border = isSelected
                  ? Border.all(color: const Color(0xFF0F291E), width: 2)
                  : Border.all(color: const Color(0xFF16A34A), width: 1.2);
            } else if (status == _DateScheduleStatus.partial) {
              bgColor = isSelected
                  ? const Color(0xFFB45309)
                  : const Color(0xFFFEF3C7);
              textColor =
                  isSelected ? Colors.white : const Color(0xFF92400E);
              border = isSelected
                  ? Border.all(color: const Color(0xFF78350F), width: 2)
                  : Border.all(color: const Color(0xFFF59E0B), width: 1.2);
            } else if (isSelected) {
              bgColor = _brown;
              textColor = Colors.white;
            } else if (isToday) {
              textColor = _brown;
              border = Border.all(color: _brown, width: 1.5);
            }
          }

          final dotPrimary = isSelected
              ? Colors.white
              : (status == _DateScheduleStatus.complete
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFD97706));
          final dotOff =
              isSelected ? const Color(0xFFFDBA74) : const Color(0xFFEA580C);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: disabled
                      ? null
                      : () => setState(() => _selectedDate = date),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: border,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.1,
                              fontWeight: isSelected ||
                                      isToday ||
                                      status != _DateScheduleStatus.none
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            height: 5,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == _DateScheduleStatus.complete) ...[
                                  _dot(dotPrimary.withValues(
                                      alpha: disabled ? 0.5 : 1)),
                                  const SizedBox(width: 2),
                                  _dot(dotPrimary.withValues(
                                      alpha: disabled ? 0.5 : 1)),
                                ] else if (status ==
                                    _DateScheduleStatus.partial) ...[
                                  _dot(dotPrimary.withValues(
                                      alpha: disabled ? 0.5 : 1)),
                                ],
                                if (hasOff) ...[
                                  if (status != _DateScheduleStatus.none)
                                    const SizedBox(width: 2),
                                  _dot(dotOff.withValues(
                                      alpha: disabled ? 0.5 : 1)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 4.5,
        height: 4.5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5EBE7)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _legendItem(
            fill: const Color(0xFFDCFCE7),
            border: const Color(0xFF16A34A),
            label: widget.activeKaryawanIds.isNotEmpty
                ? 'Semua Terjadwal'
                : (_isTwoDefaultShifts
                    ? 'Shift Lengkap (1 & 2)'
                    : 'Semua Shift Lengkap'),
          ),
          _legendItem(
            fill: const Color(0xFFFEF3C7),
            border: const Color(0xFFF59E0B),
            label: widget.activeKaryawanIds.isNotEmpty
                ? 'Sebagian Terjadwal'
                : (_isTwoDefaultShifts
                    ? 'Sebagian (1 Shift)'
                    : 'Sebagian Terisi'),
          ),
          _legendItem(
            fill: Colors.white,
            border: const Color(0xFFD1D5DB),
            label: 'Kosong',
          ),
          _legendItem(
            fill: const Color(0xFFEA580C),
            border: const Color(0xFFEA580C),
            label: 'Request Off',
            isSmallDot: true,
          ),
        ],
      ),
    );
  }

  Widget _legendItem({
    required Color fill,
    required Color border,
    required String label,
    bool isSmallDot = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSmallDot ? 8 : 11,
          height: isSmallDot ? 8 : 11,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(isSmallDot ? 4 : 3),
            border: Border.all(color: border, width: 1.1),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDatePreview({
    required String selectedStr,
    required List<Map<String, dynamic>> entries,
    required List<Map<String, dynamic>> offs,
    required _DateScheduleStatus status,
  }) {
    final orderedKeys = <String>[
      ..._expectedShifts,
      for (final e in entries)
        if ((e['shift'] ?? '').toString().isNotEmpty &&
            !_expectedShifts.contains((e['shift'] ?? '').toString()))
          (e['shift'] ?? '').toString(),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: status == _DateScheduleStatus.complete
            ? const Color(0xFFF0FDF4)
            : (status == _DateScheduleStatus.partial
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: status == _DateScheduleStatus.complete
              ? const Color(0xFFBBF7D0)
              : (status == _DateScheduleStatus.partial
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan ${widget.formatHariTanggal(selectedStr, short: true)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          if (entries.isEmpty)
            const Text(
              'Belum ada jadwal yang dibuat pada tanggal ini.',
              style: TextStyle(fontSize: 11.5, color: _textDim),
            )
          else
            for (int i = 0; i < orderedKeys.length; i++)
              if (status != _DateScheduleStatus.complete ||
                  entries.any(
                      (e) => (e['shift'] ?? '').toString() == orderedKeys[i])) ...[
                _shiftPreviewRow(
                  _templateTitle(orderedKeys[i]),
                  entries
                      .where(
                          (e) => (e['shift'] ?? '').toString() == orderedKeys[i])
                      .toList(),
                ),
                if (i < orderedKeys.length - 1) const SizedBox(height: 4),
              ],
          if (offs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Request Off: ${offs.map((r) => widget.namaKaryawan(r['karyawan_id'])).join(', ')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shiftPreviewRow(
      String shiftTitle, List<Map<String, dynamic>> items) {
    final filled = items.isNotEmpty;
    final names = items
        .map((e) =>
            '${widget.namaKaryawan(e['karyawan_id'])} (${_capArea(e['area_kerja'])} ${widget.shortTime(e['jam_mulai'])}–${widget.shortTime(e['jam_selesai'])})')
        .join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: filled ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              shiftTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            filled ? names : 'Belum dijadwalkan',
            style: TextStyle(
              fontSize: 11.5,
              color: filled ? const Color(0xFF1F2937) : _textDim,
              fontStyle: filled ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateFormResult {
  final String nama;
  final TimeOfDay jamMulai;
  final TimeOfDay jamSelesai;

  const _TemplateFormResult({
    required this.nama,
    required this.jamMulai,
    required this.jamSelesai,
  });
}

class _TemplateFormDialog extends StatefulWidget {
  final String title;
  final String submitLabel;
  final String initialNama;
  final TimeOfDay initialMulai;
  final TimeOfDay initialSelesai;
  final bool showTimePickers;

  const _TemplateFormDialog({
    required this.title,
    required this.submitLabel,
    required this.initialNama,
    required this.initialMulai,
    required this.initialSelesai,
    required this.showTimePickers,
  });

  @override
  State<_TemplateFormDialog> createState() => _TemplateFormDialogState();
}

class _TemplateFormDialogState extends State<_TemplateFormDialog> {
  late final TextEditingController _namaCtrl;
  late TimeOfDay _jamMulai;
  late TimeOfDay _jamSelesai;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController(text: widget.initialNama);
    _jamMulai = widget.initialMulai;
    _jamSelesai = widget.initialSelesai;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _jamMulai : _jamSelesai,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _jamMulai = picked;
      } else {
        _jamSelesai = picked;
      }
      _errorText = null;
    });
  }

  void _submit() {
    final nama = _namaCtrl.text.trim();
    if (nama.isEmpty) {
      setState(() => _errorText = 'Nama template shift wajib diisi');
      return;
    }
    if (widget.showTimePickers) {
      final startMin = _jamMulai.hour * 60 + _jamMulai.minute;
      final endMin = _jamSelesai.hour * 60 + _jamSelesai.minute;
      if (endMin <= startMin) {
        setState(
            () => _errorText = 'Jam selesai harus lebih lambat dari jam mulai');
        return;
      }
    }
    Navigator.pop(
      context,
      _TemplateFormResult(
        nama: nama,
        jamMulai: _jamMulai,
        jamSelesai: _jamSelesai,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startMin = _jamMulai.hour * 60 + _jamMulai.minute;
    final endMin = _jamSelesai.hour * 60 + _jamSelesai.minute;
    final invalidDuration = widget.showTimePickers && endMin <= startMin;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      title: Text(
        widget.title,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _namaCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                decoration: InputDecoration(
                  labelText: 'Nama Template Shift',
                  hintText: 'Contoh: Shift 3, Middle Shift',
                  prefixIcon: const Icon(Icons.label_outline_rounded, size: 19),
                  filled: true,
                  fillColor: _cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (widget.showTimePickers) ...[
                const SizedBox(height: 14),
                Builder(
                  builder: (context) {
                    final isNarrow = MediaQuery.sizeOf(context).width < 380;
                    final boxMulai = _dialogTimeBox(
                      'Jam Mulai',
                      _jamMulai.format(context),
                      Icons.access_time_rounded,
                      () => _pickTime(true),
                    );
                    final boxSelesai = _dialogTimeBox(
                      'Jam Selesai',
                      _jamSelesai.format(context),
                      Icons.access_time_filled_rounded,
                      () => _pickTime(false),
                    );
                    if (isNarrow) {
                      return Column(
                        children: [
                          boxMulai,
                          const SizedBox(height: 10),
                          boxSelesai,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: boxMulai),
                        const SizedBox(width: 10),
                        Expanded(child: boxSelesai),
                      ],
                    );
                  },
                ),
              ],
              if (_errorText != null || invalidDuration) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText ??
                      'Jam selesai harus lebih lambat dari jam mulai.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _brown,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: invalidDuration ? null : _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }

  Widget _dialogTimeBox(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18, color: _brown),
          filled: true,
          fillColor: _cream,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
