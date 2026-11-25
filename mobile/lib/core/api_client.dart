import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import '../core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';

const String kBaseUrl = 'http://10.0.2.2:8000';
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

  /// Send a JSON body with [method] (e.g. PATCH).
  Future<Map<String, dynamic>> sendJson(String method, String path, Map<String, Object?> body) async {
    final req = http.Request(method, uri(path))
      ..headers.addAll(_headers)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);
    return _send(req);
  }

  /// Send `multipart/form-data` with text [fields] and in-memory [files] (field name -> filename + bytes).
  Future<Map<String, dynamic>> sendMultipart(
    String method,
    String path, {
    Map<String, String> fields = const {},
    Map<String, (String, Uint8List)> files = const {},
  }) async {
    final req = http.MultipartRequest(method, uri(path))
      ..headers.addAll(_headers)
      ..fields.addAll(fields);
    for (final f in files.entries) {
      req.files.add(http.MultipartFile.fromBytes(f.key, f.value.$2, filename: f.value.$1));
    }
    return _send(req);
  }

  Future<Map<String, dynamic>> _send(http.BaseRequest req) async {
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req));
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
 final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(tokenStorageProvider).read();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      // SCRUM-70: a revoked or expired token gets 401 -> drop it and go to Welcome.
      // Login/verify/logout return 401 for their own reasons, so they are skipped.
      onError: (error, handler) {
        final path = error.requestOptions.path;
        if (error.response?.statusCode == 401 && !path.startsWith('/auth/')) {
          ref.read(authProvider.notifier).sessionExpired();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});
