import 'package:flutter/foundation.dart';

/// Notifies the router when the API rejects the current access token.
class AuthSession extends ChangeNotifier {
  bool _requiresLogin = false;
  int _generation = 0;
  int get generation => _generation;

  bool get requiresLogin => _requiresLogin;

  void markAuthenticated() {
    _generation++;
    _requiresLogin = false;
    notifyListeners();
  }

  void markUnauthenticated() {
    if (_requiresLogin) return;
    _generation++;
    _requiresLogin = true;
    notifyListeners();
  }
}

final AuthSession authSession = AuthSession();
