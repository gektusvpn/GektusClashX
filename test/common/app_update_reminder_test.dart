import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/app_update_reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('same release waits a day and a new session before reminding', () async {
    var now = DateTime.utc(2026, 10, 21, 12);
    final session = AppUpdateReminder(now: () => now);
    expect(await session.shouldShow('v1'), isTrue);
    await session.markShown('v1');
    now = now.add(const Duration(hours: 23));
    expect(await AppUpdateReminder(now: () => now).shouldShow('v1'), isFalse);
    now = now.add(const Duration(hours: 1));
    expect(await session.shouldShow('v1'), isFalse);
    expect(await AppUpdateReminder(now: () => now).shouldShow('v1'), isTrue);
  });

  test('a different release is not suppressed by the previous reminder',
      () async {
    final reminder = AppUpdateReminder();
    await reminder.markShown('v1');
    expect(await reminder.shouldShow('v2'), isTrue);
    expect(await reminder.shouldShow(''), isFalse);
  });

  test('moving the clock back does not permanently suppress reminders',
      () async {
    final now = DateTime.utc(2026, 10, 21);
    await AppUpdateReminder(now: () => now).markShown('v1');
    final nextSession = AppUpdateReminder(
      now: () => now.subtract(const Duration(days: 2)),
    );
    expect(await nextSession.shouldShow('v1'), isTrue);
  });
}
