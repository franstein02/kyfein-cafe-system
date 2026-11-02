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

class KasirJadwalScreen extends StatefulWidget {
  const KasirJadwalScreen({super.key});

  @override
  State<KasirJadwalScreen> createState() => _KasirJadwalScreenState();
}

class _KasirJadwalScreenState extends State<KasirJadwalScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _jadwal = [];

  Map<String, String> get _headers => context.read<AuthProvider>().authHeaders;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<Map<String, dynamic>> get _hariIni =>
      _jadwal.where((j) => j['tanggal'].toString() == _today).toList();

  List<Map<String, dynamic>> get _mendatang => _jadwal
      .where((j) => j['tanggal'].toString().compareTo(_today) >= 0)
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _short(dynamic t) {
    final s = (t ?? '').toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  String _ringkas(Map<String, dynamic> j) =>
      '${j['tanggal']} · ${(j['shift'] ?? '').toString().replaceAll('_', ' ')} · '
      '${_short(j['jam_mulai'])}–${_short(j['jam_selesai'])} · '
      '${(j['area_kerja'] ?? '').toString().toUpperCase()}';

  String _errorMsg(http.Response r) {
    try {
      final detail = jsonDecode(r.body)['detail'];
      if (detail is String) return detail;
      return 'Data tidak valid (${r.statusCode})';
    } catch (_) {
      return 'Gagal (${r.statusCode})';
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await http
          .get(Uri.parse('${ApiEndpoints.jadwal}/'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        _jadwal = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
      } else {
        _error = _errorMsg(r);
      }
    } catch (_) {
      _error = 'Tidak bisa terhubung ke server';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _kirim(String url, Map<String, dynamic> body, String sukses) async {
    try {
      final resp = await http
          .post(Uri.parse(url), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _snack(sukses);
        return true;
      }
      _snack(_errorMsg(resp));
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    }
    return false;
  }

  // ── Dialog bantu ───────────────────────────────────────────────────────────
  Future<String?> _inputAlasan(String title, {bool wajib = false}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Alasan', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _brown, foregroundColor: Colors.white),
            onPressed: () {
              if (wajib && c.text.trim().isEmpty) return;
              Navigator.pop(ctx, c.text.trim());
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _pilihShift(
      String title, List<Map<String, dynamic>> list) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title, style: const TextStyle(fontSize: 16)),
        children: list.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Tidak ada jadwal yang bisa dipilih'),
                )
              ]
            : list
                .map((j) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, j),
                      child: Text(_ringkas(j)),
                    ))
                .toList(),
      ),
    );
  }

  // ── Aksi pengajuan ─────────────────────────────────────────────────────────
  Future<void> _requestOff() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final alasan = await _inputAlasan(
        'Request Off · ${DateFormat('d MMM yyyy').format(d)}');
    if (alasan == null) return;
    await _kirim(
      ApiEndpoints.requestOff,
      {
        'tanggal': DateFormat('yyyy-MM-dd').format(d),
        'alasan': alasan.isEmpty ? null : alasan,
      },
      'Request off terkirim',
    );
  }

  Future<void> _tukarShift() async {
    final a = await _pilihShift('Pilih shift kamu yang mau ditukar', _mendatang);
    if (a == null || !mounted) return;

    List<Map<String, dynamic>> tersedia = [];
    try {
      final r = await http
          .get(
            Uri.parse('${ApiEndpoints.jadwalUntukTukar}?tanggal=${a['tanggal']}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) {
        _snack(_errorMsg(r));
        return;
      }
      tersedia = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
      return;
    }
    if (!mounted) return;

    final b = await _pilihShift(
        'Tukar dengan shift rekan (${a['tanggal']})', tersedia);
    if (b == null || !mounted) return;

    final alasan = await _inputAlasan('Alasan tukar shift');
    if (alasan == null) return;

    await _kirim(
      ApiEndpoints.tukarShift,
      {
        'shift_a_id': a['id'],
        'shift_b_id': b['id'],
        'karyawan_target_id': b['karyawan_id'],
        'alasan': alasan.isEmpty ? null : alasan,
      },
      'Pengajuan tukar shift terkirim',
    );
  }

  Future<void> _izinTelat() async {
    final s = await _pilihShift('Pilih shift yang akan telat', _mendatang);
    if (s == null || !mounted) return;
    final alasan = await _inputAlasan('Alasan izin telat', wajib: true);
    if (alasan == null) return;
    await _kirim(
      ApiEndpoints.izinTelat,
      {'jadwal_shift_id': s['id'], 'alasan': alasan},
      'Izin telat terkirim',
    );
  }

  void _izinTidakMasuk() {
    _snack('Izin tidak masuk butuh foto bukti, fitur upload foto menyusul');
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: Text('Jadwal Saya',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: _brown,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brown))
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  color: _brown,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHariIni(),
                            const SizedBox(height: 28),
                            _title('Form Pengajuan'),
                            const SizedBox(height: 12),
                            _buildRequestButtons(),
                            const SizedBox(height: 28),
                            _title('Jadwal Mendatang'),
                            const SizedBox(height: 12),
                            _buildMendatang(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _title(String t) => Text(
        t,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A1A),
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

  Widget _buildHariIni() {
    final list = _hariIni;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Jadwal Kerja Hari Ini'),
          const Divider(height: 24),
          if (list.isEmpty)
            const Text('Tidak ada jadwal hari ini',
                style: TextStyle(color: _textDim))
          else
            for (final j in list) ...[
              _infoRow(
                Icons.access_time_rounded,
                (j['shift'] ?? '').toString().replaceAll('_', ' ').toUpperCase(),
                '${_short(j['jam_mulai'])} – ${_short(j['jam_selesai'])}',
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.place_rounded, 'Area Kerja',
                  (j['area_kerja'] ?? '').toString().toUpperCase()),
            ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _brown.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _brown, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _textDim, fontSize: 12)),
            Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildMendatang() {
    final list = _mendatang;
    if (list.isEmpty) {
      return _card(
        child: const Text('Belum ada jadwal mendatang',
            style: TextStyle(color: _textDim)),
      );
    }
    return _card(
      child: Column(
        children: list
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
                  title: Text(j['tanggal'].toString(),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${(j['shift'] ?? '').toString().replaceAll('_', ' ')} · '
                    '${_short(j['jam_mulai'])}–${_short(j['jam_selesai'])} · '
                    '${(j['area_kerja'] ?? '').toString().toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: _textDim),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildRequestButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final buttons = [
          _requestButton(Icons.event_busy_rounded, 'Request Off', _requestOff),
          _requestButton(Icons.swap_horiz_rounded, 'Tukar Shift', _tukarShift),
          _requestButton(Icons.alarm_off_rounded, 'Izin Terlambat', _izinTelat),
          _requestButton(
              Icons.sick_rounded, 'Izin Tidak Masuk', _izinTidakMasuk),
        ];

        if (isNarrow) {
          return Column(
            children: [
              Row(children: [
                Expanded(child: buttons[0]),
                const SizedBox(width: 12),
                Expanded(child: buttons[1]),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: buttons[2]),
                const SizedBox(width: 12),
                Expanded(child: buttons[3]),
              ]),
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: buttons[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _requestButton(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brown,
          backgroundColor: Colors.white,
          side: BorderSide(color: _brown.withValues(alpha: 0.25)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        onPressed: onTap,
      ),
    );
  }
}