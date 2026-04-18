import "package:flutter/foundation.dart";

import "../../../core/state/app_state.dart";

class AlertsViewModel extends ChangeNotifier {
  AlertsViewModel(this.state);

  final AppState state;
}
