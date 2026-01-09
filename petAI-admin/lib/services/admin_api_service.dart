import "package:dio/dio.dart";
import "package:flutter/foundation.dart" show kIsWeb;

import "../config/api_config.dart";
import "../models/user_summary.dart";
import "dio_adapter.dart" if (dart.library.html) "dio_adapter_web.dart";

class ApiResult<T> {
  ApiResult.success(this.data, {this.statusCode})
    : error = null,
      isSuccess = true;

  ApiResult.failure(this.error, {this.statusCode})
    : data = null,
      isSuccess = false;

  final T? data;
  final String? error;
  final bool isSuccess;
  final int? statusCode;
}

class AdminApiService {
  AdminApiService({String? baseUrl, Dio? client})
    : _client =
          client ??
          Dio(
            BaseOptions(
              baseUrl:
                  baseUrl ??
                  const String.fromEnvironment(
                    "PETAI_API",
                    defaultValue: defaultApiUrl,
                  ),
              contentType: "application/json",
              headers: const {"Accept": "application/json"},
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 600,
            ),
          ) {
    configureDioAdapter(_client);
  }

  final Dio _client;
  String? _sessionCookie;
  String? _adminToken;

  bool get hasSession =>
      (_adminToken != null && _adminToken!.isNotEmpty) ||
      (_sessionCookie != null && _sessionCookie!.isNotEmpty);

  Future<ApiResult<void>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        "/admin/login",
        data: {"identifier": identifier, "password": password},
        options: _options(),
      );
      if (_isOk(response)) {
        final data = _data(response);
        final token = data["admin_token"]?.toString();
        if (token != null && token.isNotEmpty) {
          _adminToken = token;
          return ApiResult.success(null, statusCode: response.statusCode);
        }
        _captureSessionCookie(response);
        if (hasSession) {
          return ApiResult.success(null, statusCode: response.statusCode);
        }
        final verified = await _validateSession();
        if (verified) {
          return ApiResult.success(null, statusCode: response.statusCode);
        }
        return ApiResult.failure(
          "Login succeeded but the admin session wasn't established.",
          statusCode: response.statusCode,
        );
      }
      return ApiResult.failure(
        _errorMessage(response) ?? "Failed to log in",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResult.failure("Network error: $err");
    }
  }

  Future<ApiResult<void>> logout() async {
    try {
      final response = await _client.post(
        "/admin/logout",
        options: _options(),
      );
      if (_isOk(response)) {
        _sessionCookie = null;
        _adminToken = null;
        return ApiResult.success(null, statusCode: response.statusCode);
      }
      return ApiResult.failure(
        _errorMessage(response) ?? "Failed to logout",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResult.failure("Network error: $err");
    }
  }

  Future<ApiResult<List<UserSummary>>> fetchUsers({
    String? query,
    int limit = 50,
  }) async {
    try {
      final params = <String, dynamic>{"limit": limit};
      if (query != null && query.trim().isNotEmpty) {
        params["query"] = query.trim();
      }
      final response = await _client.get(
        "/admin/api/users",
        queryParameters: params,
        options: _options(),
      );
      if (_isOk(response)) {
        final data = _data(response);
        final rawList = data["users"];
        if (rawList is List) {
          final users =
              rawList
                  .whereType<Map<String, dynamic>>()
                  .map(UserSummary.fromJson)
                  .toList();
          return ApiResult.success(users, statusCode: response.statusCode);
        }
        return ApiResult.success(const [], statusCode: response.statusCode);
      }
      return ApiResult.failure(
        _errorMessage(response) ?? "Failed to load users",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResult.failure("Network error: $err");
    }
  }

  Future<ApiResult<int>> updateCoins({
    required int userId,
    int? coins,
    int? delta,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (coins != null) {
        payload["coins"] = coins;
      } else if (delta != null) {
        payload["delta"] = delta;
      }
      final response = await _client.post(
        "/admin/api/users/$userId/coins",
        data: payload,
        options: _options(),
      );
      if (_isOk(response)) {
        final data = _data(response);
        final updatedCoins = data["coins"];
        final value = updatedCoins is num ? updatedCoins.toInt() : 0;
        return ApiResult.success(value, statusCode: response.statusCode);
      }
      return ApiResult.failure(
        _errorMessage(response) ?? "Failed to update coins",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResult.failure("Network error: $err");
    }
  }

  Future<ApiResult<Map<String, dynamic>>> grantChests({
    required int userId,
    int quantity = 1,
    String? tier,
    int? itemId,
  }) async {
    try {
      final payload = <String, dynamic>{"quantity": quantity};
      if (tier != null && tier.isNotEmpty) {
        payload["tier"] = tier;
      }
      if (itemId != null) {
        payload["item_id"] = itemId;
      }
      final response = await _client.post(
        "/admin/api/users/$userId/chests",
        data: payload,
        options: _options(),
      );
      if (_isOk(response)) {
        return ApiResult.success(_data(response), statusCode: response.statusCode);
      }
      return ApiResult.failure(
        _errorMessage(response) ?? "Failed to grant chests",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResult.failure("Network error: $err");
    }
  }

  Options _options() {
    final headers = <String, String>{"Accept": "application/json"};
    if (_adminToken != null && _adminToken!.isNotEmpty) {
      headers["Authorization"] = "Bearer $_adminToken";
    }
    if (!kIsWeb && _sessionCookie != null && _sessionCookie!.isNotEmpty) {
      headers["Cookie"] = _sessionCookie!;
    }
    return Options(
      headers: headers,
      extra: const {"withCredentials": true},
    );
  }

  Future<bool> _validateSession() async {
    try {
      final response = await _client.get(
        "/admin/api/users",
        queryParameters: const {"limit": 1},
        options: _options(),
      );
      return _isOk(response);
    } catch (_) {
      return false;
    }
  }

  bool _isOk(Response response) {
    final status = response.statusCode ?? 0;
    return status >= 200 && status < 300;
  }

  void _captureSessionCookie(Response response) {
    if (kIsWeb) {
      return;
    }
    final rawCookies =
        response.headers["set-cookie"] ?? response.headers.map["set-cookie"];
    if (rawCookies == null || rawCookies.isEmpty) {
      return;
    }
    final cookies =
        rawCookies
            .map((cookie) => cookie.split(";").first.trim())
            .where((cookie) => cookie.isNotEmpty)
            .toList();
    if (cookies.isNotEmpty) {
      _sessionCookie = cookies.join("; ");
    }
  }

  Map<String, dynamic> _payload(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  Map<String, dynamic> _data(Response response) {
    final payload = _payload(response);
    final data = payload["data"];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  String? _errorMessage(Response response) {
    final payload = _payload(response);
    final error = payload["error"];
    if (error != null) {
      return error.toString();
    }
    return null;
  }
}
