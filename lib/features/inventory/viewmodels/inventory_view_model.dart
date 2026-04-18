import "package:flutter/foundation.dart";

import "../../../core/state/app_state.dart";

class InventoryViewModel extends ChangeNotifier {
  InventoryViewModel(this.state);

  final AppState state;
}
