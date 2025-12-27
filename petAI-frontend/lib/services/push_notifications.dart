import 'api_service.dart';

class PushNotifications {
  PushNotifications(this._apiService);

  final ApiService _apiService;

  Future<ApiResponse<void>> registerToken({
    required String token,
    required String platform,
    String? deviceId,
  }) {
    return _apiService.registerPushToken(
      token: token,
      platform: platform,
      deviceId: deviceId,
    );
  }

  Future<ApiResponse<void>> unregisterToken({required String token}) {
    return _apiService.unregisterPushToken(token: token);
  }
}
