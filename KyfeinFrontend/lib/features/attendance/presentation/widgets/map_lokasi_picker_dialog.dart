import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const _primaryGreen = Color(0xFF1B4332);
const _surfaceTint = Color(0xFFF6F8F6);

class MapLokasiPickerDialog extends StatefulWidget {
  final LatLng initialCenter;
  final int radiusMeter;

  const MapLokasiPickerDialog({
    super.key,
    required this.initialCenter,
    required this.radiusMeter,
  });

  @override
  State<MapLokasiPickerDialog> createState() => _MapLokasiPickerDialogState();
}

class _MapLokasiPickerDialogState extends State<MapLokasiPickerDialog> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  late LatLng _selectedPoint;
  bool _mapReady = false;
  bool _searching = false;
  bool _fetchingGps = false;
  String? _searchError;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialCenter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _moveCamera(LatLng target, {double? zoom}) {
    if (!_mapReady) return;
    _mapController.move(target, zoom ?? _mapController.camera.zoom);
  }

  Future<void> _searchPlace() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '5',
        'addressdetails': '1',
      });
      final res = await http.get(
        uri,
        headers: const {'User-Agent': 'KyfeinApp/1.0 (attendance-geofence)'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) {
          final parsed = <Map<String, dynamic>>[];
          for (final item in decoded) {
            if (item is Map) {
              final lat = double.tryParse((item['lat'] ?? '').toString());
              final lon = double.tryParse((item['lon'] ?? '').toString());
              if (lat != null && lon != null) {
                parsed.add({
                  'name': (item['display_name'] ?? 'Lokasi ditemukan').toString(),
                  'lat': lat,
                  'lon': lon,
                });
              }
            }
          }
          setState(() {
            _searchResults = parsed;
            if (parsed.isEmpty) {
              _searchError = 'Lokasi "$query" tidak ditemukan.';
            }
          });
          return;
        }
      }
      setState(() => _searchError = 'Pencarian peta sedang tidak tersedia.');
    } catch (_) {
      if (mounted) {
        setState(() => _searchError = 'Gagal mencari lokasi (periksa internet).');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentGps() async {
    setState(() {
      _fetchingGps = true;
      _searchError = null;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw 'Layanan GPS tidak aktif';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Izin lokasi ditolak';
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final target = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _selectedPoint = target;
        _searchResults = [];
      });
      _moveCamera(target, zoom: 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radiusMeter =
        widget.radiusMeter > 0 ? widget.radiusMeter.toDouble() : 50.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              color: _primaryGreen,
              child: Row(
                children: [
                  const Icon(Icons.add_location_alt_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Titik Lokasi Cafe di Peta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Ketuk peta atau cari alamat untuk menentukan posisi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
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
            ),

            // Search bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchPlace(),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Cari alamat / nama jalan / cafe...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _searchError = null;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: _surfaceTint,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _searching ? null : _searchPlace,
                    child: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Cari'),
                  ),
                ],
              ),
            ),

            if (_searchError != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: Colors.amber.shade50,
                child: Text(
                  _searchError!,
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ),

            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 145),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, idx) {
                    final r = _searchResults[idx];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined,
                          size: 18, color: _primaryGreen),
                      title: Text(
                        r['name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      onTap: () {
                        final target = LatLng(
                          r['lat'] as double,
                          r['lon'] as double,
                        );
                        setState(() {
                          _selectedPoint = target;
                          _searchResults = [];
                        });
                        _moveCamera(target, zoom: 17);
                      },
                    );
                  },
                ),
              ),

            // Interactive Map
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedPoint,
                      initialZoom: 16,
                      onMapReady: () => _mapReady = true,
                      onTap: (_, latLng) {
                        setState(() {
                          _selectedPoint = latLng;
                          _searchResults = [];
                        });
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
                            point: _selectedPoint,
                            radius: radiusMeter,
                            useRadiusInMeter: true,
                            color: _primaryGreen.withValues(alpha: 0.16),
                            borderColor: _primaryGreen,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint,
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFB91C1C),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Controls overlay: zoom +/- & current GPS
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _mapControlButton(
                          tooltip: 'Lokasi GPS Saya',
                          icon: _fetchingGps
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _primaryGreen,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded,
                                  color: _primaryGreen, size: 20),
                          onPressed: _fetchingGps ? null : _useCurrentGps,
                        ),
                        const SizedBox(height: 8),
                        _mapControlButton(
                          tooltip: 'Perbesar Peta',
                          icon: const Icon(Icons.add_rounded,
                              color: _primaryGreen, size: 20),
                          onPressed: () {
                            if (_mapReady) {
                              _moveCamera(
                                _mapController.camera.center,
                                zoom: (_mapController.camera.zoom + 1)
                                    .clamp(3.0, 19.0),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                        _mapControlButton(
                          tooltip: 'Perkecil Peta',
                          icon: const Icon(Icons.remove_rounded,
                              color: _primaryGreen, size: 20),
                          onPressed: () {
                            if (_mapReady) {
                              _moveCamera(
                                _mapController.camera.center,
                                zoom: (_mapController.camera.zoom - 1)
                                    .clamp(3.0, 19.0),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // Attribution pill required by OSM
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selected coordinate readout + actions
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Koordinat Terpilih: ${_selectedPoint.latitude.toStringAsFixed(8)}, ${_selectedPoint.longitude.toStringAsFixed(8)} (Radius ${widget.radiusMeter} m)',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context, _selectedPoint),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text(
                            'Gunakan Lokasi Ini',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapControlButton({
    required String tooltip,
    required Widget icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
