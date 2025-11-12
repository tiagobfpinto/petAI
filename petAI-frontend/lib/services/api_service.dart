import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_session.dart';

class ApiResponse<T> {
  ApiResponse.success(this.data) : error = null;
  ApiResponse.failure(this.error) : data = null;

  final T? data;
  final String? error;

  bool get isSuccess => data != null;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            "PETAI_API",
            defaultValue: "http://127.0.0.1:5000",
          );

  final http.Client _client;
  final String _baseUrl;

  Future<ApiResponse<UserSession>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        _uri("/auth/login"),
        headers: _headers,
        body: jsonEncode({"email": email, "password": password}),
      );
      final payload = _decode(response.body);
      if (response.statusCode == 200 && payload["user"] != null) {
        return ApiResponse.success(UserSession.fromJson(payload["user"]));
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to login",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<UserSession>> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _client.post(
        _uri("/auth/register"),
        headers: _headers,
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
          "full_name": fullName,
        }),
      );
      final payload = _decode(response.body);
      if (response.statusCode == 201 && payload["user"] != null) {
        return ApiResponse.success(UserSession.fromJson(payload["user"]));
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to create account",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Uri _uri(String path) {
    final normalizedBase = _baseUrl.endsWith("/")
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse("$normalizedBase$path");
  }

  Map<String, String> get _headers => {"Content-Type": "application/json"};

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
