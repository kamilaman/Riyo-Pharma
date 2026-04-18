import "package:flutter/foundation.dart";

import "../../../core/state/app_state.dart";

class MastersViewModel extends ChangeNotifier {
  MastersViewModel(this.state);

  final AppState state;
}
