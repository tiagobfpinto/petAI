// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class CookieConsentStorage {
  const CookieConsentStorage({String? key}) : _key = key ?? _defaultKey;

  static const String _defaultKey = "petai_cookie_consent";

  final String _key;

  Future<bool?> readConsent() async {
    final raw = html.window.localStorage[_key];
    if (raw == "accepted") return true;
    if (raw == "declined") return false;
    return null;
  }

  Future<void> writeConsent(bool accepted) async {
    html.window.localStorage[_key] = accepted ? "accepted" : "declined";
  }
}
