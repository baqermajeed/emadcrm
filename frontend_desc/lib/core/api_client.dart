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
      : _ownsClient = client == null {
    _client = client ?? _CookieIoClient(_captureIoCookies);
  }

  late final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  String? _token;
  String? _refreshCookie;
  Future<bool>? _refreshing;
  bool _sessionInvalidEmitted = false;

  void Function(String token, Map<String, dynamic>? userJson)? onAccessTokenUpdated;
  void Function(String? refreshToken)? onRefreshTokenUpdated;
  Future<void> Function()? onSessionInvalid;

  String? get token => _token;
  String? get refreshCookie => _refreshCookie;

  void setToken(String? token) {
    _token = token;
    if (token != null && token.isNotEmpty) {
      _sessionInvalidEmitted = false;
    }
  }

  void setRefreshToken(String? token) {
    _refreshCookie = (token == null || token.isEmpty) ? null : token;
    if (_refreshCookie != null) {
      _sessionInvalidEmitted = false;
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConstants.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool jsonBody = true}) {
    final headers = <String, String>{
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    _applyAuthHeaders(headers);
    return headers;
  }

  void _applyAuthHeaders(Map<String, String> headers) {
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (_refreshCookie != null && _refreshCookie!.isNotEmpty) {
      headers['Cookie'] = '${AppConstants.refreshCookieName}=$_refreshCookie';
      headers['X-Refresh-Token'] = _refreshCookie!;
    }
  }

  bool _shouldSkipRefresh(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/auth/login') ||
        normalized.contains('/auth/refresh') ||
        normalized.contains('/auth/logout');
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

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _request('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _request('POST', path, body: body);
  }

  Future<dynamic> patch(String path, {Object? body}) {
    return _request('PATCH', path, body: body);
  }

  Future<dynamic> delete(String path) {
    return _request('DELETE', path);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    await _ensureFreshAccessToken(path);
    var res = await _guard(() => _send(method, path, query: query, body: body));
    _captureCookies(res);
    res = await _retryAfterUnauthorized(path, res, () {
      return _send(method, path, query: query, body: body);
    });
    return _decode(res);
  }

  Future<dynamic> multipart(
    String path, {
    required String field,
    required String filePath,
    required String filename,
    Map<String, String>? fields,
  }) async {
    await _ensureFreshAccessToken(path);
    var res = await _guard(
      () => _sendMultipart(
        path,
        field: field,
        filePath: filePath,
        filename: filename,
        fields: fields,
      ),
    );
    _captureCookies(res);
    res = await _retryAfterUnauthorized(path, res, () {
      return _sendMultipart(
        path,
        field: field,
        filePath: filePath,
        filename: filename,
        fields: fields,
      );
    });
    return _decode(res);
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) {
    final uri = _uri(path, query);
    final headers = _headers();
    final encoded = body == null ? null : jsonEncode(body);
    return switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encoded),
      'PATCH' => _client.patch(uri, headers: headers, body: encoded),
      'DELETE' => _client.delete(uri, headers: headers),
      _ => throw ApiException('Unsupported HTTP method: $method'),
    };
  }

  Future<http.Response> _sendMultipart(
    String path, {
    required String field,
    required String filePath,
    required String filename,
    Map<String, String>? fields,
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    _applyAuthHeaders(req.headers);
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
    final streamed = await _client.send(req);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _retryAfterUnauthorized(
    String path,
    http.Response res,
    Future<http.Response> Function() retry,
  ) async {
    if (res.statusCode != 401 || !_canAttemptRefresh(path)) {
      return res;
    }
    try {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        await _emitSessionInvalid();
        return res;
      }
      final retried = await _guard(retry);
      _captureCookies(retried);
      return retried;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _emitSessionInvalid();
        return res;
      }
      rethrow;
    }
  }

  bool _canAttemptRefresh(String path) {
    return !_shouldSkipRefresh(path) &&
        _refreshCookie != null &&
        _refreshCookie!.isNotEmpty;
  }

  Future<void> _ensureFreshAccessToken(String path) async {
    if (!_canAttemptRefresh(path)) return;
    if (_token == null || _token!.isEmpty) return;
    if (!_isAccessTokenExpiringSoon(_token!)) return;
    try {
      await _refreshAccessToken();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _emitSessionInvalid();
      }
    }
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshing != null) return _refreshing!;
    final future = _doRefreshAccessToken();
    _refreshing = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshing, future)) {
        _refreshing = null;
      }
    }
  }

  Future<bool> _doRefreshAccessToken() async {
    if (_refreshCookie == null || _refreshCookie!.isEmpty) return false;
    final res = await _guard(() => _send('POST', '/api/auth/refresh'));
    _captureCookies(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode == 401 || res.statusCode == 403) return false;
      throw _exceptionFromResponse(res);
    }
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (body is! Map<String, dynamic>) return false;
    final token = (body['access_token'] as String?)?.trim();
    if (token == null || token.isEmpty) return false;
    _token = token;
    final userJson = body['user'];
    onAccessTokenUpdated?.call(
      token,
      userJson is Map<String, dynamic> ? userJson : null,
    );
    return true;
  }

  void _captureIoCookies(List<Cookie> cookies) {
    for (final cookie in cookies) {
      if (cookie.name != AppConstants.refreshCookieName) continue;
      _storeRefreshCookie(cookie.value);
    }
  }

  void _captureCookies(http.Response res) {
    final headerToken = res.headers['x-refresh-token']?.trim();
    if (headerToken != null && headerToken.isNotEmpty) {
      _storeRefreshCookie(headerToken);
      return;
    }
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final match = RegExp(
      '${RegExp.escape(AppConstants.refreshCookieName)}=([^;]*)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return;
    _storeRefreshCookie(match.group(1));
  }

  void _storeRefreshCookie(String? rawValue) {
    final value = rawValue?.trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'deleted') {
      _refreshCookie = null;
    } else {
      _refreshCookie = value;
    }
    onRefreshTokenUpdated?.call(_refreshCookie);
  }

  bool _isAccessTokenExpiringSoon(
    String token, {
    Duration skew = const Duration(seconds: 60),
  }) {
    final exp = _jwtExpiry(token);
    if (exp == null) return false;
    return !exp.subtract(skew).isAfter(DateTime.now().toUtc());
  }

  DateTime? _jwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      final exp = payload['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round(), isUtc: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> _emitSessionInvalid() async {
    if (_sessionInvalidEmitted) return;
    _sessionInvalidEmitted = true;
    _token = null;
    _refreshCookie = null;
    await onSessionInvalid?.call();
  }

  ApiException _exceptionFromResponse(http.Response res) {
    final body = res.body.isEmpty ? null : _tryJsonDecode(res.body);
    String message = 'حدث خطأ في الخادم';
    if (body is Map && body['detail'] != null) {
      final detail = body['detail'];
      message = detail is String ? detail : detail.toString();
    }
    return ApiException(
      _friendlyMessage(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  dynamic _tryJsonDecode(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  String _friendlyMessage(String message, int statusCode) {
    final lower = message.toLowerCase();
    if (lower.contains('expired token') ||
        lower.contains('invalid or expired') ||
        lower.contains('refresh token')) {
      return 'انتهت الجلسة — يرجى تسجيل الدخول';
    }
    if (statusCode >= 500) return 'حدث خطأ في الخادم';
    return message;
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw _exceptionFromResponse(res);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

class _CookieIoClient extends http.BaseClient {
  _CookieIoClient(this._onCookies);

  final HttpClient _httpClient = HttpClient();
  final void Function(List<Cookie> cookies) _onCookies;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ioRequest = await _httpClient.openUrl(request.method, request.url);
    ioRequest.followRedirects = request.followRedirects;
    ioRequest.maxRedirects = request.maxRedirects;
    ioRequest.persistentConnection = request.persistentConnection;
    request.headers.forEach((name, value) {
      ioRequest.headers.set(name, value);
    });
    final contentLength = request.contentLength;
    if (contentLength != null && contentLength >= 0) {
      ioRequest.contentLength = contentLength;
    }
    await ioRequest.addStream(request.finalize());
    final ioResponse = await ioRequest.close();
    _onCookies(List<Cookie>.from(ioResponse.cookies));

    final headers = <String, String>{};
    ioResponse.headers.forEach((name, values) {
      if (values.isNotEmpty) {
        headers[name] = values.join(',');
      }
    });

    return http.StreamedResponse(
      ioResponse,
      ioResponse.statusCode,
      contentLength: ioResponse.contentLength == -1 ? null : ioResponse.contentLength,
      reasonPhrase: ioResponse.reasonPhrase,
      request: request,
      headers: headers,
      isRedirect: ioResponse.isRedirect,
      persistentConnection: ioResponse.persistentConnection,
    );
  }

  @override
  void close() {
    _httpClient.close(force: true);
  }
}
