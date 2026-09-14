import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class ApiClient {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> get(String url) async {
    final headers = await _getHeaders();
    return await http.get(Uri.parse(url), headers: headers);
  }

  Future<http.Response> post(String url, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> put(String url, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    return await http.put(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
