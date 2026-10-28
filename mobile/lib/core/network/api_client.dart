import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

typedef AccessTokenProvider = Future<String?> Function();
typedef AccessTokenRefresher = Future<String?> Function();

/// One network boundary. Private endpoints require a verified Supabase session.
/// Avoid leaking tokens into logs or exception messages.
class ApiClient {
  ApiClient({
    http.Client? client,
    AccessTokenProvider? accessTokenProvider,
    AccessTokenRefresher? accessTokenRefresher,
    this.requestTimeout = const Duration(seconds: 30),
    this.aiRequestTimeout = const Duration(seconds: 105),
  })  : _client = client ?? http.Client(),
        _accessTokenProvider = accessTokenProvider,
        _accessTokenRefresher = accessTokenRefresher;

  final http.Client _client;
  final AccessTokenProvider? _accessTokenProvider;
  final AccessTokenRefresher? _accessTokenRefresher;
  /// Network timeouts do not retry writes: a timed-out operation may have
  /// succeeded on the backend. The longer AI limit covers local inference.
  final Duration requestTimeout;
  final Duration aiRequestTimeout;

  Future<http.Response> _send(
    String path, {
    required Future<http.Response> Function(Uri, Map<String, String>) send,
    bool requireAuth = false,
    bool jsonBody = false,
    String? contentType,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = await _headers(jsonBody: jsonBody, requireAuth: requireAuth);
    if (contentType != null) headers['Content-Type'] = contentType;
    final limit = path.startsWith('/ai/') ? aiRequestTimeout : requestTimeout;
    Future<http.Response> attempt() => send(uri, headers).timeout(
          limit,
          onTimeout: () => throw const ApiTimeoutException(),
        );
    final response = await attempt();
    // A 401 is rejected before the backend performs authorized mutations.
    // Retry just once with a *new* JWT; never retry a timed-out write.
    if (response.statusCode == 401 &&
        requireAuth &&
        _accessTokenRefresher != null) {
      String? fresh;
      try {
        fresh = await _accessTokenRefresher()
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        return response;
      }
      if (fresh != null && fresh.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $fresh';
        return attempt();
      }
    }
    return response;
  }

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
    final response = await _send(path, requireAuth: requireAuth,
        send: (uri, headers) => _client.get(uri, headers: headers));
    return _decode(response);
  }

  /// Geo reverse lookup legitimately returns JSON null for unnamed points.
  Future<Map<String, dynamic>?> getOptionalJson(
    String path, {
    bool requireAuth = false,
  }) async {
    final response = await _send(path, requireAuth: requireAuth,
        send: (uri, headers) => _client.get(uri, headers: headers));
    _ensureSuccess(response);
    final decoded = jsonDecode(response.body);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object or null');
    }
    return decoded;
  }

  /// Album and memory list endpoints return a top-level JSON array.
  Future<List<dynamic>> getList(String path, {bool requireAuth = false}) async {
    final response = await _send(path, requireAuth: requireAuth,
        send: (uri, headers) => _client.get(uri, headers: headers));
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
    final response = await _send(path, requireAuth: requireAuth, jsonBody: true,
        send: (uri, headers) => _client.post(uri, headers: headers, body: jsonEncode(body)));
    return _decode(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final response = await _send(path, requireAuth: requireAuth, jsonBody: true,
        send: (uri, headers) => _client.put(uri, headers: headers, body: jsonEncode(body)));
    return _decode(response);
  }

  /// Existing Album and Saved Places update APIs use PATCH (not PUT).
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final response = await _send(path, requireAuth: requireAuth, jsonBody: true,
        send: (uri, headers) => _client.patch(uri, headers: headers, body: jsonEncode(body)));
    return _decode(response);
  }

  /// Raw private media transfer, using the same fresh Supabase bearer token.
  Future<void> putBytes(
    String path, List<int> bytes, {
    required String contentType,
    bool requireAuth = true,
  }) async {
    final response = await _send(path, requireAuth: requireAuth,
        contentType: contentType,
        send: (uri, headers) => _client.put(uri, headers: headers, body: bytes));
    _ensureSuccess(response);
  }

  Future<List<int>> getBytes(String path, {bool requireAuth = true}) async {
    final response = await _send(path, requireAuth: requireAuth,
        send: (uri, headers) => _client.get(uri, headers: headers));
    _ensureSuccess(response);
    return response.bodyBytes;
  }

  Future<void> deleteNoContent(
    String path, {
    bool requireAuth = false,
  }) async {
    final response = await _send(path, requireAuth: requireAuth,
        send: (uri, headers) => _client.delete(uri, headers: headers));
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

/// A request timed out; no retry is attempted because the server may have
/// committed the operation even if the response was lost.
class ApiTimeoutException implements Exception {
  const ApiTimeoutException();
  @override
  String toString() => 'API request timed out';
}
