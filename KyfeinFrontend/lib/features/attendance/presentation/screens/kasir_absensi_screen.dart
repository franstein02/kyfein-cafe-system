import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/page_refresh_scope.dart';
import '../../../dashboard/providers/dashboard_provider.dart';

class KasirAbsensiScreen extends StatefulWidget {
  const KasirAbsensiScreen({super.key});

  @override
  State<KasirAbsensiScreen> createState() => _KasirAbsensiScreenState();
}

class _KasirAbsensiScreenState extends State<KasirAbsensiScreen> {
  final ApiClient _api = ApiClient();
  final StorageService _storage = StorageService();
  final ImagePicker _picker = ImagePicker();

  static const Color _primary = Color(0xFF1B4332);

  bool _loading = false;
  bool _fetching = true;
  String _info = '';

  bool _hasShift = false;
  String? _shiftId;
  String? _shiftName;
  String? _areaKerja;
  String? _jamMulai;
  String? _jamSelesai;

  String? _absensiId;
  bool _sudahMasuk = false;
  bool _sudahPulang = false;
  String? _jamMasuk;
  String? _jamPulang;
  int _menitTelat = 0;
  String? _statusPulang;

  Map<String, dynamic>? _izinTelat;
  Map<String, dynamic>? _izinTidakMasuk;

  String get _base => ApiConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _muatStatusAbsensi();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _pesanError(String body, int status) {
    try {
      final d = jsonDecode(body);
      if (d is Map && d['detail'] != null) {
        final detail = d['detail'];
        return detail is String ? detail : detail.toString();
      }
    } catch (_) {}
    return 'Gagal ($status)';
  }

