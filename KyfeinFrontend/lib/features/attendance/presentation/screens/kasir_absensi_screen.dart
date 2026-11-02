import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/storage_service.dart';

class KasirAbsensiScreen extends StatefulWidget {
  const KasirAbsensiScreen({super.key});

  @override
  State<KasirAbsensiScreen> createState() => _KasirAbsensiScreenState();
}

class _KasirAbsensiScreenState extends State<KasirAbsensiScreen> {
  final ApiClient _api = ApiClient();
  final StorageService _storage = StorageService();
  final ImagePicker _picker = ImagePicker();

  String? _absensiId;
  bool _loading = false;
  String _info = '';

  bool get _sudahMasuk => _absensiId != null;

  String get _base => ApiConfig.baseUrl;

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

  Future<String> _ambilShiftId() async {
    final res = await _api.get('$_base/jadwal/shift-aktif');
    if (res.statusCode != 200) {
      throw _pesanError(res.body, res.statusCode);
    }
    var data = jsonDecode(res.body);
    if (data is List && data.isNotEmpty) data = data.first;
    if (data is Map && data['id'] != null) return data['id'].toString();
    throw 'Tidak ada shift berjalan saat ini';
  }

  Future<String> _unggahFoto() async {
    final file = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 70);
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
    req.fields['jenis'] = 'absensi';
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: file.name,
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
    setState(() => _loading = true);
    try {
      final shiftId = await _ambilShiftId();
      final pos = await _ambilLokasi();
      final fotoId = await _unggahFoto();

      final res = await _api.post('$_base/absensi/masuk', body: {
        'jadwal_shift_id': shiftId,
        'lat_masuk': pos.latitude,
        'lng_masuk': pos.longitude,
        'foto_masuk_id': fotoId,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final d = jsonDecode(res.body);
        setState(() {
          _absensiId = d['id'].toString();
          _info = 'Masuk: ${d['jam_masuk']} (telat ${d['menit_telat']} menit)\n'
              'Lokasi: ${pos.latitude.toStringAsFixed(6)}, '
              '${pos.longitude.toStringAsFixed(6)}';
        });
        _snack('Absen masuk berhasil');
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
      _snack('Belum absen masuk pada sesi ini');
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
        final d = jsonDecode(res.body);
        setState(() {
          _info = 'Pulang: ${d['jam_pulang']} (${d['status_pulang']})';
          _absensiId = null;
        });
        _snack('Absen pulang berhasil');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi Saya'),
        backgroundColor: const Color(0xFF1B4332),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Status Absen: ${_sudahMasuk ? 'Sudah Masuk' : 'Belum Absen'}',
                        style: const TextStyle(fontSize: 16)),
                    if (_info.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_info),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.location_on),
                    label: const Text('ABSEN MASUK (GPS)'),
                    onPressed: _loading || _sudahMasuk ? null : _absenMasuk,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    icon: const Icon(Icons.logout),
                    label: const Text('ABSEN PULANG'),
                    onPressed: _loading || !_sudahMasuk ? null : _absenPulang,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}