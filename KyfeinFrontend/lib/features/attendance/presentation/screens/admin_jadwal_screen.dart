import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kyfein_frontend/core/constants/api_endpoints.dart';
import 'package:kyfein_frontend/features/auth/providers/auth_provider.dart';

const _brown = Color(0xFF1B4332);
const _cream = Color(0xFFE9F5E6);
const _textDim = Color(0xFF7A7A7A);

class AdminJadwalScreen extends StatefulWidget {
  const AdminJadwalScreen({super.key});

  @override
  State<AdminJadwalScreen> createState() => _AdminJadwalScreenState();
}

class _AdminJadwalScreenState extends State<AdminJadwalScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  List<Map<String, dynamic>> _karyawan = [];
  List<Map<String, dynamic>> _jadwal = [];
  List<Map<String, dynamic>> _tukar = [];

  // Form
  String? _karyawanId;
  DateTime _tanggal = DateTime.now();
  String _shift = 'shift_1';
  String _area = 'kasir';
  TimeOfDay _jamMulai = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _jamSelesai = const TimeOfDay(hour: 16, minute: 0);

  Map<String, String> get _headers => context.read<AuthProvider>().authHeaders;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _short(dynamic t) {
    final s = (t ?? '').toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  String _namaKaryawan(dynamic id) {
    final k = _karyawan.firstWhere(
      (e) => e['id'].toString() == id.toString(),
      orElse: () => {},
    );
    return (k['nama'] ?? k['nama_lengkap'] ?? k['email'] ?? 'Karyawan').toString();
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
    try {
      final res = await Future.wait([
        http.get(Uri.parse('${ApiEndpoints.karyawan}/'), headers: _headers),
        http.get(Uri.parse('${ApiEndpoints.jadwal}/'), headers: _headers),
        http.get(Uri.parse('${ApiEndpoints.tukarShift}?status=pending'),
            headers: _headers),
      ]).timeout(const Duration(seconds: 10));

      if (res[0].statusCode == 200) {
        final list = (jsonDecode(res[0].body) as List)
            .cast<Map<String, dynamic>>()
            .where((e) => e['status_aktif'] != false && e['role'] == 'karyawan')
            .toList();
        _karyawan = list;
      }
      if (res[1].statusCode == 200) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _jadwal = (jsonDecode(res[1].body) as List)
            .cast<Map<String, dynamic>>()
            .where((e) => (e['tanggal'] ?? '').toString().compareTo(today) >= 0)
            .toList();
      }
      if (res[2].statusCode == 200) {
        _tukar = (jsonDecode(res[2].body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _loadError = 'Gagal memuat data: cek koneksi ke server';
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _simpan() async {
    if (_karyawanId == null) {
      _snack('Pilih karyawan dulu');
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
              'tanggal': DateFormat('yyyy-MM-dd').format(_tanggal),
              'shift': _shift,
              'area_kerja': _area,
              'jam_mulai': _fmtTime(_jamMulai),
              'jam_selesai': _fmtTime(_jamSelesai),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
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

  Future<void> _prosesTukar(String id, String status) async {
    try {
      final resp = await http
          .put(
            Uri.parse('${ApiEndpoints.tukarShift}/$id/approval'),
            headers: _headers,
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _snack(status == 'disetujui' ? 'Tukar shift disetujui' : 'Tukar shift ditolak');
        await _loadAll();
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    }
  }

  Future<void> _pickTanggal() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _tanggal = d);
  }

  Future<void> _pickJam(bool mulai) async {
    final t = await showTimePicker(
      context: context,
      initialTime: mulai ? _jamMulai : _jamSelesai,
    );
    if (t != null) {
      setState(() => mulai ? _jamMulai = t : _jamSelesai = t);
    }
  }

  void _onShiftChanged(String? v) {
    if (v == null) return;
    setState(() {
      _shift = v;
      if (v == 'shift_1') {
        _jamMulai = const TimeOfDay(hour: 8, minute: 0);
        _jamSelesai = const TimeOfDay(hour: 16, minute: 0);
      } else {
        _jamMulai = const TimeOfDay(hour: 16, minute: 0);
        _jamSelesai = const TimeOfDay(hour: 23, minute: 0);
      }
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          title: Text('Kelola Jadwal',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          backgroundColor: _brown,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadAll,
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              const Tab(text: 'Atur Jadwal'),
              Tab(text: 'Approval (${_tukar.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _brown))
            : _loadError != null
                ? Center(child: Text(_loadError!))
                : TabBarView(
                    children: [_buildTabJadwal(), _buildTabApproval()],
                  ),
      ),
    );
  }

  Widget _wrap(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: child,
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
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

  Widget _pickerBox(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(label),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _brown),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabJadwal() {
    return _wrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('Penugasan Shift & Area Kerja'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _karyawanId,
                  isExpanded: true,
                  decoration: _dec('Pilih Karyawan'),
                  items: _karyawan
                      .map((k) => DropdownMenuItem(
                            value: k['id'].toString(),
                            child: Text(
                                (k['nama'] ?? k['nama_lengkap'] ?? k['email'] ?? '-')
                                    .toString()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _karyawanId = v),
                ),
                const SizedBox(height: 12),
                _pickerBox(
                  'Tanggal',
                  DateFormat('EEE, d MMM yyyy').format(_tanggal),
                  Icons.event_rounded,
                  _pickTanggal,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _shift,
                        decoration: _dec('Shift'),
                        items: const [
                          DropdownMenuItem(value: 'shift_1', child: Text('Shift 1')),
                          DropdownMenuItem(value: 'shift_2', child: Text('Shift 2')),
                        ],
                        onChanged: _onShiftChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _area,
                        decoration: _dec('Area Kerja'),
                        items: const [
                          DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
                          DropdownMenuItem(value: 'bar', child: Text('Bar')),
                          DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')),
                        ],
                        onChanged: (v) => setState(() => _area = v ?? 'kasir'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _pickerBox('Jam Mulai', _jamMulai.format(context),
                          Icons.access_time_rounded, () => _pickJam(true)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerBox('Jam Selesai', _jamSelesai.format(context),
                          Icons.access_time_filled_rounded, () => _pickJam(false)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                    onPressed: _saving ? null : _simpan,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Simpan Jadwal'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _title('Jadwal Mendatang'),
          const SizedBox(height: 12),
          if (_jadwal.isEmpty)
            _card(
              child: const Text('Belum ada jadwal mendatang',
                  style: TextStyle(color: _textDim)),
            )
          else
            _card(
              child: Column(
                children: _jadwal
                    .map((j) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _brown.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_month_rounded,
                                color: _brown, size: 18),
                          ),
                          title: Text(_namaKaryawan(j['karyawan_id']),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${j['tanggal']} · ${(j['shift'] ?? '').toString().replaceAll('_', ' ')} · '
                            '${_short(j['jam_mulai'])}–${_short(j['jam_selesai'])} · '
                            '${(j['area_kerja'] ?? '').toString().toUpperCase()}',
                            style: const TextStyle(fontSize: 12, color: _textDim),
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabApproval() {
    return _wrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Pengajuan Tukar Shift'),
          const SizedBox(height: 12),
          if (_tukar.isEmpty)
            _card(
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 12),
                  Text('Tidak ada pengajuan menunggu',
                      style: TextStyle(color: _textDim)),
                ],
              ),
            )
          else
            _card(
              child: Column(
                children: _tukar.map((t) {
                  final shiftA = _jadwal.firstWhere(
                    (j) => j['id'].toString() == t['shift_a_id'].toString(),
                    orElse: () => {},
                  );
                  final tgl = shiftA['tanggal'] ?? '-';
                  final alasan = (t['alasan'] ?? '').toString();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${_namaKaryawan(t['karyawan_pengaju_id'])}  ⇄  ${_namaKaryawan(t['karyawan_target_id'])}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Tanggal: $tgl${alasan.isNotEmpty ? '\nAlasan: $alasan' : ''}',
                      style: const TextStyle(fontSize: 12, color: _textDim),
                    ),
                    isThreeLine: alasan.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Setujui',
                          icon: const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF10B981)),
                          onPressed: () =>
                              _prosesTukar(t['id'].toString(), 'disetujui'),
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
        ],
      ),
    );
  }
}