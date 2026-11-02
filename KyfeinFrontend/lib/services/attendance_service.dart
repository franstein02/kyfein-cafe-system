import 'dart:convert';
import 'package:http/http.dart' as http;

class AttendanceService {
  // Sesuaikan URL base backend FastAPI kamu
  final String baseUrl = "http://127.0.0.1:8000/api/v1";

  // 1. Kasir melakukan absen masuk GPS
  Future<bool> clockIn(int userId, double lat, double lng) async {
    final response = await http.post(
      Uri.parse('$baseUrl/absensi/kasir/clock-in'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"user_id": userId, "lat": lat, "lng": lng}),
    );
    return response.statusCode == 200;
  }

  // 2. Admin mengambil daftar approval/pengajuan kasir
  Future<List<dynamic>> getApprovals() async {
    final response = await http.get(Uri.parse('$baseUrl/absensi/admin/approvals'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    }
    throw Exception('Gagal memuat data approval');
  }
}