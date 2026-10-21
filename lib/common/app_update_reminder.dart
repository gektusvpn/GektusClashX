import 'package:shared_preferences/shared_preferences.dart';

/// Remind once per app session, and at most once a day for the same release.
class AppUpdateReminder {
  AppUpdateReminder({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final _shownThisSession = <String>{};
  static const interval = Duration(days: 1);

  String _key(String version) => 'appUpdateReminder.$version';

  Future<bool> shouldShow(String version) async {
    if (version.isEmpty || _shownThisSession.contains(version)) return false;
    final preferences = await SharedPreferences.getInstance();
    final lastShown = preferences.getInt(_key(version));
    if (lastShown == null) return true;
    final elapsed = _now().millisecondsSinceEpoch - lastShown;
    // A clock correction must not suppress reminders indefinitely.
    return elapsed < 0 || elapsed >= interval.inMilliseconds;
  }

  Future<void> markShown(String version) async {
    _shownThisSession.add(version);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_key(version), _now().millisecondsSinceEpoch);
  }
}
