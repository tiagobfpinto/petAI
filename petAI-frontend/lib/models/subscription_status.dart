class SubscriptionStatus {
  const SubscriptionStatus({
    required this.active,
    required this.status,
    this.productId,
    this.provider,
    this.isTrial = false,
    this.expiresAt,
    this.startedAt,
  });

  final bool active;
  final String status;
  final String? productId;
  final String? provider;
  final bool isTrial;
  final DateTime? expiresAt;
  final DateTime? startedAt;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      active: json["active"] as bool? ?? false,
      status: json["status"] as String? ?? "none",
      productId: json["product_id"] as String?,
      provider: json["provider"] as String?,
      isTrial: json["is_trial"] as bool? ?? false,
      expiresAt: _parseDate(json["expires_at"] as String?),
      startedAt: _parseDate(json["started_at"] as String?),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
}
