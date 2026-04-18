import "package:flutter/foundation.dart";

import "../../../core/state/app_state.dart";

class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this.state);

  final AppState state;
}
