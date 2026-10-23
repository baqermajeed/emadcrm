import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'constants.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  String? _token;

  void setToken(String? token) => _token = token;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConstants.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool jsonBody = true}) {
    final headers = <String, String>{
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run().timeout(timeout);
    } on TimeoutException {
      throw ApiException('انتهت مهلة الاتصال — تحقق من الإنترنت وحاول مجدداً');
    } on SocketException {
      throw ApiException('لا يوجد اتصال بالخادم — تحقق من الإنترنت');
    } on http.ClientException {
      throw ApiException('تعذر الاتصال بالخادم — تحقق من الإنترنت');
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _guard(() async {
      final res = await _client.get(_uri(path, query), headers: _headers());
      return _decode(res);
    });
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _guard(() async {
      final res = await _client.post(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      );
      return _decode(res);
    });
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _guard(() async {
      final res = await _client.patch(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      );
      return _decode(res);
    });
  }

  Future<dynamic> delete(String path) async {
    return _guard(() async {
      final res = await _client.delete(_uri(path), headers: _headers());
      return _decode(res);
    });
  }

  Future<dynamic> multipart(
    String path, {
    required String field,
    required String filePath,
    required String filename,
    Map<String, String>? fields,
  }) async {
    return _guard(() async {
      final req = http.MultipartRequest('POST', _uri(path));
      if (_token != null) {
        req.headers['Authorization'] = 'Bearer $_token';
      }
      if (fields != null) {
        req.fields.addAll(fields);
      }
      final lower = filename.toLowerCase();
      final contentType = switch (true) {
        _ when lower.endsWith('.png') => MediaType('image', 'png'),
        _ when lower.endsWith('.webp') => MediaType('image', 'webp'),
        _ when lower.endsWith('.gif') => MediaType('image', 'gif'),
        _ when lower.endsWith('.pdf') => MediaType('application', 'pdf'),
        _ when lower.endsWith('.jpg') || lower.endsWith('.jpeg') =>
          MediaType('image', 'jpeg'),
        _ => MediaType('image', 'jpeg'),
      };
      req.files.add(
        await http.MultipartFile.fromPath(
          field,
          filePath,
          filename: filename,
          contentType: contentType,
        ),
      );
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      return _decode(res);
    });
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    String message = 'حدث خطأ في الخادم';
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      message = detail is String ? detail : detail.toString();
    }
    throw ApiException(message, statusCode: res.statusCode);
  }
}
