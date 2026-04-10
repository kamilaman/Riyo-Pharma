import "package:flutter_local_notifications/flutter_local_notifications.dart";

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const settings = InitializationSettings(
      windows: WindowsInitializationSettings(
        appName: "PharmaCore",
        appUserModelId: "com.riyopharma.pharmacore",
        guid: "7f57d8ac-6d8f-4b10-9ec7-0f72d469ce88",
      ),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: "Open"),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  Future<void> showAlert(String title, String body) async {
    if (!_ready) return;
    const details = NotificationDetails(
      windows: WindowsNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      linux: LinuxNotificationDetails(),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
