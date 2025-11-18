import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/activity_completion.dart';
import '../models/activity_log.dart';
import '../models/pet_state.dart';
import '../models/session_bootstrap.dart';
import '../models/user_interest.dart';
import '../models/user_session.dart';

class ApiResponse<T> {
  ApiResponse.success([this.data])
      : error = null,
        isSuccess = true;

  ApiResponse.failure(this.error)
      : data = null,
        isSuccess = false;

  final T? data;
  final String? error;
  final bool isSuccess;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              "PETAI_API",
              defaultValue: "http://127.0.0.1:5000",
            );

  final http.Client _client;
  final String _baseUrl;
  String? _token;

  Future<ApiResponse<SessionBootstrap>> login({
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
      final data = _data(payload);
      _token = data["token"] as String?;
      if (response.statusCode == 200 && data.isNotEmpty) {
        return ApiResponse.success(_parseBootstrap(data));
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to log in",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<SessionBootstrap>> register({
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
      final data = _data(payload);
      _token = data["token"] as String?;
      if (response.statusCode == 201 && data.isNotEmpty) {
        return ApiResponse.success(_parseBootstrap(data));
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to create account",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<void>> logout() async {
    try {
      final response = await _client.post(
        _uri("/auth/logout"),
        headers: _headers,
      );
      if (response.statusCode == 401) {
        _token = null;
      }
      if (response.statusCode == 200) {
        _token = null;
        return ApiResponse.success();
      }
      final payload = _decode(response.body);
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to logout",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<String>>> fetchDefaultInterests() async {
    try {
      final response = await _client.get(
        _uri("/interests"),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final list = (data["interests"] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .toList();
        return ApiResponse.success(list);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load interests",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<UserInterest>>> fetchUserInterests() async {
    try {
      final response = await _client.get(
        _uri("/user/interests"),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final entries = (data["interests"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(UserInterest.fromJson)
            .toList();
        return ApiResponse.success(entries);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load user interests",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<UserInterest>>> saveUserInterests(
    List<Map<String, dynamic>> entries,
  ) async {
    try {
      final response = await _client.post(
        _uri("/user/interests"),
        headers: _headers,
        body: jsonEncode({"interests": entries}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final items = (data["interests"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(UserInterest.fromJson)
            .toList();
        return ApiResponse.success(items);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to save interests",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<PetState>> fetchPet() async {
    try {
      final response = await _client.get(
        _uri("/pet"),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200 && data["pet"] is Map<String, dynamic>) {
        return ApiResponse.success(
          PetState.fromJson(data["pet"] as Map<String, dynamic>),
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load pet",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<ActivityCompletionResult>> completeActivity(
    String interestName,
  ) async {
    try {
      final response = await _client.post(
        _uri("/activities/complete"),
        headers: _headers,
        body: jsonEncode({"interest": interestName}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if ((response.statusCode == 201 || response.statusCode == 200) &&
          data["pet"] is Map<String, dynamic>) {
        return ApiResponse.success(
          ActivityCompletionResult.fromJson(data),
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to complete activity",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<ActivityLogEntry>>> fetchTodayActivities() async {
    try {
      final response = await _client.get(
        _uri("/activities/today"),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final items = (data["activities"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ActivityLogEntry.fromJson)
            .toList();
        return ApiResponse.success(items);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load activities",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  SessionBootstrap _parseBootstrap(Map<String, dynamic> data) {
    final userJson = data["user"] as Map<String, dynamic>? ?? {};
    final petJson = data["pet"] as Map<String, dynamic>? ?? {};
    return SessionBootstrap(
      user: UserSession.fromJson(userJson),
      pet: PetState.fromJson(petJson),
      needInterestsSetup: data["need_interests_setup"] as bool? ?? false,
    );
  }

  Uri _uri(String path) {
    final normalizedBase = _baseUrl.endsWith("/")
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    return Uri.parse("$normalizedBase$path");
  }

  Map<String, String> get _headers {
    final headers = {"Content-Type": "application/json"};
    final token = _token;
    if (token != null && token.isNotEmpty) {
      headers["Authorization"] = "Bearer $token";
    }
    return headers;
  }

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

  Map<String, dynamic> _data(Map<String, dynamic> payload) {
    final data = payload["data"];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }
}
