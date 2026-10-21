import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/controller.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/profiles/tv_profile_switcher.dart';
import 'package:gektusclashx/widgets/tv_controls.dart';

const _profiles = [
  Profile(id: 'a', label: 'Alpha', autoUpdateDuration: Duration(hours: 1)),
  Profile(id: 'b', label: 'Beta', autoUpdateDuration: Duration(hours: 1)),
];

// Record UI commands and remove cards without touching files or the VPN core.
class _RecordingController extends AppController {
  _RecordingController(BuildContext context, WidgetRef ref, this.deleted)
      : _ref = ref,
        super(context, ref);

  final WidgetRef _ref;
  final List<String> deleted;
  PageLabel? lastPage;

  @override
  void toPage(PageLabel pageLabel) => lastPage = pageLabel;

  @override
  Future<void> deleteProfile(String id) async {
    deleted.add(id);
    _ref.read(profilesProvider.notifier).deleteProfileById(id);
  }
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<List<String>> _open(WidgetTester tester,
    {List<Profile> profiles = _profiles, String? selectedId = 'a'}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  globalState.config = Config(
    themeProps: const ThemeProps(),
    profiles: profiles,
    currentProfileId: selectedId,
  );
  final deleted = <String>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [isAndroidTVProvider.overrideWith((ref) async => true)],
    child: Consumer(builder: (context, ref, _) {
      globalState.appController = _RecordingController(context, ref, deleted);
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              autofocus: true,
              onPressed: () => showTVProfileSwitcher(context),
              child: const Text('Open profiles'),
            ),
          ),
        ),
      );
    }),
  ));
  await tester.pumpAndSettle();
  await _press(tester, LogicalKeyboardKey.select);
  return deleted;
}

Finder _action(String label) =>
    find.widgetWithText(TVActionButton, label).hitTestable();

Future<void> _requestDeletion(WidgetTester tester) async {
  await _press(tester, LogicalKeyboardKey.arrowDown);
  expect(Focus.of(tester.element(_action('Delete'))).hasFocus, isTrue);
  await _press(tester, LogicalKeyboardKey.select);
  expect(_action('Cancel'), findsOneWidget);
  expect(Focus.of(tester.element(find.text('Cancel'))).hasFocus, isTrue);
}

void main() {
  setUp(() async => AppLocalizations.load(const Locale('en')));

  testWidgets(
      'focused profile has Delete only; moving and Cancel never switch it',
      (tester) async {
    final deleted = await _open(tester);
    expect(find.text('Open'), findsNothing);
    expect(_action('Delete'), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(Focus.of(tester.element(find.text('Beta'))).hasFocus, isTrue);
    await _requestDeletion(tester);
    expect(find.textContaining('Beta', findRichText: true), findsWidgets);
    expect(globalState.config.currentProfileId, 'a');
    await _press(tester, LogicalKeyboardKey.select);
    expect(deleted, isEmpty);
    expect(globalState.config.profiles, _profiles);
    expect(Focus.of(tester.element(_action('Delete'))).hasFocus, isTrue);

    // Horizontal movement from actions goes to the next card. Hidden actions
    // must not be reachable, including underneath the Add card.
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(Focus.of(tester.element(find.text('Add Profile'))).hasFocus, isTrue);
    expect(_action('Open'), findsNothing);
    expect(_action('Delete'), findsNothing);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(Focus.of(tester.element(find.text('Beta'))).hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.select);
    expect(globalState.config.currentProfileId, 'b');
    expect(find.byType(TVProfileSwitcher), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'deletion keeps picker until the last profile, then returns to home',
      (tester) async {
    final deleted = await _open(tester);
    await _requestDeletion(tester);
    expect(deleted, isEmpty);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.select);
    expect(deleted, ['a']);
    expect(find.text('Alpha'), findsNothing);
    expect(Focus.of(tester.element(find.text('Beta'))).hasFocus, isTrue);

    await _requestDeletion(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.select);
    expect(deleted, ['a', 'b']);
    expect(globalState.config.profiles, isEmpty);
    expect(_action('Open'), findsNothing);
    expect(_action('Delete'), findsNothing);
    expect(find.byType(TVProfileSwitcher), findsNothing);
    expect(find.text('Select Profile'), findsNothing);
    expect(find.text('Open profiles'), findsOneWidget);
    expect((globalState.appController as _RecordingController).lastPage,
        PageLabel.dashboard);
    expect(tester.takeException(), isNull);
  });
  testWidgets('saved offscreen profile and adjacent rows remain reachable',
      (tester) async {
    final profiles = List.generate(
      24,
      (i) => Profile(
        id: 'p$i',
        label: 'Profile $i',
        autoUpdateDuration: const Duration(hours: 1),
      ),
    );
    await _open(tester, profiles: profiles, selectedId: 'p22');
    expect(Focus.of(tester.element(find.text('Profile 22'))).hasFocus, isTrue);
    expect(find.text('Profile 22').hitTestable(), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(Focus.of(tester.element(find.text('Profile 23'))).hasFocus, isTrue);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(Focus.of(tester.element(find.text('Add Profile'))).hasFocus, isTrue);
    expect(find.text('Add Profile').hitTestable(), findsOneWidget);
    expect(globalState.config.currentProfileId, 'p22');
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(Focus.of(tester.element(find.text('Profile 23'))).hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}
