import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

/// Helper terpusat untuk akses Firebase Realtime Database (RTDB).
class RtdbService {
  RtdbService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final Random _rand = Random();

  static DatabaseReference ref(String path) => _db.ref(path);

  static String newId([String prefix = 'id']) {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final r = _rand.nextInt(0xFFFFFF).toRadixString(36).padLeft(4, '0');
    return '$prefix-$ts-$r';
  }

  static String nowIso() => DateTime.now().toUtc().toIso8601String();

  static String todayDate() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static dynamic normalizeValue(dynamic val) {
    if (val is Map) {
      return val.map((k, v) => MapEntry(k.toString(), normalizeValue(v)));
    }
    if (val is List) {
      return val.map(normalizeValue).toList();
    }
    return val;
  }

  static Future<Map<String, dynamic>> getMap(String node) async {
    final snap = await _db.ref(node).get();
    if (!snap.exists || snap.value == null) return {};
    final raw = snap.value;
    if (raw is Map) {
      final out = <String, dynamic>{};
      raw.forEach((k, v) {
        final key = k.toString();
        if (key == '_template') return;
        out[key] = normalizeValue(v);
      });
      return out;
    }
    return {};
  }

  static Future<List<Map<String, dynamic>>> getList(String node) async {
    final map = await getMap(node);
    final list = <Map<String, dynamic>>[];
    map.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        final item = Map<String, dynamic>.from(v);
        item['id'] ??= k;
        list.add(item);
      }
    });
    return list;
  }

  static Future<Map<String, dynamic>?> getById(String node, String id) async {
    final snap = await _db.ref('$node/$id').get();
    if (!snap.exists || snap.value == null) return null;
    final val = normalizeValue(snap.value);
    if (val is Map<String, dynamic>) {
      val['id'] ??= id;
      return val;
    }
    return null;
  }

  static Future<void> setRecord(
      String node, String id, Map<String, dynamic> data) async {
    await _db.ref('$node/$id').set(data);
  }

  static Future<void> updateRecord(
      String node, String id, Map<String, dynamic> data) async {
    await _db.ref('$node/$id').update(data);
  }

  static Future<void> deleteRecord(String node, String id) async {
    await _db.ref('$node/$id').remove();
  }

  static Stream<DatabaseEvent> watchNode(String node) => _db.ref(node).onValue;
}

