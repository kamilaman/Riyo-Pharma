import "package:flutter/foundation.dart";

import "../../../core/state/app_state.dart";

class ReportsViewModel extends ChangeNotifier {
  ReportsViewModel(this.state);

  final AppState state;
}
