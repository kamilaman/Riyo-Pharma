import "package:flutter/foundation.dart";

import "../../../core/state/app_state.dart";

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this.state);

  final AppState state;
}
