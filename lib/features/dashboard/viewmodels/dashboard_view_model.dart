import "package:flutter/foundation.dart";

import "../../../core/state/app_state.dart";

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel(this.state);

  final AppState state;
}
