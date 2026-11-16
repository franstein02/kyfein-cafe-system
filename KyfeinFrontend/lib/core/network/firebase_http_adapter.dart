import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../services/rtdb_service.dart';

/// Adapter HTTP-compatible yang mengarahkan semua operasi API Kyfein
/// langsung ke Firebase Realtime Database (tanpa FastAPI / MySQL).
class FirebaseHttpAdapter {
  FirebaseHttpAdapter._();

  static const _storage = FlutterSecureStorage();

  static http.Response _json(dynamic data, {int statusCode = 200}) {
    return http.Response(
      jsonEncode(data),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  static Future<String?> _currentKaryawanId() async {
    try {
      return await _storage.read(key: 'karyawan_id');
    } catch (_) {
      return null;
    }
  }

  static String _normalizePath(Uri uri) {
    var p = uri.path;
    const prefix = '/api/v1';
    if (p.startsWith(prefix)) {
      p = p.substring(prefix.length);
    }
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p.isEmpty ? '/' : p;
  }

  static Map<String, dynamic> _decodeBody(Object? body) {
    if (body == null) return {};
    if (body is Map<String, dynamic>) return body;
    if (body is Map) {
      return body.map((k, v) => MapEntry(k.toString(), v));
    }
    if (body is String && body.isNotEmpty) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return {};
  }

  static double _toDouble(dynamic v, [double fallback = 0.0]) =>
      double.tryParse((v ?? fallback).toString()) ?? fallback;

  static int _toInt(dynamic v, [int fallback = 0]) =>
      int.tryParse((v ?? fallback).toString()) ?? fallback;

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final path = _normalizePath(uri);
    final q = uri.queryParameters;

    try {
      // ── Karyawan ───────────────────────────────────────────
      if (path == '/karyawan' || path == '/karyawan/manajemen-role') {
        var list = await RtdbService.getList('karyawan');
        if (q['role'] != null && q['role']!.isNotEmpty) {
          list = list.where((e) => e['role'] == q['role']).toList();
        }
        return _json(list);
      }
      if (path.startsWith('/karyawan/')) {
        final id = path.split('/').last;
        final item = await RtdbService.getById('karyawan', id);
        if (item == null) return _json({'detail': 'Not found'}, statusCode: 404);
        return _json(item);
      }

      // ── Master Data ────────────────────────────────────────
      if (path == '/master/kategori-menu') {
        return _json(await RtdbService.getList('kategori_menu'));
      }
      if (path == '/master/menu') {
        final menus = await RtdbService.getList('menu');
        final kats = await RtdbService.getMap('kategori_menu');
        final reseps = await RtdbService.getList('menu_resep');
        final bahans = await RtdbService.getMap('bahan');

        final enriched = menus.map((m) {
          final kat = kats[m['kategori_id']];
          final menuResep = reseps
              .where((r) => r['menu_id'] == m['id'])
              .map((r) {
                final b = bahans[r['bahan_id']];
                return {
                  ...r,
                  'nama_bahan': b?['nama'] ?? '',
                  'satuan': b?['satuan'] ?? '',
                };
              })
              .toList();
          return {
            ...m,
            'nama_kategori': kat?['nama'] ?? '',
            'area_produksi': kat?['area_produksi'] ?? 'kitchen',
            'resep': menuResep,
          };
        }).toList();
        return _json(enriched);
      }
      if (path.startsWith('/master/menu/') && path.endsWith('/resep')) {
        final segs = path.split('/');
        final menuId = segs[3];
        final reseps = await RtdbService.getList('menu_resep');
        final bahans = await RtdbService.getMap('bahan');
        final list = reseps
            .where((r) => r['menu_id'] == menuId)
            .map((r) {
              final b = bahans[r['bahan_id']];
              return {
                ...r,
                'nama_bahan': b?['nama'] ?? '',
                'satuan': b?['satuan'] ?? '',
              };
            })
            .toList();
        return _json(list);
      }
      if (path == '/master/bahan') {
        return _json(await RtdbService.getList('bahan'));
      }
      if (path == '/master/bahan/stok-menipis') {
        return _json(await _getStokMenipis());
      }
      if (path == '/master/kategori-pengeluaran') {
        return _json(await RtdbService.getList('kategori_pengeluaran'));
      }
      if (path == '/master/konfigurasi-lokasi') {
        final list = await RtdbService.getList('konfigurasi_lokasi');
        if (list.isEmpty) {
          return _json({
            'id': 'lokasi-utama',
            'latitude': -7.8166,
            'longitude': 112.0114,
            'radius_meter': 50,
          });
        }
        return _json(list.first);
      }

      // ── Transaksi POS ──────────────────────────────────────
      if (path == '/transaksi') {
        var list = await RtdbService.getList('transaksi');
        final details = await RtdbService.getList('transaksi_detail');
        final menus = await RtdbService.getMap('menu');
        final karyawans = await RtdbService.getMap('karyawan');

        if (q['tanggal'] != null && q['tanggal']!.isNotEmpty) {
          list = list
              .where((t) =>
                  (t['waktu_transaksi'] ?? '').toString().startsWith(q['tanggal']!))
              .toList();
        }
        if (q['status'] != null && q['status']!.isNotEmpty) {
          list = list.where((t) => t['status'] == q['status']).toList();
        }

        final enriched = list.map((t) {
          final items = details
              .where((d) => d['transaksi_id'] == t['id'])
              .map((d) {
                final m = menus[d['menu_id']];
                return {
                  ...d,
                  'nama_menu': m?['nama'] ?? '-',
                  'kode_menu': m?['kode_menu'] ?? '',
                };
              })
              .toList();
          final kasir = karyawans[t['kasir_id']];
          return {
            ...t,
            'nama_kasir': kasir?['nama'] ?? 'Kasir',
            'details': items,
            'items': items,
          };
        }).toList()
          ..sort((a, b) => (b['waktu_transaksi'] ?? '')
              .toString()
              .compareTo((a['waktu_transaksi'] ?? '').toString()));

        return _json(enriched);
      }
      if (path == '/transaksi/shift-aktif/laporan') {
        final today = RtdbService.todayDate();
        final list = (await RtdbService.getList('transaksi'))
            .where((t) =>
                t['status'] == 'selesai' &&
                (t['waktu_transaksi'] ?? '').toString().startsWith(today))
            .toList();
        double total = 0;
        double cash = 0;
        double qris = 0;
        for (final t in list) {
          final h = _toDouble(t['total_harga']);
          total += h;
          if (t['metode_bayar'] == 'qris') {
            qris += h;
          } else {
            cash += h;
          }
        }
        return _json({
          'total_pendapatan': total,
          'jumlah_transaksi': list.length,
          'total_cash': cash,
          'total_qris': qris,
        });
      }

      // ── KDS ────────────────────────────────────────────────
      if (path.startsWith('/kds/orders/')) {
        final area = path.split('/').last;
        final details = await RtdbService.getList('transaksi_detail');
        final trxs = await RtdbService.getMap('transaksi');
        final menus = await RtdbService.getMap('menu');
        final kats = await RtdbService.getMap('kategori_menu');

        final list = <Map<String, dynamic>>[];
        for (final d in details) {
          final trx = trxs[d['transaksi_id']];
          if (trx != null && trx['status'] == 'dibatalkan') continue;
          final menu = menus[d['menu_id']];
          final kat = menu != null ? kats[menu['kategori_id']] : null;
          final itemArea = (kat?['area_produksi'] ?? 'kitchen').toString();
          if (area != 'all' && itemArea != area) continue;
          list.add({
            ...d,
            'nomor_transaksi': trx?['nomor_transaksi'] ?? '-',
            'waktu_transaksi': trx?['waktu_transaksi'],
            'nama_menu': menu?['nama'] ?? '-',
            'kode_menu': menu?['kode_menu'] ?? '',
            'area_produksi': itemArea,
          });
        }
        return _json(list);
      }

      // ── Stok & Gudang ──────────────────────────────────────
      if (path == '/stok/stok-gudang') {
        final gudang = await RtdbService.getList('stok_gudang');
        final bahans = await RtdbService.getMap('bahan');
        final list = gudang.map((g) {
          final b = bahans[g['bahan_id']];
          return {
            ...g,
            'nama_bahan': b?['nama'] ?? '',
            'satuan': b?['satuan'] ?? '',
            'isi_per_kemasan': b?['isi_per_kemasan'],
            'stok_minimum': b?['stok_minimum'] ?? 0,
            'harga_rata_rata': b?['harga_rata_rata'] ?? 0,
          };
        }).toList();
        return _json(list);
      }
      if (path == '/stok/stok-titik') {
        var list = await RtdbService.getList('stok_titik');
        final bahans = await RtdbService.getMap('bahan');
        if (q['titik'] != null && q['titik']!.isNotEmpty) {
          list = list.where((e) => e['titik'] == q['titik']).toList();
        }
        final enriched = list.map((s) {
          final b = bahans[s['bahan_id']];
          return {
            ...s,
            'nama_bahan': b?['nama'] ?? '',
            'satuan': b?['satuan'] ?? '',
            'stok_minimum': b?['stok_minimum'] ?? 0,
          };
        }).toList();
        return _json(enriched);
      }
      if (path == '/stok/opname/harian') {
        var list = await RtdbService.getList('stok_opname');
        final details = await RtdbService.getList('stok_opname_detail');
        final bahans = await RtdbService.getMap('bahan');
        final karyawans = await RtdbService.getMap('karyawan');
        if (q['titik'] != null && q['titik']!.isNotEmpty) {
          list = list.where((o) => o['titik'] == q['titik']).toList();
        }
        if (q['tanggal'] != null && q['tanggal']!.isNotEmpty) {
          list = list
              .where((o) =>
                  (o['waktu_opname'] ?? '').toString().startsWith(q['tanggal']!))
              .toList();
        }
        final enriched = list.map((o) {
          final items = details
              .where((d) => d['stok_opname_id'] == o['id'])
              .map((d) {
                final b = bahans[d['bahan_id']];
                return {
                  ...d,
                  'nama_bahan': b?['nama'] ?? '',
                  'satuan': b?['satuan'] ?? '',
                };
              })
              .toList();
          return {
            ...o,
            'nama_karyawan': karyawans[o['karyawan_id']]?['nama'] ?? '',
            'items': items,
          };
        }).toList();
        return _json(enriched);
      }
      if (path == '/stok/opname/audit') {
        var list = await RtdbService.getList('mutasi_stok');
        final bahans = await RtdbService.getMap('bahan');
        if (q['titik'] != null && q['titik']!.isNotEmpty) {
          list = list.where((m) => m['titik'] == q['titik']).toList();
        }
        final enriched = list.map((m) {
          final b = bahans[m['bahan_id']];
          return {
            ...m,
            'nama_bahan': b?['nama'] ?? '',
            'satuan': b?['satuan'] ?? '',
          };
        }).toList();
        return _json(enriched);
      }

      // ── Jadwal & Shift ─────────────────────────────────────
      if (path == '/jadwal') {
        var list = await RtdbService.getList('jadwal_shift');
        final karyawans = await RtdbService.getMap('karyawan');
        if (q['tanggal'] != null && q['tanggal']!.isNotEmpty) {
          list = list.where((j) => j['tanggal'] == q['tanggal']).toList();
        }
        if (q['karyawan_id'] != null && q['karyawan_id']!.isNotEmpty) {
          list = list.where((j) => j['karyawan_id'] == q['karyawan_id']).toList();
        }
        final enriched = list.map((j) {
          final k = karyawans[j['karyawan_id']];
          return {
            ...j,
            'nama_karyawan': k?['nama'] ?? '',
          };
        }).toList();
        return _json(enriched);
      }
      if (path == '/jadwal/shift-aktif') {
        final uid = await _currentKaryawanId();
        final today = RtdbService.todayDate();
        final jadwals = await RtdbService.getList('jadwal_shift');
        final absensis = await RtdbService.getList('absensi');
        final opnames = await RtdbService.getList('stok_opname');

        final match = jadwals.where((j) =>
            (uid == null || j['karyawan_id'] == uid) && j['tanggal'] == today);
        if (match.isEmpty) {
          return _json({'detail': 'Tidak ada shift aktif hari ini'}, statusCode: 404);
        }
        final shift = match.first;
        final abs = absensis.where((a) => a['jadwal_shift_id'] == shift['id']);
        final op = opnames.where((o) =>
            o['jadwal_shift_id'] == shift['id'] && o['tipe'] == 'awal_shift');
        return _json({
          ...shift,
          'absensi': abs.isNotEmpty ? abs.first : null,
          'opname_awal_submit': op.isNotEmpty,
        });
      }
      if (path == '/jadwal/shift-template') {
        return _json(await RtdbService.getList('shift_template'));
      }
      if (path == '/jadwal/request-off') {
        var list = await RtdbService.getList('request_off');
        final karyawans = await RtdbService.getMap('karyawan');
        return _json(list.map((r) {
          return {
            ...r,
            'nama_karyawan': karyawans[r['karyawan_id']]?['nama'] ?? '',
          };
        }).toList());
      }
      if (path == '/jadwal/tukar-shift') {
        var list = await RtdbService.getList('tukar_shift');
        final karyawans = await RtdbService.getMap('karyawan');
        if (q['status'] != null && q['status']!.isNotEmpty) {
          list = list.where((e) => e['status'] == q['status']).toList();
        }
        return _json(list.map((t) {
          return {
            ...t,
            'nama_pengaju': karyawans[t['karyawan_pengaju_id']]?['nama'] ?? '',
            'nama_target': karyawans[t['karyawan_target_id']]?['nama'] ?? '',
          };
        }).toList());
      }
      if (path == '/jadwal/tukar-shift/jadwal-tersedia') {
        final tanggal = q['tanggal'];
        var list = await RtdbService.getList('jadwal_shift');
        final karyawans = await RtdbService.getMap('karyawan');
        if (tanggal != null && tanggal.isNotEmpty) {
          list = list.where((j) => j['tanggal'] == tanggal).toList();
        }
        return _json(list.map((j) {
          return {
            ...j,
            'nama_karyawan': karyawans[j['karyawan_id']]?['nama'] ?? '',
          };
        }).toList());
      }
      if (path == '/jadwal/approvals/pending') {
        final karyawans = await RtdbService.getMap('karyawan');
        final out = <Map<String, dynamic>>[];
        for (final t in await RtdbService.getList('tukar_shift')) {
          if (t['status'] == 'pending') {
            out.add({
              'id': t['id'],
              'type': 'swap_shift',
              'nama_karyawan': karyawans[t['karyawan_pengaju_id']]?['nama'] ?? '',
              'keterangan': t['alasan'] ?? 'Pengajuan tukar shift',
              'tanggal': (t['diajukan_at'] ?? '').toString(),
            });
          }
        }
        for (final i in await RtdbService.getList('izin_telat')) {
          if (i['status'] == 'pending') {
            out.add({
              'id': i['id'],
              'type': 'izin_telat',
              'nama_karyawan': karyawans[i['karyawan_id']]?['nama'] ?? '',
              'keterangan': i['alasan'] ?? 'Izin telat',
              'tanggal': (i['diajukan_at'] ?? '').toString(),
            });
          }
        }
        for (final i in await RtdbService.getList('izin_tidak_masuk')) {
          if (i['status'] == 'pending') {
            out.add({
              'id': i['id'],
              'type': 'izin_tidak_masuk',
              'nama_karyawan': karyawans[i['karyawan_id']]?['nama'] ?? '',
              'keterangan': i['alasan'] ?? 'Izin tidak masuk',
              'tanggal': (i['diajukan_at'] ?? '').toString(),
            });
          }
        }
        return _json(out);
      }

      // ── Absensi & Izin ─────────────────────────────────────
      if (path == '/absensi') {
        var list = await RtdbService.getList('absensi');
        final karyawans = await RtdbService.getMap('karyawan');
        return _json(list.map((a) {
          return {
            ...a,
            'nama_karyawan': karyawans[a['karyawan_id']]?['nama'] ?? '',
          };
        }).toList());
      }
      if (path == '/absensi/status') {
        final uid = await _currentKaryawanId();
        final today = RtdbService.todayDate();
        final jadwals = await RtdbService.getList('jadwal_shift');
        final absensis = await RtdbService.getList('absensi');
        final lokasiList = await RtdbService.getList('konfigurasi_lokasi');
        final lokasi = lokasiList.isNotEmpty
            ? lokasiList.first
            : {'latitude': -7.8166, 'longitude': 112.0114, 'radius_meter': 50};
        final myShift = jadwals.where(
            (j) => (uid == null || j['karyawan_id'] == uid) && j['tanggal'] == today);
        final shift = myShift.isNotEmpty ? myShift.first : null;
        final abs = shift != null
            ? absensis.where((a) => a['jadwal_shift_id'] == shift['id']).toList()
            : <Map<String, dynamic>>[];
        return _json({
          'shift_hari_ini': shift,
          'absensi_hari_ini': abs.isNotEmpty ? abs.first : null,
          'konfigurasi_lokasi': lokasi,
        });
      }
      if (path == '/absensi/izin-telat') {
        var list = await RtdbService.getList('izin_telat');
        final karyawans = await RtdbService.getMap('karyawan');
        if (q['status'] != null && q['status']!.isNotEmpty) {
          list = list.where((e) => e['status'] == q['status']).toList();
        }
        return _json(list.map((e) {
          return {
            ...e,
            'nama_karyawan': karyawans[e['karyawan_id']]?['nama'] ?? '',
          };
        }).toList());
      }
      if (path == '/absensi/izin-tidak-masuk') {
        var list = await RtdbService.getList('izin_tidak_masuk');
        final karyawans = await RtdbService.getMap('karyawan');
        if (q['status'] != null && q['status']!.isNotEmpty) {
          list = list.where((e) => e['status'] == q['status']).toList();
        }
        return _json(list.map((e) {
          return {
            ...e,
            'nama_karyawan': karyawans[e['karyawan_id']]?['nama'] ?? '',
          };
        }).toList());
      }
      if (path == '/absensi/admin/approvals') {
        final karyawans = await RtdbService.getMap('karyawan');
        final telat = (await RtdbService.getList('izin_telat')).map((e) => {
              ...e,
              'tipe': 'izin_telat',
              'nama_karyawan': karyawans[e['karyawan_id']]?['nama'] ?? '',
            });
        final tidakMasuk =
            (await RtdbService.getList('izin_tidak_masuk')).map((e) => {
                  ...e,
                  'tipe': 'izin_tidak_masuk',
                  'nama_karyawan': karyawans[e['karyawan_id']]?['nama'] ?? '',
                });
        return _json([...telat, ...tidakMasuk]);
      }

      // ── Reporting ──────────────────────────────────────────
      if (path == '/reporting/dashboard-overview') {
        return _json(await _getDashboardOverview());
      }
      if (path == '/reporting/profit-harian') {
        final tanggal = q['tanggal'] ?? RtdbService.todayDate();
        return _json(await _getProfitForRange(tanggal, tanggal));
      }
      if (path == '/reporting/profit-periode') {
        final start = q['start_date'] ?? RtdbService.todayDate();
        final end = q['end_date'] ?? RtdbService.todayDate();
        return _json(await _getProfitForRange(start, end));
      }
      if (path == '/reporting/pengeluaran') {
        var list = await RtdbService.getList('pengeluaran');
        final kats = await RtdbService.getMap('kategori_pengeluaran');
        if (q['tipe'] != null && q['tipe']!.isNotEmpty) {
          list = list.where((p) => p['tipe'] == q['tipe']).toList();
        }
        if (q['kategori_id'] != null && q['kategori_id']!.isNotEmpty) {
          list = list.where((p) => p['kategori_id'] == q['kategori_id']).toList();
        }
        return _json(list.map((p) {
          return {
            ...p,
            'nama_kategori': kats[p['kategori_id']]?['nama'] ?? 'Lainnya',
          };
        }).toList());
      }
      if (path == '/reporting/pengeluaran/breakdown') {
        final list = await RtdbService.getList('pengeluaran');
        final kats = await RtdbService.getMap('kategori_pengeluaran');
        final grouped = <String, double>{};
        for (final p in list) {
          final nama = (kats[p['kategori_id']]?['nama'] ?? 'Lainnya').toString();
          grouped[nama] = (grouped[nama] ?? 0) + _toDouble(p['nominal']);
        }
        final out = grouped.entries
            .map((e) => {'kategori': e.key, 'total': e.value})
            .toList();
        return _json(out);
      }

      return _json({'detail': 'Route not found: $path'}, statusCode: 404);
    } catch (e) {
      return _json({'detail': e.toString()}, statusCode: 500);
    }
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final path = _normalizePath(uri);
    final data = _decodeBody(body);
    final uid = await _currentKaryawanId() ?? 'karyawan-admin-001';
    final now = RtdbService.nowIso();

    try {
      if (path == '/auth/fcm-token') {
        final token = data['fcm_token']?.toString();
        if (token != null) {
          await RtdbService.updateRecord('karyawan', uid, {'fcm_token': token});
        }
        return _json({'status': 'ok'});
      }

      if (path == '/foto') {
        final id = RtdbService.newId('foto');
        final record = {
          'id': id,
          'jenis': data['jenis'] ?? 'absensi',
          'path': data['path'] ?? 'firebase_rtdb/inline',
          'uploader_id': uid,
          'dipakai': true,
          'created_at': now,
        };
        await RtdbService.setRecord('foto', id, record);
        return _json(record, statusCode: 201);
      }

      // ── Karyawan ───────────────────────────────────────────
      if (path == '/karyawan') {
        final id = RtdbService.newId('karyawan');
        final record = {
          'id': id,
          'role': data['role'] ?? 'karyawan',
          'nama': data['nama'] ?? '',
          'email': data['email'] ?? '',
          'nomor_hp': data['nomor_hp'] ?? '',
          'password': data['password'] ?? '123456',
          'divisi': data['divisi'] ?? 'kasir',
          'foto_profile_id': data['foto_profile_id'],
          'status_aktif': data['status_aktif'] ?? true,
          'created_at': now,
          'updated_at': now,
        };
        await RtdbService.setRecord('karyawan', id, record);
        return _json(record, statusCode: 201);
      }
      if (path.endsWith('/promote')) {
        final id = path.split('/')[2];
        await RtdbService.updateRecord('karyawan', id, {
          'role': data['role'] ?? 'admin',
          'updated_at': now,
        });
        return _json({'status': 'ok'});
      }
      if (path.endsWith('/nonaktifkan')) {
        final id = path.split('/')[2];
        await RtdbService.updateRecord('karyawan', id, {
          'status_aktif': false,
          'updated_at': now,
        });
        return _json({'status': 'ok'});
      }

      // ── Master Data ────────────────────────────────────────
      if (path == '/master/kategori-menu') {
        final id = RtdbService.newId('kat');
        final record = {
          'id': id,
          'nama': data['nama'] ?? '',
          'area_produksi': data['area_produksi'] ?? 'kitchen',
          'status_aktif': data['status_aktif'] ?? true,
          'created_at': now,
        };
        await RtdbService.setRecord('kategori_menu', id, record);
        return _json(record, statusCode: 201);
      }
      if (path == '/master/menu') {
        final id = RtdbService.newId('menu');
        final record = {
          'id': id,
          'nama': data['nama'] ?? '',
          'kode_menu': data['kode_menu'] ?? 'MNU-${DateTime.now().millisecond}',
          'harga': _toDouble(data['harga']),
          'kategori_id': data['kategori_id'] ?? '',
          'foto_id': data['foto_id'],
          'status_aktif': data['status_aktif'] ?? true,
          'dibuat_oleh': uid,
          'diubah_oleh': uid,
          'created_at': now,
          'updated_at': now,
        };
        await RtdbService.setRecord('menu', id, record);
        if (data['resep'] is List) {
          for (final r in (data['resep'] as List)) {
            if (r is Map) {
              final rid = RtdbService.newId('resep');
              await RtdbService.setRecord('menu_resep', rid, {
                'id': rid,
                'menu_id': id,
                'bahan_id': r['bahan_id'],
                'jumlah_terpakai': _toDouble(r['jumlah_terpakai']),
              });
            }
          }
        }
        return _json(record, statusCode: 201);
      }
      if (path.startsWith('/master/menu/') && path.endsWith('/resep')) {
        final menuId = path.split('/')[3];
        final id = RtdbService.newId('resep');
        final record = {
          'id': id,
          'menu_id': menuId,
          'bahan_id': data['bahan_id'],
          'jumlah_terpakai': _toDouble(data['jumlah_terpakai']),
        };
        await RtdbService.setRecord('menu_resep', id, record);
        return _json(record, statusCode: 201);
      }
      if (path == '/master/bahan') {
        final id = RtdbService.newId('bahan');
        final record = {
          'id': id,
          'nama': data['nama'] ?? '',
          'satuan': data['satuan'] ?? 'gram',
          'isi_per_kemasan': data['isi_per_kemasan'],
          'stok_minimum': _toDouble(data['stok_minimum']),
          'harga_rata_rata': _toDouble(data['harga_rata_rata']),
          'created_at': now,
          'updated_at': now,
        };
        await RtdbService.setRecord('bahan', id, record);
        return _json(record, statusCode: 201);
      }
      if (path == '/master/kategori-pengeluaran') {
        final id = RtdbService.newId('katpeng');
        final record = {
          'id': id,
          'nama': data['nama'] ?? '',
          'status_aktif': data['status_aktif'] ?? true,
          'created_at': now,
        };
        await RtdbService.setRecord('kategori_pengeluaran', id, record);
        return _json(record, statusCode: 201);
      }

      // ── Transaksi POS ──────────────────────────────────────
      if (path == '/transaksi') {
        final trxId = RtdbService.newId('trx');
        final itemsRaw =
            (data['details'] as List?) ?? (data['items'] as List?) ?? [];
        final menus = await RtdbService.getMap('menu');
        final kats = await RtdbService.getMap('kategori_menu');
        final reseps = await RtdbService.getList('menu_resep');
        final bahans = await RtdbService.getMap('bahan');
        final titikList = await RtdbService.getList('stok_titik');

        double totalHarga = 0;
        final createdItems = <Map<String, dynamic>>[];

        for (final item in itemsRaw) {
          if (item is! Map) continue;
          final menuId = item['menu_id'].toString();
          final qty = _toInt(item['qty'], 1);
          final menu = menus[menuId];
          final kat = menu != null ? kats[menu['kategori_id']] : null;
          final area = (kat?['area_produksi'] ?? 'kitchen').toString();
          final hargaSatuan = _toDouble(menu?['harga']);
          double hppSatuan = 0;
          for (final r in reseps.where((x) => x['menu_id'] == menuId)) {
            final bahanId = r['bahan_id'].toString();
            final terpakai = _toDouble(r['jumlah_terpakai']) * qty;
            final b = bahans[bahanId];
            hppSatuan += _toDouble(r['jumlah_terpakai']) *
                _toDouble(b?['harga_rata_rata']);

            // Kurangi stok_titik sesuai area produksi (bar / kitchen)
            final matchTitik = titikList.where(
                (s) => s['bahan_id'] == bahanId && s['titik'] == area);
            if (matchTitik.isNotEmpty) {
              final st = matchTitik.first;
              final sisa = (_toDouble(st['jumlah']) - terpakai)
                  .clamp(0.0, double.infinity);
              st['jumlah'] = sisa;
              await RtdbService.updateRecord('stok_titik', st['id'].toString(), {
                'jumlah': sisa,
                'updated_at': now,
              });
            }
          }
          final subtotal = hargaSatuan * qty;
          totalHarga += subtotal;

          final detailId = RtdbService.newId('trxd');
          final detail = {
            'id': detailId,
            'transaksi_id': trxId,
            'menu_id': menuId,
            'qty': qty,
            'harga_satuan': hargaSatuan,
            'hpp_satuan': hppSatuan,
            'catatan': item['catatan'] ?? '',
            'subtotal': subtotal,
            'status_item': 'menunggu',
          };
          await RtdbService.setRecord('transaksi_detail', detailId, detail);
          createdItems.add(detail);
        }

        if (totalHarga == 0 && data['total_harga'] != null) {
          totalHarga = _toDouble(data['total_harga']);
        }
        final metode = (data['metode_bayar'] ?? 'cash').toString();
        final uangDiterima =
            data['uang_diterima'] != null ? _toDouble(data['uang_diterima']) : totalHarga;
        final kembalian = metode == 'cash' ? (uangDiterima - totalHarga) : 0.0;
        final trx = {
          'id': trxId,
          'jadwal_shift_id': data['jadwal_shift_id'] ?? 'jadwal-frans-today',
          'kasir_id': uid,
          'nomor_transaksi':
              'TRX-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
          'metode_bayar': metode,
          'total_harga': totalHarga,
          'uang_diterima': uangDiterima,
          'kembalian': kembalian,
          'foto_bukti_qris_id': data['foto_bukti_qris_id'],
          'status': 'selesai',
          'waktu_transaksi': now,
          'created_at': now,
        };
        await RtdbService.setRecord('transaksi', trxId, trx);
        return _json({...trx, 'details': createdItems, 'items': createdItems},
            statusCode: 201);
      }
      if (path.startsWith('/transaksi/') && path.endsWith('/void')) {
        final id = path.split('/')[2];
        await RtdbService.updateRecord('transaksi', id, {'status': 'dibatalkan'});

        // Kembalikan stok_titik sesuai resep transaksi yang dibatalkan
        final details = (await RtdbService.getList('transaksi_detail'))
            .where((d) => d['transaksi_id'] == id);
        final menus = await RtdbService.getMap('menu');
        final kats = await RtdbService.getMap('kategori_menu');
        final reseps = await RtdbService.getList('menu_resep');
        final titikList = await RtdbService.getList('stok_titik');

        for (final d in details) {
          final menu = menus[d['menu_id']];
          final kat = menu != null ? kats[menu['kategori_id']] : null;
          final area = (kat?['area_produksi'] ?? 'kitchen').toString();
          final qty = _toInt(d['qty'], 1);
          for (final r in reseps.where((x) => x['menu_id'] == d['menu_id'])) {
            final bahanId = r['bahan_id'].toString();
            final kembali = _toDouble(r['jumlah_terpakai']) * qty;
            final matchTitik = titikList.where(
                (s) => s['bahan_id'] == bahanId && s['titik'] == area);
            if (matchTitik.isNotEmpty) {
              final st = matchTitik.first;
              final baru = _toDouble(st['jumlah']) + kembali;
              st['jumlah'] = baru;
              await RtdbService.updateRecord('stok_titik', st['id'].toString(), {
                'jumlah': baru,
                'updated_at': now,
              });
            }
          }
        }
        return _json({'status': 'ok'});
      }

      // ── Stok & Gudang ──────────────────────────────────────
      if (path == '/stok/barang-masuk') {
        final bmId = RtdbService.newId('bm');
        await RtdbService.setRecord('barang_masuk', bmId, {
          'id': bmId,
          'karyawan_id': uid,
          'keterangan': data['keterangan'] ?? '',
          'waktu': now,
          'created_at': now,
        });
        final items = (data['items'] as List?) ?? [];
        final gudangList = await RtdbService.getList('stok_gudang');
        for (final item in items) {
          if (item is! Map) continue;
          final bahanId = item['bahan_id'].toString();
          final jmlBesar = _toInt(item['jumlah_kemasan_besar']);
          final jmlKecil = _toDouble(item['jumlah_satuan_kecil']);
          final hargaTotal = _toDouble(item['harga_total']);
          final detId = RtdbService.newId('bmd');
          await RtdbService.setRecord('barang_masuk_detail', detId, {
            'id': detId,
            'barang_masuk_id': bmId,
            'bahan_id': bahanId,
            'jumlah_kemasan_besar': jmlBesar,
            'jumlah_satuan_kecil': jmlKecil,
            'harga_total': hargaTotal,
          });
          final existing = gudangList.where((g) => g['bahan_id'] == bahanId);
          if (existing.isNotEmpty) {
            final g = existing.first;
            await RtdbService.updateRecord('stok_gudang', g['id'].toString(), {
              'jumlah_kemasan_besar':
                  _toInt(g['jumlah_kemasan_besar']) + jmlBesar,
              'jumlah_satuan_kecil':
                  _toDouble(g['jumlah_satuan_kecil']) + jmlKecil,
              'updated_at': now,
            });
          } else {
            final gid = RtdbService.newId('sg');
            await RtdbService.setRecord('stok_gudang', gid, {
              'id': gid,
              'bahan_id': bahanId,
              'jumlah_kemasan_besar': jmlBesar,
              'jumlah_satuan_kecil': jmlKecil,
              'updated_at': now,
            });
          }
        }
        return _json({'id': bmId, 'status': 'ok'}, statusCode: 201);
      }
      if (path == '/stok/barang-keluar') {
        final bkId = RtdbService.newId('bk');
        final titik = (data['titik_tujuan'] ?? 'bar').toString();
        await RtdbService.setRecord('barang_keluar', bkId, {
          'id': bkId,
          'titik_tujuan': titik,
          'karyawan_id': uid,
          'waktu': now,
          'created_at': now,
        });
        final items = (data['items'] as List?) ?? [];
        final gudangList = await RtdbService.getList('stok_gudang');
        final titikList = await RtdbService.getList('stok_titik');
        for (final item in items) {
          if (item is! Map) continue;
          final bahanId = item['bahan_id'].toString();
          final jumlah = _toDouble(item['jumlah']);
          final detId = RtdbService.newId('bkd');
          await RtdbService.setRecord('barang_keluar_detail', detId, {
            'id': detId,
            'barang_keluar_id': bkId,
            'bahan_id': bahanId,
            'jumlah': jumlah,
          });
          // Kurangi stok_gudang saat barang keluar ke titik
          final matchGudang = gudangList.where((g) => g['bahan_id'] == bahanId);
          if (matchGudang.isNotEmpty) {
            final g = matchGudang.first;
            final sisaGudang = (_toDouble(g['jumlah_satuan_kecil']) - jumlah)
                .clamp(0.0, double.infinity);
            await RtdbService.updateRecord('stok_gudang', g['id'].toString(), {
              'jumlah_satuan_kecil': sisaGudang,
              'updated_at': now,
            });
          }
          final existing = titikList
              .where((s) => s['bahan_id'] == bahanId && s['titik'] == titik);
          if (existing.isNotEmpty) {
            final s = existing.first;
            await RtdbService.updateRecord('stok_titik', s['id'].toString(), {
              'jumlah': _toDouble(s['jumlah']) + jumlah,
              'updated_at': now,
            });
          } else {
            final sid = RtdbService.newId('st');
            await RtdbService.setRecord('stok_titik', sid, {
              'id': sid,
              'bahan_id': bahanId,
              'titik': titik,
              'jumlah': jumlah,
              'updated_at': now,
            });
          }
        }
        return _json({'id': bkId, 'status': 'ok'}, statusCode: 201);
      }
      if (path == '/stok/opname') {
        final opId = RtdbService.newId('op');
        final record = {
          'id': opId,
          'jadwal_shift_id': data['jadwal_shift_id'] ?? 'jadwal-sample-001',
          'titik': data['titik'] ?? 'bar',
          'tipe': data['tipe'] ?? 'awal_shift',
          'metode': data['metode'] ?? 'hitung_manual',
          'karyawan_id': uid,
          'susulan': data['susulan'] ?? false,
          'diinput_oleh': uid,
          'waktu_opname': now,
          'catatan': data['catatan'] ?? '',
          'created_at': now,
        };
        await RtdbService.setRecord('stok_opname', opId, record);
        final items = (data['items'] as List?) ?? [];
        for (final item in items) {
          if (item is! Map) continue;
          final did = RtdbService.newId('opd');
          await RtdbService.setRecord('stok_opname_detail', did, {
            'id': did,
            'stok_opname_id': opId,
            'bahan_id': item['bahan_id'],
            'jumlah': _toDouble(item['jumlah']),
          });
        }
        return _json(record, statusCode: 201);
      }

      // ── Jadwal & Shift ─────────────────────────────────────
      if (path == '/jadwal') {
        final id = RtdbService.newId('jadwal');
        final record = {
          'id': id,
          'karyawan_id': data['karyawan_id'],
          'tanggal': data['tanggal'],
          'shift': data['shift'] ?? 'shift_1',
          'area_kerja': data['area_kerja'] ?? 'kasir',
          'shift_template_id': data['shift_template_id'],
          'jam_mulai': data['jam_mulai'] ?? '08:00:00',
          'jam_selesai': data['jam_selesai'] ?? '16:00:00',
          'dibuat_oleh': uid,
          'created_at': now,
          'updated_at': now,
        };
        await RtdbService.setRecord('jadwal_shift', id, record);
        return _json(record, statusCode: 201);
      }
      if (path == '/jadwal/request-off') {
        final id = RtdbService.newId('roff');
        final record = {
          'id': id,
          'karyawan_id': uid,
          'tanggal': data['tanggal'],
          'alasan': data['alasan'] ?? '',
          'diajukan_at': now,
        };
        await RtdbService.setRecord('request_off', id, record);
        return _json(record, statusCode: 201);
      }
      if (path == '/jadwal/tukar-shift') {
        final id = RtdbService.newId('tukar');
        final record = {
          'id': id,
          'shift_a_id': data['shift_a_id'],
          'shift_b_id': data['shift_b_id'],
          'karyawan_pengaju_id': uid,
          'karyawan_target_id': data['karyawan_target_id'] ?? '',
          'status': 'pending',
          'alasan': data['alasan'] ?? '',
          'diajukan_at': now,
        };
        await RtdbService.setRecord('tukar_shift', id, record);
        return _json(record, statusCode: 201);
      }
      if (path.startsWith('/jadwal/tukar-shift/') &&
          (path.endsWith('/approve') ||
              path.endsWith('/reject') ||
              path.endsWith('/approval'))) {
        final segs = path.split('/');
        final id = segs[3];
        final action = segs.last;
        final status = action == 'reject'
            ? 'ditolak'
            : (data['status'] ?? (action == 'approve' ? 'disetujui' : 'ditolak'));
        await RtdbService.updateRecord('tukar_shift', id, {
          'status': status,
          'diproses_oleh': uid,
          'diproses_at': now,
        });
        return _json({'status': 'ok'});
      }

      // ── Absensi & Izin ─────────────────────────────────────
      if (path == '/absensi/masuk') {
        final id = RtdbService.newId('abs');
        final record = {
          'id': id,
          'karyawan_id': uid,
          'jadwal_shift_id': data['jadwal_shift_id'] ?? 'jadwal-sample-001',
          'jam_masuk': now,
          'lat_masuk': _toDouble(data['latitude'] ?? data['lat_masuk']),
          'lng_masuk': _toDouble(data['longitude'] ?? data['lng_masuk']),
          'foto_masuk_id': data['foto_masuk_id'] ?? data['foto_id'] ?? '',
          'menit_telat': _toInt(data['menit_telat']),
          'created_at': now,
        };
        await RtdbService.setRecord('absensi', id, record);
        return _json(record, statusCode: 201);
      }
      if (path.startsWith('/absensi/') && path.endsWith('/pulang')) {
        final id = path.split('/')[2];
        await RtdbService.updateRecord('absensi', id, {
          'jam_pulang': now,
          'lat_pulang': _toDouble(data['latitude'] ?? data['lat_pulang']),
          'lng_pulang': _toDouble(data['longitude'] ?? data['lng_pulang']),
          'foto_pulang_id': data['foto_pulang_id'] ?? data['foto_id'],
          'status_pulang': data['status_pulang'] ?? 'tepat_waktu',
        });
        return _json({'status': 'ok'});
      }
      if (path == '/absensi/izin-telat') {
        final id = RtdbService.newId('izt');
        final record = {
          'id': id,
          'karyawan_id': uid,
          'jadwal_shift_id': data['jadwal_shift_id'] ?? 'jadwal-sample-001',
          'alasan': data['alasan'] ?? '',
          'foto_id': data['foto_id'],
          'status': 'pending',
          'diajukan_at': now,
        };
        await RtdbService.setRecord('izin_telat', id, record);
        return _json(record, statusCode: 201);
      }
      if (path == '/absensi/izin-tidak-masuk') {
        final id = RtdbService.newId('iztm');
        final record = {
          'id': id,
          'karyawan_id': uid,
          'jadwal_shift_id': data['jadwal_shift_id'] ?? 'jadwal-sample-001',
          'alasan': data['alasan'] ?? '',
          'foto_id': data['foto_id'] ?? '',
          'status': 'pending',
          'diajukan_at': now,
        };
        await RtdbService.setRecord('izin_tidak_masuk', id, record);
        return _json(record, statusCode: 201);
      }
      if (path.startsWith('/absensi/izin-telat/') && path.endsWith('/approval')) {
        final id = path.split('/')[3];
        await RtdbService.updateRecord('izin_telat', id, {
          'status': data['status'] ?? 'disetujui',
          'diproses_oleh': uid,
          'diproses_at': now,
        });
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/absensi/izin-tidak-masuk/') &&
          path.endsWith('/approval')) {
        final id = path.split('/')[3];
        await RtdbService.updateRecord('izin_tidak_masuk', id, {
          'status': data['status'] ?? 'disetujui',
          'diproses_oleh': uid,
          'diproses_at': now,
        });
        return _json({'status': 'ok'});
      }

      // ── Reporting / Pengeluaran ────────────────────────────
      if (path == '/reporting/pengeluaran') {
        final id = RtdbService.newId('peng');
        final record = {
          'id': id,
          'kategori_id': data['kategori_id'],
          'tipe': data['tipe'] ?? 'mendadak',
          'nominal': _toDouble(data['nominal']),
          'bulan': data['bulan'],
          'tanggal': data['tanggal'],
          'keterangan': data['keterangan'] ?? '',
          'dicatat_oleh': uid,
          'created_at': now,
        };
        await RtdbService.setRecord('pengeluaran', id, record);
        return _json(record, statusCode: 201);
      }

      return _json({'detail': 'POST route not found: $path'}, statusCode: 404);
    } catch (e) {
      return _json({'detail': e.toString()}, statusCode: 500);
    }
  }

  static Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final path = _normalizePath(uri);
    final data = _decodeBody(body);
    final uid = await _currentKaryawanId() ?? 'karyawan-admin-001';
    final now = RtdbService.nowIso();

    try {
      if (path == '/master/konfigurasi-lokasi') {
        await RtdbService.updateRecord('konfigurasi_lokasi', 'lokasi-utama', {
          'id': 'lokasi-utama',
          'latitude': _toDouble(data['latitude']),
          'longitude': _toDouble(data['longitude']),
          'radius_meter': _toInt(data['radius_meter'], 50),
          'updated_by': uid,
          'updated_at': now,
        });
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/karyawan/')) {
        final id = path.split('/').last;
        await RtdbService.updateRecord('karyawan', id, {...data, 'updated_at': now});
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/master/kategori-menu/')) {
        final id = path.split('/').last;
        await RtdbService.updateRecord('kategori_menu', id, data);
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/master/menu/')) {
        final id = path.split('/').last;
        await RtdbService.updateRecord('menu', id, {
          ...data,
          'diubah_oleh': uid,
          'updated_at': now,
        });
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/master/bahan/')) {
        final id = path.split('/').last;
        await RtdbService.updateRecord('bahan', id, {...data, 'updated_at': now});
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/master/kategori-pengeluaran/')) {
        final id = path.split('/').last;
        await RtdbService.updateRecord('kategori_pengeluaran', id, data);
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/stok/stok-gudang/')) {
        final bahanId = path.split('/').last;
        final list = await RtdbService.getList('stok_gudang');
        final existing = list.where((g) => g['bahan_id'] == bahanId);
        if (existing.isNotEmpty) {
          await RtdbService.updateRecord('stok_gudang', existing.first['id'].toString(), {
            ...data,
            'updated_at': now,
          });
        } else {
          final id = RtdbService.newId('sg');
          await RtdbService.setRecord('stok_gudang', id, {
            'id': id,
            'bahan_id': bahanId,
            ...data,
            'updated_at': now,
          });
        }
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/jadwal/shift-template/')) {
        final shift = path.split('/').last;
        await RtdbService.updateRecord('shift_template', shift, {
          ...data,
          'shift': shift,
          'updated_at': now,
        });
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/reporting/pengeluaran/')) {
        final id = path.split('/').last;
        await RtdbService.updateRecord('pengeluaran', id, data);
        return _json({'status': 'ok'});
      }
      return _json({'detail': 'PUT route not found: $path'}, statusCode: 404);
    } catch (e) {
      return _json({'detail': e.toString()}, statusCode: 500);
    }
  }

