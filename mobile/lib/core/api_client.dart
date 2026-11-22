import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error from the API, using its standard `{code, message}` body (API doc 1.3).
class ApiException implements Exception {
  ApiException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'ApiException($code): $message';
}

/// Thin JSON client: base URL, bearer token, and the shared error model.
class ApiClient {
  ApiClient({required this.baseUrl, this.token, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String? token;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri uri(String path, [Map<String, Object?> query = const {}]) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final params = {
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return Uri.parse('$base$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, Object?> query = const {}}) async {
    final http.Response res;
    try {
      res = await _http.get(uri(path, query), headers: _headers);
    } on Exception {
      throw ApiException(0, 'Could not reach the server. Check your connection.');
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Object? body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      body = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && body is Map<String, dynamic>) {
      return body;
    }
    if (body is Map<String, dynamic> && body['message'] is String) {
      throw ApiException(res.statusCode, body['message'] as String);
    }
    throw ApiException(res.statusCode, 'Something went wrong (${res.statusCode}).');
  }
}
