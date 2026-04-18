import "package:flutter/foundation.dart";

import "../../../core/models/models.dart";
import "../../../core/state/app_state.dart";

class HomeShellViewModel extends ChangeNotifier {
  HomeShellViewModel(this._appState);

  AppState _appState;
  int _selectedIndex = 0;

  AppUser get currentUser => _appState.currentUser!;
  int get selectedIndex => _selectedIndex;
  bool get allowAdmin =>
      currentUser.role == UserRole.admin ||
      currentUser.role == UserRole.pharmacist;

  void bind(AppState state) {
    _appState = state;
  }

  void setSelectedIndex(int value, int pageCount) {
    final next = value.clamp(0, pageCount - 1);
    if (_selectedIndex == next) return;
    _selectedIndex = next;
    notifyListeners();
  }

  void ensureValidIndex(int pageCount) {
    if (_selectedIndex < pageCount) return;
    _selectedIndex = 0;
    notifyListeners();
  }

  void logout() {
    _appState.logout();
  }
}