  static Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final path = _normalizePath(uri);
    final data = _decodeBody(body);
    try {
      if (path.startsWith('/kds/') && path.endsWith('/status')) {
        final segs = path.split('/');
        final detailId = segs[segs.length - 2];
        await RtdbService.updateRecord('transaksi_detail', detailId, {
          'status_item': data['status_item'] ?? data['status'] ?? 'selesai',
        });
        return _json({'status': 'ok'});
      }
      return await put(uri, headers: headers, body: body);
    } catch (e) {
      return _json({'detail': e.toString()}, statusCode: 500);
    }
  }

  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final path = _normalizePath(uri);
    try {
      if (path.startsWith('/karyawan/')) {
        await RtdbService.deleteRecord('karyawan', path.split('/').last);
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/master/menu/')) {
        await RtdbService.deleteRecord('menu', path.split('/').last);
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/master/bahan/')) {
        await RtdbService.deleteRecord('bahan', path.split('/').last);
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/jadwal/request-off/')) {
        await RtdbService.deleteRecord('request_off', path.split('/').last);
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/jadwal/')) {
        await RtdbService.deleteRecord('jadwal_shift', path.split('/').last);
        return _json({'status': 'ok'});
      }
      if (path.startsWith('/reporting/pengeluaran/')) {
        await RtdbService.deleteRecord('pengeluaran', path.split('/').last);
        return _json({'status': 'ok'});
      }
      return _json({'detail': 'DELETE route not found: $path'}, statusCode: 404);
    } catch (e) {
      return _json({'detail': e.toString()}, statusCode: 500);
    }
  }

  static Future<List<Map<String, dynamic>>> _getStokMenipis() async {
    final bahans = await RtdbService.getList('bahan');
    final gudangs = await RtdbService.getList('stok_gudang');
    final titiks = await RtdbService.getList('stok_titik');
    final out = <Map<String, dynamic>>[];

    for (final b in bahans) {
      final minStok = _toDouble(b['stok_minimum']);
      double total = 0;
      for (final g in gudangs.where((x) => x['bahan_id'] == b['id'])) {
        total += _toDouble(g['jumlah_satuan_kecil']);
      }
      for (final t in titiks.where((x) => x['bahan_id'] == b['id'])) {
        total += _toDouble(t['jumlah']);
      }
      if (total <= minStok) {
        out.add({
          'bahan_id': b['id'],
          'nama_bahan': b['nama'],
          'jumlah_sisa': total,
          'stok_minimum': minStok,
          'satuan': b['satuan'],
        });
      }
    }
    return out;
  }

  static Future<Map<String, dynamic>> _getProfitForRange(
      String start, String end) async {
    final trxs = (await RtdbService.getList('transaksi'))
        .where((t) => t['status'] == 'selesai')
        .toList();
    final details = await RtdbService.getList('transaksi_detail');
    final pengs = await RtdbService.getList('pengeluaran');

    double omzet = 0;
    double hpp = 0;
    int jumlahTrx = 0;
    for (final t in trxs) {
      final w = (t['waktu_transaksi'] ?? '').toString();
      final d = w.length >= 10 ? w.substring(0, 10) : '';
      if (d.compareTo(start) >= 0 && d.compareTo(end) <= 0) {
        omzet += _toDouble(t['total_harga']);
        jumlahTrx++;
        for (final det in details.where((x) => x['transaksi_id'] == t['id'])) {
          hpp += _toDouble(det['hpp_satuan']) * _toInt(det['qty'], 1);
        }
      }
    }

    double beban = 0;
    for (final p in pengs) {
      final tgl = (p['tanggal'] ?? '').toString();
      if (tgl.isNotEmpty && tgl.compareTo(start) >= 0 && tgl.compareTo(end) <= 0) {
        beban += _toDouble(p['nominal']);
      }
    }

    final profitKotor = omzet - hpp;
    final profitBersih = profitKotor - beban;
    return {
      'omzet': omzet,
      'total_pendapatan': omzet,
      'hpp': hpp,
      'total_hpp': hpp,
      'pengeluaran': beban,
      'total_pengeluaran': beban,
      'profit_kotor': profitKotor,
      'profit_bersih': profitBersih,
      'jumlah_transaksi': jumlahTrx,
    };
  }

  static Future<Map<String, dynamic>> _getDashboardOverview() async {
    final today = RtdbService.todayDate();
    final profit = await _getProfitForRange(today, today);
    final stokMenipis = await _getStokMenipis();
    final absensis = (await RtdbService.getList('absensi'))
        .where((a) => (a['jam_masuk'] ?? '').toString().startsWith(today))
        .length;
    final trxsToday = (await RtdbService.getList('transaksi'))
        .where((t) =>
            t['status'] == 'selesai' &&
            (t['waktu_transaksi'] ?? '').toString().startsWith(today));
    double totalCash = 0;
    double totalQris = 0;
    for (final t in trxsToday) {
      final h = _toDouble(t['total_harga']);
      if (t['metode_bayar'] == 'qris') {
        totalQris += h;
      } else {
        totalCash += h;
      }
    }
    return {
      ...profit,
      'total_cash': totalCash,
      'total_qris': totalQris,
      'stok_menipis': stokMenipis,
      'jumlah_stok_menipis': stokMenipis.length,
      'hadir_hari_ini': absensis,
    };
  }
}

