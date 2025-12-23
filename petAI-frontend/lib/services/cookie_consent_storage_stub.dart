class CookieConsentStorage {
  const CookieConsentStorage();

  Future<bool?> readConsent() async {
    return true;
  }

  Future<void> writeConsent(bool accepted) async {}
}
