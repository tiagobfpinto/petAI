import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/activity_completion.dart';
import '../models/activity_log.dart';
import '../models/friend_profile.dart';
import '../models/friend_search_result.dart';
import '../models/goal_suggestion.dart';
import '../models/pet_state.dart';
import '../models/progression_snapshot.dart';
import '../models/progression_redeem_result.dart';
import '../models/daily_activity.dart';
import '../models/session_bootstrap.dart';
import '../models/subscription_status.dart';
import '../models/activity_type.dart';
import '../models/user_interest.dart';
import '../models/user_session.dart';
import '../models/shop.dart';
import '../models/style_equip_result.dart';
import '../models/style_inventory_item.dart';
import '../models/store_listing.dart';
import 'token_storage.dart';

class ApiResponse<T> {
  ApiResponse.success(this.data, {this.statusCode = 200})
    : error = null,
      isSuccess = true;

  ApiResponse.failure(this.error, {this.statusCode})
    : data = null,
      isSuccess = false;

  final T? data;
  final String? error;
  final bool isSuccess;
  final int? statusCode;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl, TokenStorage? tokenStorage})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            "PETAI_API",
            defaultValue: defaultApiUrl,
          ),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final String _baseUrl;
  final TokenStorage _tokenStorage;
  String? _token;

  Future<String?> hydrateToken() async {
    _token = await _tokenStorage.readToken();
    return _token;
  }

  Future<void> clearToken() {
    return _persistToken(null);
  }

  Future<void> persistCurrentToken() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await _tokenStorage.writeToken(token);
  }

  Future<void> clearStoredToken() async {
    await _tokenStorage.deleteToken();
  }

  Future<void> syncToken(String? token) async {
    if (token == null || token.isEmpty) return;
    await _persistToken(token);
  }

  Future<void> _ensureTokenLoaded() async {
    if (_token == null || _token!.isEmpty) {
      _token = await _tokenStorage.readToken();
    }
  }

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
      return _parseSessionResponse(response, defaultError: "Failed to log in");
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  /// Converts the current guest user into a real account.
  Future<ApiResponse<SessionBootstrap>> convertGuest({
    required String username,
    required String email,
    required String password,
  }) async {
    await _ensureTokenLoaded();
    if (_token == null || _token!.isEmpty) {
      return ApiResponse.failure(
        "No active session. Please restart to refresh your guest profile.",
      );
    }
    final authHeader = _headers["Authorization"];
    // ignore: avoid_print
    print("[convertGuest] Authorization: $authHeader | token=$_token");
    try {
      final response = await _client.post(
        _uri("/auth/convert"),
        headers: _headers,
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
        }),
      );
      return _parseSessionResponse(
        response,
        defaultError: "Failed to convert guest",
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  /// Alias kept for compatibility. Registers now behave like a guest conversion.
  Future<ApiResponse<SessionBootstrap>> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) {
    return convertGuest(username: username, email: email, password: password);
  }

  Future<ApiResponse<SessionBootstrap>> currentUser() async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.get(_uri("/auth/me"), headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200 && data.isNotEmpty) {
        final token = data["token"] as String?;
        if (token != null && token.isNotEmpty) {
          await _persistToken(token);
        }
        return ApiResponse.success(
          _parseBootstrap(data, token: token),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load session",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<UserSession>> updateProfile({
    int? age,
    String? gender,
  }) async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.post(
        _uri("/user/profile"),
        headers: _headers,
        body: jsonEncode({"age": age, "gender": gender}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data["user"] is Map<String, dynamic>) {
        return ApiResponse.success(
          UserSession.fromJson(data["user"] as Map<String, dynamic>),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to update profile",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<GoalSuggestion>> fetchGoalSuggestion({
    int? age,
    String? gender,
    String? activityLevel,
    List<String>? refusedActivities,
  }) async {
    await _ensureTokenLoaded();
    final params = <String, String>{};
    if (age != null) params["age"] = "$age";
    if (gender != null && gender.isNotEmpty) params["gender"] = gender;
    if (activityLevel != null && activityLevel.isNotEmpty) {
      params["activity_level"] = activityLevel;
    }
    if (refusedActivities != null && refusedActivities.isNotEmpty) {
      params["refused"] = refusedActivities.join(",");
    }
    var uri = _uri("/goal/suggested");
    if (params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    try {
      final response = await _client.get(uri, headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        return ApiResponse.success(
          GoalSuggestion.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load suggested goal",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<GoalSuggestion>> fetchWeeklyGoalSuggestion({
    int? age,
    String? gender,
    String? activity,
    double? lastGoalValue,
    String? lastGoalUnit,
    String? interestName,
  }) async {
    await _ensureTokenLoaded();
    final params = <String, String>{};
    if (age != null) params["age"] = "$age";
    if (gender != null && gender.isNotEmpty) params["gender"] = gender;
    if (activity != null && activity.isNotEmpty) params["activity"] = activity;
    if (lastGoalValue != null) params["last_goal_value"] = "$lastGoalValue";
    if (lastGoalUnit != null && lastGoalUnit.isNotEmpty) {
      params["last_goal_unit"] = lastGoalUnit;
    }
    if (interestName != null && interestName.isNotEmpty) {
      params["interest"] = interestName;
    }
    var uri = _uri("/goal/weekly");
    if (params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    try {
      final response = await _client.get(uri, headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        return ApiResponse.success(
          GoalSuggestion.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load weekly goal",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<SessionBootstrap>> createGuest() async {
    try {
      final response = await _client.post(
        _uri("/auth/create/guest"),
        headers: _headers,
      );
      return _parseSessionResponse(
        response,
        defaultError: "Failed to create guest",
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
      if (response.statusCode == 401 || response.statusCode == 200) {
        await _persistToken(null);
      }
      if (response.statusCode == 200) {
        return ApiResponse.success(null, statusCode: response.statusCode);
      }
      final payload = _decode(response.body);
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to logout",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<String>>> fetchDefaultInterests() async {
    try {
      final response = await _client.get(_uri("/interests"), headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final list = (data["interests"] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .toList();
        return ApiResponse.success(list, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load interests",
        statusCode: response.statusCode,
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
        return ApiResponse.success(entries, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load user interests",
        statusCode: response.statusCode,
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
        return ApiResponse.success(items, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to save interests",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<PetState>> fetchPet() async {
    try {
      final response = await _client.get(_uri("/pet"), headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200 && data["pet"] is Map<String, dynamic>) {
        return ApiResponse.success(
          PetState.fromJson(data["pet"] as Map<String, dynamic>),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load pet",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<ActivityCompletionResult>> completeActivity(
    String interestName, {
    double? value,
    String? unit,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        "area": interestName,
        "interest": interestName,
      };
      if (value != null) payload["value"] = value;
      if (unit != null && unit.trim().isNotEmpty) payload["unit"] = unit.trim();
      final response = await _client.post(
        _uri("/activities/complete"),
        headers: _headers,
        body: jsonEncode(payload),
      );
      final decoded = _decode(response.body);
      final data = _data(decoded);
      if ((response.statusCode == 201 || response.statusCode == 200) &&
          data["pet"] is Map<String, dynamic>) {
        return ApiResponse.success(
          ActivityCompletionResult.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        decoded["error"] as String? ?? "Failed to complete activity",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> createActivity({
    required String name,
    required String area,
    double? weeklyGoalValue,
    String? weeklyGoalUnit,
    List<String>? days,
    String? rrule,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        "name": name,
        "area": area,
      };
      if (weeklyGoalValue != null) {
        payload["weekly_goal_value"] = weeklyGoalValue;
      }
      if (weeklyGoalUnit != null && weeklyGoalUnit.trim().isNotEmpty) {
        payload["weekly_goal_unit"] = weeklyGoalUnit.trim();
      }
      if (days != null && days.isNotEmpty) {
        payload["days"] = List<String>.from(days);
      }
      if (rrule != null && rrule.trim().isNotEmpty) {
        payload["rrule"] = rrule.trim();
      }
      final response = await _client.post(
        _uri("/activities"),
        headers: _headers,
        body: jsonEncode(payload),
      );
      final decoded = _decode(response.body);
      final data = _data(decoded);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse.success(
          data is Map<String, dynamic> ? data : <String, dynamic>{},
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        decoded["error"] as String? ?? "Failed to create activity",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<ActivityType>>> fetchActivityTypes() async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.get(
        _uri("/activities/types"),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final items = (data["activity_types"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ActivityType.fromJson)
            .toList();
        return ApiResponse.success(items, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load activity types",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> updateActivityType({
    required int activityTypeId,
    required String name,
    required String area,
    double? weeklyGoalValue,
    String? weeklyGoalUnit,
    List<String>? days,
    String? rrule,
  }) async {
    await _ensureTokenLoaded();
    try {
      final Map<String, dynamic> payload = {
        "name": name,
        "area": area,
      };
      if (weeklyGoalValue != null) payload["weekly_goal_value"] = weeklyGoalValue;
      if (weeklyGoalUnit != null && weeklyGoalUnit.trim().isNotEmpty) {
        payload["weekly_goal_unit"] = weeklyGoalUnit.trim();
      }
      if (days != null && days.isNotEmpty) {
        payload["days"] = List<String>.from(days);
      }
      if (rrule != null && rrule.trim().isNotEmpty) {
        payload["rrule"] = rrule.trim();
      }
      final response = await _client.put(
        _uri("/activities/types/$activityTypeId"),
        headers: _headers,
        body: jsonEncode(payload),
      );
      final decoded = _decode(response.body);
      final data = _data(decoded);
      if (response.statusCode == 200) {
        return ApiResponse.success(
          data is Map<String, dynamic> ? data : <String, dynamic>{},
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        decoded["error"] as String? ?? "Failed to update activity",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<void>> deleteActivityType(int activityTypeId) async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.delete(
        _uri("/activities/types/$activityTypeId"),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return ApiResponse.success(null, statusCode: response.statusCode);
      }
      final payload = _decode(response.body);
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to delete activity",
        statusCode: response.statusCode,
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
        return ApiResponse.success(items, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load activities",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<DailyActivity>>> fetchDailyActivities() async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.get(
        _uri("/daily/activities"),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final items = (data["activities"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DailyActivity.fromJson)
            .toList();
        return ApiResponse.success(items, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load daily activities",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<ActivityCompletionResult>> completeDailyActivity(
    int activityId, {
    double? value,
    String? unit,
  }) async {
    await _ensureTokenLoaded();
    try {
      final Map<String, dynamic> body = {"activity_id": activityId};
      if (value != null) body["value"] = value;
      if (unit != null && unit.trim().isNotEmpty) body["unit"] = unit.trim();
      final response = await _client.post(
        _uri("/daily/activities/complete"),
        headers: _headers,
        body: jsonEncode(body),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final completion = data["completion"] as Map<String, dynamic>? ?? {};
        return ApiResponse.success(
          ActivityCompletionResult.fromJson(completion),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to complete activity",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<ShopState>> fetchShop() async {
    try {
      final response = await _client.get(_uri("/hub/shop"), headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        return ApiResponse.success(
          ShopState.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load shop",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<ShopState>> purchaseItem(String itemId) async {
    try {
      final response = await _client.post(
        _uri("/hub/shop/purchase"),
        headers: _headers,
        body: jsonEncode({"item_id": itemId}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse.success(
          ShopState.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Purchase failed",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<int>> purchaseCoinPack(String packId) async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.post(
        _uri("/hub/coins/purchase"),
        headers: _headers,
        body: jsonEncode({"pack_id": packId}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final balance = data["balance"];
        if (balance is num) {
          return ApiResponse.success(balance.toInt(), statusCode: response.statusCode);
        }
        return ApiResponse.failure(
          "Unexpected response",
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to purchase coins",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<StyleInventoryItem>>> fetchStyleInventory() async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.get(_uri("/style"), headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final items =
            (data["items"] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(StyleInventoryItem.fromJson)
                .toList();
        return ApiResponse.success(items, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load inventory",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<String>>> fetchEquippedStyleTriggers() async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.get(
        _uri("/style/equipped"),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final equipped = data["equipped"];
        final triggers = <String>[];
        if (equipped is Map<String, dynamic>) {
          for (final slot in const ["hat", "sunglasses", "color"]) {
            final entry = equipped[slot];
            if (entry is! Map<String, dynamic>) continue;
            final trigger = entry["trigger"]?.toString().trim() ?? "";
            if (trigger.isNotEmpty) triggers.add(trigger);
          }
        }
        return ApiResponse.success(triggers, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load equipped style",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<StyleEquipResult>> equipStyleItem(int itemId) async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.post(
        _uri("/style/equip/$itemId"),
        headers: _headers,
        body: jsonEncode({}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse.success(
          StyleEquipResult.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to equip item",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<StoreListing>>> fetchStoreListings() async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.get(_uri("/store"), headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final listings =
            (data["listings"] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(StoreListing.fromJson)
                .toList();
        return ApiResponse.success(listings, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load store listings",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<StorePurchaseResult>> buyStoreListing(
    int storeListingId, {
    int quantity = 1,
  }) async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.post(
        _uri("/store/buy/$storeListingId"),
        headers: _headers,
        body: jsonEncode({"quantity": quantity}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse.success(
          StorePurchaseResult.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Purchase failed",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<FriendsOverview>> fetchFriends() async {
    try {
      final response = await _client.get(_uri("/friends"), headers: _headers);
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        return ApiResponse.success(
          FriendsOverview.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load friends",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<FriendRequestEntry>> sendFriendRequest(
    String username,
  ) async {
    try {
      final response = await _client.post(
        _uri("/friends/request"),
        headers: _headers,
        body: jsonEncode({"username": username}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 201 || response.statusCode == 200) {
        final requestJson = data["request"] as Map<String, dynamic>? ?? {};
        return ApiResponse.success(
          FriendRequestEntry.fromJson(
            requestJson,
            direction: RequestDirection.outgoing,
          ),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to send request",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<FriendRequestEntry>> acceptFriendRequest(
    int requestId,
  ) async {
    try {
      final response = await _client.post(
        _uri("/friends/accept"),
        headers: _headers,
        body: jsonEncode({"request_id": requestId}),
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final requestJson = data["request"] as Map<String, dynamic>? ?? {};
        return ApiResponse.success(
          FriendRequestEntry.fromJson(
            requestJson,
            direction: RequestDirection.incoming,
          ),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to accept request",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<void>> removeFriend(int friendId) async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.post(
        _uri("/friends/remove"),
        headers: _headers,
        body: jsonEncode({"friend_id": friendId}),
      );
      if (response.statusCode == 200) {
        return ApiResponse.success(null, statusCode: response.statusCode);
      }
      final payload = _decode(response.body);
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to remove friend",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<List<FriendSearchResult>>> searchFriends(
    String query,
  ) async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.get(
        _uri("/friends/search").replace(queryParameters: {"query": query}),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        final matches = (data["matches"] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(FriendSearchResult.fromJson)
            .toList();
        return ApiResponse.success(matches, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to search friends",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<ProgressionSnapshot>> fetchProgression() async {
    await _ensureTokenLoaded();
    try {
      final response = await _client.get(
        _uri("/hub/progression"),
        headers: _headers,
      );
      final payload = _decode(response.body);
      final data = _data(payload);
      if (response.statusCode == 200) {
        return ApiResponse.success(
          ProgressionSnapshot.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        payload["error"] as String? ?? "Failed to load progression",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<ProgressionRedeemResult>> redeemProgressionReward({
    required String type,
    int? goalId,
    String? milestoneId,
  }) async {
    await _ensureTokenLoaded();
    try {
      final payload = <String, dynamic>{"type": type};
      if (goalId != null) payload["goal_id"] = goalId;
      if (milestoneId != null && milestoneId.isNotEmpty) {
        payload["milestone_id"] = milestoneId;
      }
      final response = await _client.post(
        _uri("/hub/progression/redeem"),
        headers: _headers,
        body: jsonEncode(payload),
      );
      final decoded = _decode(response.body);
      final data = _data(decoded);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(
          ProgressionRedeemResult.fromJson(data),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        decoded["error"] as String? ?? "Failed to redeem reward",
        statusCode: response.statusCode,
      );
    } catch (err) {
      return ApiResponse.failure("Network error: $err");
    }
  }

  Future<ApiResponse<SessionBootstrap>> _parseSessionResponse(
    http.Response response, {
    required String defaultError,
  }) async {
    final payload = _decode(response.body);
    final data = _data(payload);
    final token = data["token"] as String?;

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        data.isNotEmpty) {
      if (token != null && token.isNotEmpty) {
        await _persistToken(token);
      }
      return ApiResponse.success(
        _parseBootstrap(data, token: token),
        statusCode: response.statusCode,
      );
    }

    return ApiResponse.failure(
      payload["error"] as String? ?? defaultError,
      statusCode: response.statusCode,
    );
  }

  Future<void> _persistToken(String? token) async {
    _token = token;
    if (token == null || token.isEmpty) {
      await _tokenStorage.deleteToken();
    } else {
      await _tokenStorage.writeToken(token);
    }
  }

  SessionBootstrap _parseBootstrap(Map<String, dynamic> data, {String? token}) {
    final userJson = data["user"] as Map<String, dynamic>? ?? {};
    final trial = data["trial_days_left"];
    if (trial != null) {
      userJson["trial_days_left"] = trial;
    }
    final subscriptionJson = data["subscription"];
    final petJson = data["pet"] as Map<String, dynamic>? ?? {};
    return SessionBootstrap(
      user: UserSession.fromJson(userJson),
      pet: PetState.fromJson(petJson),
      needInterestsSetup: data["need_interests_setup"] as bool? ?? false,
      subscription:
          subscriptionJson is Map<String, dynamic>
              ? SubscriptionStatus.fromJson(subscriptionJson)
              : null,
      token: token ?? data["token"] as String?,
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
