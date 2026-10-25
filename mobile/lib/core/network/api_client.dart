import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

typedef AccessTokenProvider = Future<String?> Function();

/// One network boundary. Private endpoints require a verified Supabase session.
/// Avoid leaking tokens into logs or exception messages.
class ApiClient {
  ApiClient({http.Client? client, AccessTokenProvider? accessTokenProvider})
      : _client = client ?? http.Client(),
        _accessTokenProvider = accessTokenProvider;

  final http.Client _client;
  final AccessTokenProvider? _accessTokenProvider;

  Future<Map<String, String>> _headers({bool jsonBody = false}) async {
    final token = await _accessTokenProvider?.call();
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(jsonBody: true),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Never include server response bodies: they can contain private text.
      throw ApiException(response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'API request failed (HTTP $statusCode)';
}
