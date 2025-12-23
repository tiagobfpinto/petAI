// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'cookie_consent_storage.dart';

/// Persists the auth token in browser storage when the user consents.
class TokenStorage {
  TokenStorage({CookieConsentStorage? consentStorage})
      : _consentStorage = consentStorage ?? const CookieConsentStorage();

  final CookieConsentStorage _consentStorage;

  static const String _tokenKey = "token";

  String? _volatileToken;

  Future<String?> readToken() async {
    final consent = await _consentStorage.readConsent();
    if (consent == true) {
      final persisted = _readPersistedToken();
      if (persisted != null && persisted.isNotEmpty) {
        _volatileToken = persisted;
        return persisted;
      }
    }
    return _volatileToken;
  }

  Future<void> writeToken(String token) async {
    _volatileToken = token;
    final consent = await _consentStorage.readConsent();
    if (consent == true) {
      _writePersistedToken(token);
    }
  }

  Future<void> deleteToken() async {
    _volatileToken = null;
    _deletePersistedToken();
  }

  String? _readPersistedToken() {
    return html.window.localStorage[_tokenKey];
  }

  void _writePersistedToken(String token) {
    html.window.localStorage[_tokenKey] = token;
  }

  void _deletePersistedToken() {
    html.window.localStorage.remove(_tokenKey);
  }
}