  String _formatJam(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoStr);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      final parts = isoStr.split('T');
      if (parts.length > 1) {
        final timePart = parts[1].split('.')[0];
        final sub = timePart.split(':');
        if (sub.length >= 2) return '${sub[0]}:${sub[1]}';
      }
      return isoStr;
    }
  }

  Future<void> _muatStatusAbsensi() async {
    setState(() => _fetching = true);
    try {
      final res = await _api.get(ApiEndpoints.absensiStatus);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final hasShift = d['has_shift'] == true;
        final sudahMasuk = d['sudah_masuk'] == true;
        final sudahPulang = d['sudah_pulang'] == true;
        final abs = d['absensi'] is Map
            ? d['absensi'] as Map<String, dynamic>
            : null;
        final izTelat = d['izin_telat'] is Map
            ? d['izin_telat'] as Map<String, dynamic>
            : null;
        final izTm = d['izin_tidak_masuk'] is Map
            ? d['izin_tidak_masuk'] as Map<String, dynamic>
            : null;

        setState(() {
          _hasShift = hasShift;
          _shiftId = d['shift_id']?.toString();
          _shiftName = d['shift']?.toString();
          _areaKerja = d['area_kerja']?.toString();
          _jamMulai = d['jam_mulai']?.toString();
          _jamSelesai = d['jam_selesai']?.toString();

          _sudahMasuk = sudahMasuk;
          _sudahPulang = sudahPulang;
          _absensiId = abs?['id']?.toString();
          _jamMasuk = abs?['jam_masuk']?.toString();
          _jamPulang = abs?['jam_pulang']?.toString();
          _menitTelat = abs?['menit_telat'] is int ? abs!['menit_telat'] : 0;
          _statusPulang = abs?['status_pulang']?.toString();

          _izinTelat = izTelat;
          _izinTidakMasuk = izTm;

          if (sudahPulang) {
            _info = 'Shift selesai. Jam Pulang: ${_formatJam(_jamPulang)}';
          } else if (sudahMasuk) {
            _info = 'Jam Masuk: ${_formatJam(_jamMasuk)}'
                '${_menitTelat > 0 ? " (terlambat $_menitTelat menit)" : " (tepat waktu)"}';
          } else if (izTm != null && izTm['status'] == 'disetujui') {
            _info =
                'Izin Tidak Masuk Anda untuk shift ini telah DISETUJUI oleh Admin.';
          } else if (hasShift) {
            _info =
                'Silakan absen masuk menggunakan foto & GPS saat mulai bekerja.';
          } else {
            _info = 'Tidak ada shift berjalan untuk Anda saat ini.';
          }
        });
      }
    } catch (e) {
      debugPrint('Error _muatStatusAbsensi: $e');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<Position> _ambilLokasi() async {
    final aktif = await Geolocator.isLocationServiceEnabled();
    if (!aktif) throw 'Layanan lokasi tidak aktif';
    var izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
    }
    if (izin == LocationPermission.denied ||
        izin == LocationPermission.deniedForever) {
      throw 'Izin lokasi ditolak';
    }
    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<String> _unggahFoto({
    String jenis = 'absensi',
    XFile? customFile,
  }) async {
    final file = customFile ??
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (file == null) throw 'Foto belum dipilih';
    final bytes = await file.readAsBytes();
    final nama = file.name.toLowerCase();
    final tipe = nama.endsWith('.png')
        ? MediaType('image', 'png')
        : MediaType('image', 'jpeg');

    final token = await _storage.getToken();
    final req = http.MultipartRequest('POST', Uri.parse('$_base/foto'));
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['jenis'] = jenis;
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: file.name.isNotEmpty ? file.name : 'foto.jpg',
      contentType: tipe,
    ));
    final res = await http.Response.fromStream(await req.send());

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw 'Unggah foto gagal: ${_pesanError(res.body, res.statusCode)}';
    }
    final d = jsonDecode(res.body);
    final id = d is Map ? (d['id'] ?? d['foto_id']) : null;
    if (id == null) throw 'Respons foto tidak berisi id: ${res.body}';
    return id.toString();
  }

  Future<void> _absenMasuk() async {
    if (_shiftId == null) {
      _snack('Tidak ada shift aktif');
      return;
    }
    setState(() => _loading = true);
    try {
      final pos = await _ambilLokasi();
      final fotoId = await _unggahFoto(jenis: 'absensi');

      final res = await _api.post('$_base/absensi/masuk', body: {
        'jadwal_shift_id': _shiftId,
        'lat_masuk': pos.latitude,
        'lng_masuk': pos.longitude,
        'foto_masuk_id': fotoId,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack('Absen masuk berhasil');
        await _muatStatusAbsensi();
        if (mounted) {
          try {
            await context.read<DashboardProvider>().refresh();
          } catch (_) {}
        }
      } else {
        _snack(_pesanError(res.body, res.statusCode));
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _absenPulang() async {
    if (_absensiId == null) {
      _snack('Data absensi masuk tidak ditemukan');
      return;
    }
    setState(() => _loading = true);
    try {
      final pos = await _ambilLokasi();
      final res = await _api.post('$_base/absensi/$_absensiId/pulang', body: {
        'lat_pulang': pos.latitude,
        'lng_pulang': pos.longitude,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack('Absen pulang berhasil');
        await _muatStatusAbsensi();
        if (mounted) {
          try {
            await context.read<DashboardProvider>().refresh();
          } catch (_) {}
        }
      } else {
        _snack(_pesanError(res.body, res.statusCode));
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _dialogFormIzin({
    required String title,
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
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: c,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan (Wajib diisi)',
                    hintText: 'Tuliskan alasan Anda...',
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
                  Text(
                    '✓ Foto: ${pickedFile!.name}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600),
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
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (c.text.trim().isEmpty) {
                  setDialogState(() => errText = 'Alasan wajib diisi');
                  return;
                }
                if (wajibFoto && pickedFile == null) {
                  setDialogState(
                      () => errText = 'Foto bukti wajib dilampirkan');
                  return;
                }
                Navigator.pop(ctx, {
                  'alasan': c.text.trim(),
                  'file': pickedFile,
                });
              },
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ajukanIzinTelat() async {
    if (_shiftId == null) return;
    final form = await _dialogFormIzin(
      title: 'Ajukan Izin Terlambat',
      wajibFoto: false,
    );
    if (form == null) return;

    setState(() => _loading = true);
    try {
      String? fotoId;
      final XFile? file = form['file'] as XFile?;
      if (file != null) {
        fotoId = await _unggahFoto(jenis: 'izin', customFile: file);
      }
      final body = <String, dynamic>{
        'jadwal_shift_id': _shiftId,
        'alasan': form['alasan'],
      };
      if (fotoId != null) body['foto_id'] = fotoId;

      final res = await _api.post(ApiEndpoints.izinTelat, body: body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack('Pengajuan izin terlambat berhasil dikirim');
        await _muatStatusAbsensi();
      } else {
        _snack(_pesanError(res.body, res.statusCode));
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ajukanIzinTidakMasuk() async {
    if (_shiftId == null) return;
    final form = await _dialogFormIzin(
      title: 'Ajukan Izin Tidak Masuk',
      wajibFoto: true,
    );
    if (form == null) return;

    setState(() => _loading = true);
    try {
      final XFile file = form['file'] as XFile;
      final fotoId = await _unggahFoto(jenis: 'izin', customFile: file);

      final res = await _api.post(ApiEndpoints.izinTidakMasuk, body: {
        'jadwal_shift_id': _shiftId,
        'alasan': form['alasan'],
        'foto_id': fotoId,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack('Pengajuan izin tidak masuk berhasil dikirim');
        await _muatStatusAbsensi();
      } else {
        _snack(_pesanError(res.body, res.statusCode));
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageRefreshRegistrar(
      onRefresh: _muatStatusAbsensi,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8F6),
        appBar: buildStandaloneAppBar(
          context,
          title: 'Absensi Masuk & Pulang',
          onRefresh: _muatStatusAbsensi,
        ),
        body: RefreshIndicator(
          onRefresh: _muatStatusAbsensi,
          color: _primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_fetching)
                          const LinearProgressIndicator(color: _primary)
                        else if (_loading)
                          const LinearProgressIndicator(color: Colors.amber),
                        const SizedBox(height: 8),

                        // Card Shift & Status
                        _buildStatusCard(),

                        const SizedBox(height: 24),

                        // Tombol Aksi Utama (Absen Masuk / Pulang)
                        _buildActionButtons(),

                        // Tombol Pintas Pengajuan Izin (Jika belum absen masuk)
                        if (_hasShift && !_sudahMasuk) ...[
                          const SizedBox(height: 16),
                          _buildIzinShortcutButtons(),
                        ],

                        // Status Izin pada Shift Ini (Jika ada)
                        if (_izinTelat != null || _izinTidakMasuk != null) ...[
                          const SizedBox(height: 20),
                          _buildStatusIzinCard(),
                        ],

                        const SizedBox(height: 24),

                        // Card Detail Riwayat Shift Ini
                        if (_sudahMasuk) _buildDetailRiwayatCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color badgeBg;
    Color badgeText;
    String badgeLabel;
    IconData badgeIcon;

    if (!_hasShift) {
      badgeBg = Colors.grey.shade200;
      badgeText = Colors.grey.shade700;
      badgeLabel = 'Tidak Ada Shift';
      badgeIcon = Icons.event_busy_rounded;
    } else if (_sudahPulang) {
      badgeBg = Colors.blue.shade50;
      badgeText = Colors.blue.shade700;
      badgeLabel = 'Shift Selesai (Sudah Pulang)';
      badgeIcon = Icons.task_alt_rounded;
    } else if (_sudahMasuk) {
      badgeBg = Colors.green.shade50;
      badgeText = Colors.green.shade700;
      badgeLabel = 'Sedang Bekerja';
      badgeIcon = Icons.badge_rounded;
    } else if (_izinTidakMasuk != null &&
        _izinTidakMasuk!['status'] == 'disetujui') {
      badgeBg = Colors.purple.shade50;
      badgeText = Colors.purple.shade700;
      badgeLabel = 'Izin Disetujui';
      badgeIcon = Icons.verified_rounded;
    } else {
      badgeBg = Colors.orange.shade50;
      badgeText = Colors.orange.shade800;
      badgeLabel = 'Belum Absen Masuk';
      badgeIcon = Icons.pending_actions_rounded;
    }

    final shiftTitle = _shiftName != null
        ? _shiftName!.replaceAll('_', ' ').toUpperCase()
        : 'SHIFT';
    final areaTitle = _areaKerja != null ? _areaKerja!.toUpperCase() : '-';
    final jamStr = (_jamMulai != null && _jamSelesai != null)
        ? '$_jamMulai – $_jamSelesai'
        : '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Shift Hari Ini',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeText.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeText),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          badgeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$shiftTitle ($areaTitle)',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                jamStr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: _sudahMasuk
                    ? Colors.green.shade700
                    : Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _info,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool izinTmApproved =
        _izinTidakMasuk != null && _izinTidakMasuk!['status'] == 'disetujui';
    final bool bolehMasuk = !_loading &&
        !_fetching &&
        _hasShift &&
        !_sudahMasuk &&
        !izinTmApproved;
    final bool bolehPulang =
        !_loading && !_fetching && _sudahMasuk && !_sudahPulang;

    return Row(
      children: [
        // Tombol Absen Masuk
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _sudahMasuk
                  ? Colors.grey.shade400
                  : const Color(0xFF10B981),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: bolehMasuk ? 2 : 0,
            ),
            icon: Icon(
              _sudahMasuk
                  ? Icons.check_circle_rounded
                  : Icons.my_location_rounded,
              size: 18,
            ),
            label: Text(
              _sudahMasuk ? 'SUDAH MASUK' : 'ABSEN MASUK',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: bolehMasuk ? _absenMasuk : null,
          ),
        ),
        const SizedBox(width: 12),

        // Tombol Absen Pulang
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _sudahPulang
                  ? Colors.grey.shade400
                  : const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: bolehPulang ? 2 : 0,
            ),
            icon: Icon(
              _sudahPulang ? Icons.task_alt_rounded : Icons.logout_rounded,
              size: 18,
            ),
            label: Text(
              _sudahPulang ? 'SUDAH PULANG' : 'ABSEN PULANG',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: bolehPulang ? _absenPulang : null,
          ),
        ),
      ],
    );
  }

  Widget _buildIzinShortcutButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              backgroundColor: Colors.white,
              side: BorderSide(color: _primary.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.alarm_off_rounded, size: 17),
            label: const Text(
              'Izin Terlambat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed:
                _loading || _fetching ? null : _ajukanIzinTelat,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.sick_rounded, size: 17),
            label: const Text(
              'Izin Tidak Masuk',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed:
                _loading || _fetching ? null : _ajukanIzinTidakMasuk,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIzinCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengajuan Izin Shift Ini',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (_izinTelat != null)
            _detailRow(
              icon: Icons.alarm_off_rounded,
              color: Colors.amber.shade800,
              title: 'Izin Terlambat',
              val: 'Alasan: ${_izinTelat!['alasan'] ?? '-'}',
              subtitle:
                  (_izinTelat!['status'] ?? 'pending').toString().toUpperCase(),
            ),
          if (_izinTelat != null && _izinTidakMasuk != null)
            const Divider(height: 20),
          if (_izinTidakMasuk != null)
            _detailRow(
              icon: Icons.sick_rounded,
              color: Colors.red.shade700,
              title: 'Izin Tidak Masuk',
              val: 'Alasan: ${_izinTidakMasuk!['alasan'] ?? '-'}',
              subtitle: (_izinTidakMasuk!['status'] ?? 'pending')
                  .toString()
                  .toUpperCase(),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRiwayatCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catatan Presensi Shift Ini',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _detailRow(
            icon: Icons.login_rounded,
            color: Colors.green,
            title: 'Waktu Absen Masuk',
            val: _formatJam(_jamMasuk),
            subtitle: _menitTelat > 0
                ? 'Terlambat $_menitTelat menit'
                : 'Tepat Waktu',
          ),
          if (_sudahPulang) ...[
            const Divider(height: 20),
            _detailRow(
              icon: Icons.logout_rounded,
              color: Colors.blue,
              title: 'Waktu Absen Pulang',
              val: _formatJam(_jamPulang),
              subtitle: _statusPulang != null
                  ? 'Status: ${_statusPulang!.replaceAll('_', ' ')}'
                  : 'Selesai',
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required Color color,
    required String title,
    required String val,
    required String subtitle,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              Text(val,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            subtitle,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
