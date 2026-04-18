import "package:flutter/foundation.dart";

import "../../../core/state/app_state.dart";

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._appState);

  AppState _appState;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _appState.currentUser != null;

  void bind(AppState state) {
    _appState = state;
  }

  bool signIn(String username, String pin) {
    final ok = _appState.login(username, pin);
    _errorMessage = ok ? null : "Invalid credentials";
    notifyListeners();
    return ok;
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
