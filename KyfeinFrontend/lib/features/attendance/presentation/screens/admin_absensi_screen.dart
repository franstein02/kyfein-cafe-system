import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/widgets/page_refresh_scope.dart';
import '../../providers/attendance_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import '../widgets/map_lokasi_picker_dialog.dart';

const _brown = Color(0xFF1B4332);
const _cream = Color(0xFFF6F8F6);
const _textDim = Color(0xFF7A7A7A);

class AdminAbsensiScreen extends StatefulWidget {
  final int initialSection;

  const AdminAbsensiScreen({super.key, this.initialSection = 1});

  @override
  State<AdminAbsensiScreen> createState() => _AdminAbsensiScreenState();
}

class _AdminAbsensiScreenState extends State<AdminAbsensiScreen> {
  late int _currentSection;

  bool _loading = true;
  String? _error;

  // Lokasi Cafe
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  final MapController _previewMapController = MapController();
  bool _previewMapReady = false;
  bool _savingLocation = false;
  bool _fetchingGps = false;
  String? _lastUpdatedAt;

  // Rekap Absensi
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _absensiList = [];
  Map<String, String> _karyawanMap = {};

  Map<String, String> get _headers => context.read<AuthProvider>().authHeaders;

  @override
  void initState() {
    super.initState();
    _currentSection = widget.initialSection.clamp(0, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAll();
    });
  }

  @override
  void didUpdateWidget(covariant AdminAbsensiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      setState(() {
        _currentSection = widget.initialSection.clamp(0, 1);
      });
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _previewMapController.dispose();
    super.dispose();
  }

  LatLng get _currentLatLng {
    final lat = double.tryParse(_latController.text.trim()) ?? -7.83344070;
    final lng = double.tryParse(_lngController.text.trim()) ?? 112.00330990;
    return LatLng(lat.clamp(-85.0, 85.0), lng.clamp(-180.0, 180.0));
  }

  double get _currentRadiusMeter {
    final r = double.tryParse(_radiusController.text.trim()) ?? 100.0;
    return r > 0 ? r : 100.0;
  }

  void _syncPreviewMap() {
    if (!_previewMapReady) return;
    _previewMapController.move(_currentLatLng, _previewMapController.camera.zoom);
  }

  Future<void> _openMapPicker() async {
    final picked = await showDialog<LatLng>(
      context: context,
      builder: (_) => MapLokasiPickerDialog(
        initialCenter: _currentLatLng,
        radiusMeter: _currentRadiusMeter.round(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _latController.text = picked.latitude.toStringAsFixed(8);
      _lngController.text = picked.longitude.toStringAsFixed(8);
    });
    _syncPreviewMap();
    _snack('Titik koordinat dipilih dari peta. Tekan Simpan untuk menerapkan.');
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[800] : _brown,
      ),
    );
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

  String _fmtJam(dynamic dtStr, [String fallback = '-']) {
    if (dtStr == null) return fallback;
    final s = dtStr.toString();
    final parsed = DateTime.tryParse(s);
    if (parsed != null) {
      return DateFormat('HH:mm').format(parsed);
    }
    if (s.length >= 16) return s.substring(11, 16);
    if (s.length >= 5) return s.substring(0, 5);
    return s.isNotEmpty ? s : fallback;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final att = context.read<AttendanceProvider>();
    await att.loadAdminAbsensiData(dateStr);

    if (!mounted) return;
    setState(() {
      final loc = att.konfigurasiLokasi;
      if (loc != null) {
        _latController.text = (loc['latitude'] ?? '').toString();
        _lngController.text = (loc['longitude'] ?? '').toString();
        _radiusController.text = (loc['radius_meter'] ?? '').toString();
        _lastUpdatedAt = loc['updated_at']?.toString();
      }
      _karyawanMap = {
        for (var k in att.karyawan)
          k['id'].toString(): (k['nama'] ?? k['email'] ?? 'Karyawan').toString()
      };
      _absensiList = att.absensiList;
      _error = att.error;
      _loading = false;
    });
    _syncPreviewMap();
  }

  Future<void> _ambilGpsPerangkat() async {
    setState(() => _fetchingGps = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw 'Layanan lokasi (GPS) tidak aktif di perangkat ini';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'Izin akses lokasi perangkat ditolak';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latController.text = pos.latitude.toStringAsFixed(8);
        _lngController.text = pos.longitude.toStringAsFixed(8);
      });
      _syncPreviewMap();
      _snack('Koordinat GPS berhasil diambil dari posisi Anda saat ini');
    } catch (e) {
      _snack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  Future<void> _simpanLokasi() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim());

    if (lat == null || lng == null) {
      _snack('Format Latitude atau Longitude tidak valid', isError: true);
      return;
    }
    if (radius == null || radius <= 0) {
      _snack('Radius harus berupa angka lebih besar dari 0 meter', isError: true);
      return;
    }

    setState(() => _savingLocation = true);
    try {
      final res = await http.put(
        Uri.parse(ApiEndpoints.konfigurasiLokasi),
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': lat,
          'longitude': lng,
          'radius_meter': radius,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        _snack('Pengaturan titik lokasi & radius berhasil disimpan!');
        _loadAll();
      } else {
        _snack(_errorMsg(res), isError: true);
      }
    } catch (_) {
      _snack('Gagal menghubungi server', isError: true);
    } finally {
      if (mounted) setState(() => _savingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLokasi = _currentSection == 0;

    return PageRefreshRegistrar(
      onRefresh: _loadAll,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: buildStandaloneAppBar(
          context,
          title: isLokasi ? 'Titik & Radius GPS' : 'Monitoring Absensi',
          onRefresh: _loadAll,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _brown))
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    color: _brown,
                    onRefresh: _loadAll,
                    child: isLokasi
                        ? _buildTabSettingLokasi()
                        : _buildTabRekapAbsensi(),
                  ),
      ),
    );
  }

  // ── TAB 1: Setting Lokasi & Radius ─────────────────────────────────────────
  Widget _buildTabSettingLokasi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _brown.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.share_location_rounded,
                              color: _brown, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Titik Lokasi Cafe & Radius Absensi',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Karyawan hanya dapat melakukan absen masuk & pulang jika berada di dalam radius ini.',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: _textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),

                    // Pratinjau Peta Lokasi & Radius
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _cream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: _previewMapController,
                              options: MapOptions(
                                initialCenter: _currentLatLng,
                                initialZoom: 16,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                                onMapReady: () {
                                  _previewMapReady = true;
                                  _syncPreviewMap();
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.kyfein.app',
                                ),
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: _currentLatLng,
                                      radius: _currentRadiusMeter,
                                      useRadiusInMeter: true,
                                      color: _brown.withValues(alpha: 0.16),
                                      borderColor: _brown,
                                      borderStrokeWidth: 2,
                                    ),
                                  ],
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _currentLatLng,
                                      width: 40,
                                      height: 40,
                                      alignment: Alignment.topCenter,
                                      child: const Icon(
                                        Icons.location_on_rounded,
                                        color: Color(0xFFB91C1C),
                                        size: 36,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _openMapPicker,
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: Container(
                                      margin: const EdgeInsets.all(10),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _brown,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x26000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.edit_location_alt_rounded,
                                              color: Colors.white,
                                              size: 15),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Pilih di Peta',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    '© OpenStreetMap',
                                    style: TextStyle(
                                        fontSize: 9.5, color: Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action buttons: Pilih di Peta & Ambil GPS perangkat
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        final mapBtn = OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: _brown,
                            side: const BorderSide(color: _brown),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onPressed: _openMapPicker,
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: Text(
                            'Pilih Lokasi Lewat Peta',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        );

                        final gpsBtn = OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brown,
                            side: const BorderSide(color: _brown),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          onPressed: _fetchingGps ? null : _ambilGpsPerangkat,
                          icon: _fetchingGps
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: _brown),
                                )
                              : const Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            _fetchingGps
                                ? 'Mengambil Sinyal GPS...'
                                : 'Gunakan Lokasi GPS Saat Ini',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              mapBtn,
                              const SizedBox(height: 10),
                              gpsBtn,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: mapBtn),
                            const SizedBox(width: 12),
                            Expanded(child: gpsBtn),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Latitude & Longitude (Responsive)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        final latField = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Latitude',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _latController,
                              onChanged: (_) {
                                setState(() {});
                                _syncPreviewMap();
                              },
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                              decoration: InputDecoration(
                                hintText: '-7.82841199',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        );

                        final lngField = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Longitude',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _lngController,
                              onChanged: (_) {
                                setState(() {});
                                _syncPreviewMap();
                              },
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                              decoration: InputDecoration(
                                hintText: '111.99807238',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              latField,
                              const SizedBox(height: 12),
                              lngField,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: latField),
                            const SizedBox(width: 14),
                            Expanded(child: lngField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Radius Absensi
                    Text(
                      'Radius Toleransi Absensi (Meter)',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _radiusController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '100',
                        suffixText: 'meter',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Preset chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [25, 50, 100, 150, 200, 300].map((preset) {
                        return ActionChip(
                          label: Text('$preset m'),
                          backgroundColor: _cream,
                          labelStyle: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _brown,
                          ),
                          onPressed: () {
                            setState(() {
                              _radiusController.text = preset.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    if (_lastUpdatedAt != null) ...[
                      Text(
                        'Terakhir diperbarui: $_lastUpdatedAt',
                        style: GoogleFonts.outfit(fontSize: 11, color: _textDim),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brown,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _savingLocation ? null : _simpanLokasi,
                        icon: _savingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _savingLocation
                              ? 'Menyimpan...'
                              : 'Simpan Titik & Radius Lokasi',
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.amber.shade900, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Server backend secara ketat memverifikasi jarak koordinat GPS perangkat karyawan saat melakukan Absen Masuk / Pulang terhadap titik lokasi cafe di atas. Di luar batas radius, absensi otomatis ditolak server.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF6B4700),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB 2: Monitoring Rekap Absensi (Proses 34) ───────────────────────────
  Widget _buildTabRekapAbsensi() {
    final fmtDate = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_selectedDate);
    final att = context.watch<AttendanceProvider>();
    final jadwalIdsToday = att.allJadwal.map((j) => j['id'].toString()).toSet();

    final izinTelatToday = att.izinTelat
        .where((e) => jadwalIdsToday.isEmpty || jadwalIdsToday.contains(e['jadwal_shift_id']?.toString()))
        .toList();
    final izinTidakMasukToday = att.izinTidakMasuk
        .where((e) => jadwalIdsToday.isEmpty || jadwalIdsToday.contains(e['jadwal_shift_id']?.toString()))
        .toList();
    final tukarShiftList = att.tukarShift;

    final totalHadir = _absensiList.length;
    final totalTelat = _absensiList.where((a) => ((a['menit_telat'] ?? 0) as num) > 0).length;
    final totalSudahPulang = _absensiList.where((a) => a['jam_pulang'] != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Tanggal (Responsive Wrap to prevent overflow)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'Monitoring Absensi, Izin & Tukar Shift',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brown,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: _brown),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadAll();
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded, size: 16),
                    label: Text(
                      fmtDate,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Summary Chips (Proses 34)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSummaryBadge('Hadir Masuk', '$totalHadir', Colors.green.shade700),
                  _buildSummaryBadge('Absen Pulang', '$totalSudahPulang', Colors.teal.shade700),
                  _buildSummaryBadge('Terlambat', '$totalTelat', Colors.orange.shade800),
                  _buildSummaryBadge('Izin Telat', '${izinTelatToday.length}', Colors.amber.shade900),
                  _buildSummaryBadge('Tidak Masuk / Izin', '${izinTidakMasukToday.length}', Colors.red.shade700),
                  _buildSummaryBadge('Tukar Shift', '${tukarShiftList.length}', Colors.indigo.shade700),
                ],
              ),
              const SizedBox(height: 18),

              // 1. Daftar Absensi Masuk, Keterlambatan & Absensi Pulang
              Text(
                '1. Data Absensi Masuk, Keterlambatan & Absensi Pulang',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (_absensiList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.event_busy_rounded,
                          size: 36, color: _textDim),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada data absensi pada tanggal ini.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                            fontSize: 13.5, color: _textDim),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _absensiList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = _absensiList[i];
                    final nama = _karyawanMap[item['karyawan_id']] ?? 'Karyawan';
                    final masuk = _fmtJam(item['jam_masuk']);
                    final pulang = _fmtJam(item['jam_pulang'], 'Belum Pulang');
                    final menitTelat = item['menit_telat'] ?? 0;
                    final statusPulang = item['status_pulang'] ?? '-';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _brown.withValues(alpha: 0.1),
                            foregroundColor: _brown,
                            child: const Icon(Icons.person_rounded, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nama,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Masuk: $masuk  ·  Pulang: $pulang',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: _textDim),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: menitTelat > 0
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  menitTelat > 0
                                      ? 'Telat $menitTelat m'
                                      : 'Tepat Waktu',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: menitTelat > 0
                                        ? Colors.red.shade800
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Pulang: $statusPulang',
                                style: const TextStyle(
                                    fontSize: 10.5, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 22),

              // 2. Data Izin Keterlambatan & Izin Tidak Masuk (Ketidakhadiran)
              Text(
                '2. Data Izin Keterlambatan & Ketidakhadiran (Izin Tidak Masuk)',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (izinTelatToday.isEmpty && izinTidakMasukToday.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Tidak ada pengajuan izin keterlambatan maupun izin tidak masuk.',
                    style: GoogleFonts.outfit(fontSize: 13, color: _textDim),
                  ),
                )
              else ...[
                ...izinTelatToday.map((iz) {
                  final nama = _karyawanMap[iz['karyawan_id']] ?? 'Karyawan';
                  final st = (iz['status'] ?? 'pending').toString().toUpperCase();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: Colors.amber.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Izin Terlambat — $nama (${iz['estimasi_menit'] ?? 0} menit)\nAlasan: ${iz['alasan'] ?? "-"}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Chip(
                          label: Text(st, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                }),
                ...izinTidakMasukToday.map((iz) {
                  final nama = _karyawanMap[iz['karyawan_id']] ?? 'Karyawan';
                  final st = (iz['status'] ?? 'pending').toString().toUpperCase();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.medical_information_rounded, color: Colors.red.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Izin Tidak Masuk (${iz['jenis'] ?? "izin"}) — $nama\nKeterangan: ${iz['keterangan'] ?? "-"}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Chip(
                          label: Text(st, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 22),

              // 3. Data Pertukaran Shift Kasir
              Text(
                '3. Riwayat Pertukaran Shift Kasir',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (tukarShiftList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Belum ada riwayat pertukaran shift.',
                    style: GoogleFonts.outfit(fontSize: 13, color: _textDim),
                  ),
                )
              else
                ...tukarShiftList.map((ts) {
                  final pemohon = _karyawanMap[ts['pemohon_id']] ?? 'Kasir Pemohon';
                  final target = _karyawanMap[ts['target_id']] ?? 'Kasir Pengganti';
                  final st = (ts['status'] ?? 'pending').toString().toUpperCase();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz_rounded, color: Colors.indigo.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$pemohon ⇄ $target\nCatatan: ${ts['catatan'] ?? "-"}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        Chip(
                          label: Text(st, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
