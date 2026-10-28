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

  Future<Map<String, String>> _headers({
    bool jsonBody = false,
    bool requireAuth = false,
  }) async {
    final token = await _accessTokenProvider?.call();
    // Never send private journal content to an AI endpoint without an
    // authenticated session. A missing token fails before any HTTP request.
    if (requireAuth && (token == null || token.trim().isEmpty)) {
      throw const MissingAccessTokenException();
    }
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    bool requireAuth = false,
  }) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(requireAuth: requireAuth),
    );
    return _decode(response);
  }

  /// Album and memory list endpoints return a top-level JSON array.
  Future<List<dynamic>> getList(String path, {bool requireAuth = false}) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(requireAuth: requireAuth),
    );
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('Expected JSON list');
    return decoded;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(jsonBody: true, requireAuth: requireAuth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final response = await _client.put(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(jsonBody: true, requireAuth: requireAuth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  /// Existing Album and Saved Places update APIs use PATCH (not PUT).
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final response = await _client.patch(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(jsonBody: true, requireAuth: requireAuth),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> deleteNoContent(
    String path, {
    bool requireAuth = false,
  }) async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _headers(requireAuth: requireAuth),
    );
    // Private error bodies are never logged or copied into exceptions.
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException(response.statusCode);
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Expected JSON object');
    return decoded;
  }

  void _ensureSuccess(http.Response response) {
    // No private content, tokens, or upstream messages in exceptions.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode);
    }
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'API request failed (HTTP $statusCode)';
}

/// Local authentication is missing; the HTTP request was never sent.
class MissingAccessTokenException implements Exception {
  const MissingAccessTokenException();

  @override
  String toString() => 'Authentication required for private AI requests';
}
