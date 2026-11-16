import 'dart:convert';
import 'package:kyfein_frontend/core/constants/api_endpoints.dart';
import 'package:kyfein_frontend/core/network/firebase_http_adapter.dart';

class AttendanceService {
  // 1. Kasir melakukan absen masuk GPS ke Firebase RTDB
  Future<bool> clockIn(int userId, double lat, double lng) async {
    final response = await FirebaseHttpAdapter.post(
      Uri.parse(ApiEndpoints.absenMasuk),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'lat': lat, 'lng': lng}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // 2. Admin mengambil daftar approval/pengajuan kasir dari Firebase RTDB
  Future<List<dynamic>> getApprovals() async {
    final response = await FirebaseHttpAdapter.get(
      Uri.parse('${ApiConfig.baseUrl}/absensi/admin/approvals'),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['data'] is List) return decoded['data'];
      return [];
    }
    throw Exception('Gagal memuat data approval');
  }
}
