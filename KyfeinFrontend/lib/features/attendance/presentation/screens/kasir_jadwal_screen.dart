import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kyfein_frontend/core/constants/api_endpoints.dart';
import 'package:kyfein_frontend/features/attendance/providers/attendance_provider.dart';
import 'package:kyfein_frontend/features/auth/providers/auth_provider.dart';

const _brown = Color(0xFF1B4332);
const _cream = Color(0xFFF6F8F6);
const _textDim = Color(0xFF7A7A7A);

class KasirJadwalScreen extends StatefulWidget {
  final int initialSection;
  const KasirJadwalScreen({super.key, this.initialSection = 0});

  @override
  State<KasirJadwalScreen> createState() => _KasirJadwalScreenState();
}

class _KasirJadwalScreenState extends State<KasirJadwalScreen> {
  final ImagePicker _picker = ImagePicker();
  late int _activeSection;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> _jadwal = [];
  List<Map<String, dynamic>> _requestOffs = [];
  List<Map<String, dynamic>> _tukarShifts = [];
  List<Map<String, dynamic>> _izinTelats = [];
  List<Map<String, dynamic>> _izinTidakMasuks = [];

  // Filter Jadwal Mendatang per Hari (null = Semua Hari, 'yyyy-MM-dd' = per hari)
  String? _filterTanggalJadwal =
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<String, String> get _headers => context.read<AuthProvider>().authHeaders;
  String? get _myUserId => context.read<AuthProvider>().karyawanId;

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<Map<String, dynamic>> get _hariIni =>
      _jadwal.where((j) => j['tanggal'].toString() == _today).toList();

