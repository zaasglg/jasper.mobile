abstract interface class PushGateway {
  bool get supported;
  Stream<Map<String, dynamic>> get events;
  Future<Map<String, dynamic>> status();
  Future<String?> token();
  Future<Map<String, dynamic>?> initialMessage();
  Future<void> requestPermission();
  Future<void> openSettings();
  Future<void> deleteToken();
  Future<void> bindAccount(String userId);
  Future<void> clearAccount();
}
