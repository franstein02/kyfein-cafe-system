import 'package:http/http.dart' as http;
import 'firebase_http_adapter.dart';

class ApiClient {
  Future<http.Response> get(String url) =>
      FirebaseHttpAdapter.get(Uri.parse(url));

  Future<http.Response> post(String url, {Map<String, dynamic>? body}) =>
      FirebaseHttpAdapter.post(Uri.parse(url), body: body);

  Future<http.Response> put(String url, {Map<String, dynamic>? body}) =>
      FirebaseHttpAdapter.put(Uri.parse(url), body: body);

  Future<http.Response> patch(String url, {Map<String, dynamic>? body}) =>
      FirebaseHttpAdapter.patch(Uri.parse(url), body: body);

  Future<http.Response> delete(String url) =>
      FirebaseHttpAdapter.delete(Uri.parse(url));
}
