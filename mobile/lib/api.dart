import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Talks to backend/app.py. Signed-in requests carry the login token as
/// "Authorization: Bearer ...", the same way the website does.
class Api {
  String? token;

  Future<dynamic> request(String method, String path, {Object? body, Duration timeout = const Duration(seconds: 20)}) async {
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final req = http.Request(method, Uri.parse('${AppConfig.apiBase}$path'))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(timeout));
    } catch (_) {
      throw ApiException('Could not reach the server. Check your connection and try again.');
    }
    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 400) {
      final msg = data is Map && data['error'] is String ? data['error'] as String : 'The server said no (${res.statusCode}).';
      throw ApiException(msg);
    }
    return data;
  }

  Future<dynamic> get(String path) => request('GET', path);
  Future<dynamic> post(String path, Object body) => request('POST', path, body: body);
  Future<dynamic> patch(String path, Object body) => request('PATCH', path, body: body);
}
