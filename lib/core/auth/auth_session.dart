import 'package:flutter/foundation.dart';

/// Notifies the router when the API rejects the current access token.
class AuthSession extends ChangeNotifier {
  bool _requiresLogin = false;

  bool get requiresLogin => _requiresLogin;

  void markAuthenticated() {
    if (!_requiresLogin) return;
    _requiresLogin = false;
    notifyListeners();
  }

  void markUnauthenticated() {
    if (_requiresLogin) return;
    _requiresLogin = true;
    notifyListeners();
  }
}

final AuthSession authSession = AuthSession();