  List<Map<String, dynamic>> get _mendatang => _jadwal
      .where((j) => j['tanggal'].toString().compareTo(_today) >= 0)
      .toList()
    ..sort((a, b) =>
        (a['tanggal'] ?? '').toString().compareTo((b['tanggal'] ?? '').toString()));

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
    if (short) {
      return tglStr == _today ? 'Hari Ini ($h, ${dt.day} $b)' : '$h, ${dt.day} $b';
    }
    return tglStr == _today
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
    for (final j in _mendatang) {
      final t = (j['tanggal'] ?? '').toString();
      if (t.isNotEmpty) setTanggal.add(t);
    }
    if (_filterTanggalJadwal != null && _filterTanggalJadwal!.isNotEmpty) {
      setTanggal.add(_filterTanggalJadwal!);
    }
    final list = setTanggal.toList()..sort();
    return list;
  }

  Future<void> _pickFilterTanggalJadwal() async {
    final initDt = (_filterTanggalJadwal != null
            ? DateTime.tryParse(_filterTanggalJadwal!)
            : null) ??
        DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initDt,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  List<Map<String, dynamic>> get _myRequestOffs {
    final uid = _myUserId;
    if (uid == null || uid.isEmpty) return _requestOffs;
    return _requestOffs
        .where((r) => r['karyawan_id']?.toString() == uid)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection;
    _load();
  }

  @override
  void didUpdateWidget(covariant KasirJadwalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() => _activeSection = widget.initialSection);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _short(dynamic t) {
    final s = (t ?? '').toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  String _ringkas(Map<String, dynamic> j) =>
      '${j['tanggal']} · ${(j['shift'] ?? '').toString().replaceAll('_', ' ').toUpperCase()} · '
      '${_short(j['jam_mulai'])}–${_short(j['jam_selesai'])} · '
      '${(j['area_kerja'] ?? '').toString().toUpperCase()}';

  String _ringkasByShiftId(dynamic shiftId) {
    final j = _jadwal.firstWhere(
      (e) => e['id'].toString() == shiftId.toString(),
      orElse: () => {},
    );
    if (j.isEmpty) return 'Shift ID: $shiftId';
    return _ringkas(j);
  }

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
    final att = context.read<AttendanceProvider>();
    await att.loadKasirJadwalData();
    if (!mounted) return;
    setState(() {
      _jadwal = att.allJadwal;
      _requestOffs = att.requestOff;
      _tukarShifts = att.tukarShift;
      _izinTelats = att.izinTelat;
      _izinTidakMasuks = att.izinTidakMasuk;
      _error = att.error;
      _loading = false;
    });
  }

  Future<bool> _kirim(
      String url, Map<String, dynamic> body, String sukses) async {
    setState(() => _submitting = true);
    try {
      final resp = await http
          .post(Uri.parse(url), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _snack(sukses);
        await _load();
        return true;
      }
      _snack(_errorMsg(resp));
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    return false;
  }

  Future<String> _uploadFotoIzin(XFile file) async {
    final bytes = await file.readAsBytes();
    final nama = file.name.toLowerCase();
    final tipe = nama.endsWith('.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');

    final req =
        http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/foto'));
    req.headers.addAll(_headers);
    req.headers.remove('Content-Type');
    req.fields['jenis'] = 'izin';
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: file.name.isNotEmpty ? file.name : 'bukti_izin.jpg',
      contentType: tipe,
    ));

    final res = await http.Response.fromStream(await req.send())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw _errorMsg(res);
    }
    final d = jsonDecode(res.body);
    final id = d is Map ? (d['id'] ?? d['foto_id']) : null;
    if (id == null) throw 'Gagal mendapatkan ID foto bukti';
    return id.toString();
  }

  // ── Dialog bantu ───────────────────────────────────────────────────────────
  Future<String?> _inputAlasan(String title, {bool wajib = false}) {
    final c = TextEditingController();
    String? errText;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 16)),
          content: TextField(
            controller: c,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: wajib ? 'Alasan (Wajib diisi)' : 'Alasan (Opsional)',
              errorText: errText,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _brown, foregroundColor: Colors.white),
              onPressed: () {
                if (wajib && c.text.trim().isEmpty) {
                  setDialogState(() => errText = 'Alasan wajib diisi');
                  return;
                }
                Navigator.pop(ctx, c.text.trim());
              },
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _inputAlasanDanFoto({
    required String title,
    required String shiftInfo,
    required bool wajibFoto,
  }) {
    final c = TextEditingController();
    XFile? pickedFile;
    String? errText;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _brown.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    shiftInfo,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _brown),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: c,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan (Wajib diisi)',
                    hintText: 'Contoh: Ban bocor / Sakit demam...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  wajibFoto
                      ? 'Foto Bukti (Wajib dilampirkan)'
                      : 'Foto Bukti (Opsional)',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        label: const Text('Kamera',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final f = await _picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 70,
                          );
                          if (f != null) {
                            setDialogState(() {
                              pickedFile = f;
                              errText = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library_rounded, size: 16),
                        label: const Text('Galeri',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final f = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (f != null) {
                            setDialogState(() {
                              pickedFile = f;
                              errText = null;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                if (pickedFile != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Foto terpilih: ${pickedFile!.name}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF10B981)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (errText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errText!,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brown,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (c.text.trim().isEmpty) {
                  setDialogState(() => errText = 'Alasan wajib diisi!');
                  return;
                }
                if (wajibFoto && pickedFile == null) {
                  setDialogState(() =>
                      errText = 'Foto bukti wajib dilampirkan untuk izin ini!');
                  return;
                }
                Navigator.pop(ctx, {
                  'alasan': c.text.trim(),
                  'file': pickedFile,
                });
              },
              child: const Text('Kirim Pengajuan'),
            ),
          ],
        ),
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
                  child: Text(
                      'Tidak ada jadwal aktif/mendatang yang bisa dipilih'),
                )
              ]
            : list
                .map((j) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, j),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(_ringkas(j)),
                      ),
                    ))
                .toList(),
      ),
    );
  }

  // ── Aksi pengajuan ─────────────────────────────────────────────────────────
  Future<void> _requestOff() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final tglStr = DateFormat('yyyy-MM-dd').format(d);

    final sudahAdaShift =
        _jadwal.any((j) => j['tanggal'].toString() == tglStr);
    if (sudahAdaShift) {
      _snack(
          'Anda sudah memiliki jadwal shift pada $tglStr. Gunakan Tukar Shift atau Izin Tidak Masuk.');
      return;
    }

    final alasan = await _inputAlasan(
      'Request Off · ${DateFormat('d MMM yyyy').format(d)}',
      wajib: true,
    );
    if (alasan == null) return;
    await _kirim(
      ApiEndpoints.requestOff,
      {
        'tanggal': tglStr,
        'alasan': alasan,
      },
      'Request off berhasil diajukan',
    );
  }

  Future<void> _batalkanRequestOff(String id) async {
    try {
      final resp = await http
          .delete(Uri.parse('${ApiEndpoints.requestOff}/$id'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        _snack('Request off dibatalkan');
        await _load();
      } else {
        _snack(_errorMsg(resp));
      }
    } catch (_) {
      _snack('Tidak bisa terhubung ke server');
    }
  }

  Future<void> _tukarShift() async {
    final a =
        await _pilihShift('Pilih shift Anda yang mau ditukar', _mendatang);
    if (a == null || !mounted) return;

    List<Map<String, dynamic>> tersedia = [];
    try {
      final r = await http
          .get(
            Uri.parse(
                '${ApiEndpoints.jadwalUntukTukar}?tanggal=${a['tanggal']}'),
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
        'Pilih shift rekan pada tanggal ${a['tanggal']}', tersedia);
    if (b == null || !mounted) return;

    final alasan = await _inputAlasan('Alasan tukar shift', wajib: true);
    if (alasan == null) return;

    await _kirim(
      ApiEndpoints.tukarShift,
      {
        'shift_a_id': a['id'],
        'shift_b_id': b['id'],
        'karyawan_target_id': b['karyawan_id'],
        'alasan': alasan,
      },
      'Pengajuan tukar shift terkirim ke Admin',
    );
  }

  Future<void> _izinTelat() async {
    final s =
        await _pilihShift('Pilih shift yang akan terlambat', _mendatang);
    if (s == null || !mounted) return;

    final form = await _inputAlasanDanFoto(
      title: 'Ajukan Izin Terlambat',
      shiftInfo: _ringkas(s),
      wajibFoto: false,
    );
    if (form == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      String? fotoId;
      final XFile? file = form['file'] as XFile?;
      if (file != null) {
        fotoId = await _uploadFotoIzin(file);
      }

      final body = <String, dynamic>{
        'jadwal_shift_id': s['id'],
        'alasan': form['alasan'],
      };
      if (fotoId != null) body['foto_id'] = fotoId;

      await _kirim(
        ApiEndpoints.izinTelat,
        body,
        'Pengajuan izin terlambat terkirim ke Admin',
      );
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _izinTidakMasuk() async {
    final s =
        await _pilihShift('Pilih shift yang tidak dapat dihadiri', _mendatang);
    if (s == null || !mounted) return;

    final form = await _inputAlasanDanFoto(
      title: 'Ajukan Izin Tidak Masuk',
      shiftInfo: _ringkas(s),
      wajibFoto: true,
    );
    if (form == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      final XFile file = form['file'] as XFile;
      final fotoId = await _uploadFotoIzin(file);

      await _kirim(
        ApiEndpoints.izinTidakMasuk,
        {
          'jadwal_shift_id': s['id'],
          'alasan': form['alasan'],
          'foto_id': fotoId,
        },
        'Pengajuan izin tidak masuk terkirim ke Admin',
      );
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE5EBE7))),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeSection == 0 ? 'Jadwal Kerja Saya' : 'Pengajuan Izin & Request Off',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D312E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activeSection == 0
                          ? 'Lihat jadwal shift hari ini, area kerja, dan jadwal mendatang'
                          : 'Ajukan request off, pertukaran shift, izin terlambat, atau izin tidak masuk',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5EBE7)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _activeSection,
                          isDense: true,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _brown),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2D312E),
                          ),
                          onChanged: (val) {
                            if (val != null) setState(() => _activeSection = val);
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month_rounded, size: 16, color: _brown),
                                  SizedBox(width: 8),
                                  Text('Jadwal Kerja Saya'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assignment_turned_in_rounded, size: 16, color: _brown),
                                  SizedBox(width: 8),
                                  Text('Pengajuan Izin & Off'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _load,
                      tooltip: 'Segarkan data',
                      style: IconButton.styleFrom(
                        backgroundColor: _cream,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFFE5EBE7)),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: _brown),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
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
                              constraints: const BoxConstraints(maxWidth: 780),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_submitting) ...[
                                    const LinearProgressIndicator(color: _brown),
                                    const SizedBox(height: 16),
                                  ],
                                  if (_activeSection == 0) ...[
                                    _buildHariIni(),
                                    const SizedBox(height: 24),
                                    _buildMendatang(),
                                  ] else ...[
                                    _title('Form Pengajuan Baru'),
                                    const SizedBox(height: 12),
                                    _buildRequestButtons(),
                                    const SizedBox(height: 28),
                                    _title('Status Pengajuan & Request Off Saya'),
                                    const SizedBox(height: 12),
                                    _buildRiwayatPengajuan(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
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

  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    String label;
    if (s == 'disetujui') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
      label = 'DISETUJUI';
    } else if (s == 'ditolak') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
      label = 'DITOLAK';
    } else {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
      label = 'MENUNGGU';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _textDim, fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMendatang() {
    final list = _mendatang;
    final tanggalChips = _pilihanTanggalFilter;
    final isSemua = _filterTanggalJadwal == null;

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    if (isSemua) {
      for (final j in list) {
        final t = (j['tanggal'] ?? '').toString();
        grouped.putIfAbsent(t, () => []).add(j);
      }
    } else {
      final tgl = _filterTanggalJadwal!;
      grouped[tgl] =
          list.where((j) => (j['tanggal'] ?? '').toString() == tgl).toList();
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Semua Hari (${list.length})'),
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
                final count = list
                    .where((j) => (j['tanggal'] ?? '').toString() == tgl)
                    .length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${_formatHariTanggal(tgl, short: true)}${count > 0 ? ' ($count)' : ''}',
                    ),
                    selected: selected,
                    selectedColor: _brown,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: selected || count > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: selected
                          ? Colors.white
                          : (count > 0 ? _brown : _textDim),
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
                    child: Text(
                      _formatHariTanggal(_filterTanggalJadwal!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _brown,
                      ),
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
        if (isSemua && list.isEmpty)
          _card(
            child: const Text('Belum ada jadwal mendatang',
                style: TextStyle(color: _textDim)),
          )
        else if (!isSemua && (grouped[_filterTanggalJadwal!] ?? []).isEmpty)
          _card(
            child: Text(
              'Tidak ada jadwal shift pada ${_formatHariTanggal(_filterTanggalJadwal!)}',
              style: const TextStyle(color: _textDim),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _brown.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.calendar_month_rounded,
                              color: _brown, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formatHariTanggal(tgl),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _brown,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    ...listHari.map((j) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: _brown, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${(j['shift'] ?? '').toString().replaceAll('_', ' ').toUpperCase()} · '
                                  '${_short(j['jam_mulai'])}–${_short(j['jam_selesai'])}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _brown.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (j['area_kerja'] ?? '')
                                      .toString()
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _brown,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRiwayatPengajuan() {
    final myOffs = _myRequestOffs;
    final hasAny = myOffs.isNotEmpty ||
        _izinTelats.isNotEmpty ||
        _izinTidakMasuks.isNotEmpty ||
        _tukarShifts.isNotEmpty;

    if (!hasAny) {
      return _card(
        child: const Text('Belum ada pengajuan izin atau request off',
            style: TextStyle(color: _textDim)),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in myOffs)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event_busy_rounded,
                  color: Colors.orange.shade800, size: 20),
              title: Text('Request Off · ${r['tanggal']}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                (r['alasan'] ?? '').toString().isNotEmpty
                    ? 'Alasan: ${r['alasan']}'
                    : 'Terdaftar libur (tidak dapat dijadwalkan)',
                style: const TextStyle(fontSize: 12, color: _textDim),
              ),
              trailing: IconButton(
                tooltip: 'Batalkan Request Off',
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade400, size: 20),
                onPressed: () => _batalkanRequestOff(r['id'].toString()),
              ),
            ),
          for (final it in _izinTelats)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.alarm_off_rounded,
                  color: Colors.amber.shade800, size: 20),
              title: Text(
                  'Izin Terlambat · ${_ringkasByShiftId(it['jadwal_shift_id'])}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('Alasan: ${it['alasan'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: _textDim)),
              trailing: _statusChip((it['status'] ?? 'pending').toString()),
            ),
          for (final itm in _izinTidakMasuks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.sick_rounded,
                  color: Colors.red.shade700, size: 20),
              title: Text(
                  'Izin Tidak Masuk · ${_ringkasByShiftId(itm['jadwal_shift_id'])}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('Alasan: ${itm['alasan'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: _textDim)),
              trailing: _statusChip((itm['status'] ?? 'pending').toString()),
            ),
          for (final ts in _tukarShifts)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz_rounded,
                  color: _brown, size: 20),
              title: Text(
                  'Tukar Shift · ${_ringkasByShiftId(ts['shift_a_id'])}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('Alasan: ${ts['alasan'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: _textDim)),
              trailing: _statusChip((ts['status'] ?? 'pending').toString()),
            ),
        ],
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
        onPressed: _submitting ? null : onTap,
      ),
    );
  }
}
