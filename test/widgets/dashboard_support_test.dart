import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/dashboard/widgets/support.dart';
import 'package:gektusclashx/widgets/widgets.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/news_test_app.dart';

class _RecordingUrlLauncher extends UrlLauncherPlatform {
  final urls = <String>[];

  @override
  Null get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    return true;
  }
}

final _profile = StateProvider<Profile?>((ref) => null);

Profile _withContacts(Map<String, String> headers) => Profile(
      id: 'support-test',
      label: 'Support test',
      autoUpdateDuration: const Duration(hours: 1),
      providerHeaders: headers,
    );

Future<ProviderContainer> _pumpHeader(WidgetTester tester,
    {Map<String, String> headers = const {},
    bool tv = false,
    double width = 800,
    double textScale = 1,
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    VoidCallback? onSettings}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = ProviderContainer(overrides: [
    isAndroidTVProvider.overrideWith((ref) async => tv),
    currentProfileProvider.overrideWith((ref) => ref.watch(_profile)),
  ]);
  container.read(_profile.notifier).state = _withContacts(headers);
  await container.read(isAndroidTVProvider.future);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      navigatorKey: globalState.navigatorKey,
      theme: ThemeData(
        brightness: brightness,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: CommonScaffold(
        title: locale.languageCode == 'ru' ? 'Главная' : 'Home',
        actions: [DashboardHeaderActions(onSettings: onSettings ?? () {})],
        body: const SizedBox(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
  return container;
}

void main() {
  late _RecordingUrlLauncher launcher;
  setUp(() {
    final previous = UrlLauncherPlatform.instance;
    launcher = _RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    addTearDown(() => UrlLauncherPlatform.instance = previous);
  });
  // Resolve the shared platform future outside individual tests' fake async zones.
  setUpAll(() async {
    await system.isAndroidTV;
  });
  setUp(() async {
    initializeNewsTestState();
    await AppLocalizations.load(const Locale('en'));
  });

  testWidgets('header follows subscription changes and ignores empty contacts',
      (tester) async {
    var settingsOpened = false;
    final container = await _pumpHeader(tester,
        headers: {'support-url': '  ', 'support-email': '\t'},
        onSettings: () => settingsOpened = true);
    expect(find.byIcon(Icons.support_agent_rounded), findsNothing);
    await tester.tap(find.byTooltip('Settings'));
    expect(settingsOpened, isTrue);

    container.read(_profile.notifier).state =
        _withContacts({'support-email': 'help@example.com'});
    await tester.pumpAndSettle();
    expect(find.text('Support'), findsOneWidget);
    expect(tester.getTopLeft(find.byIcon(Icons.support_agent_rounded)).dx,
        lessThan(tester.getTopLeft(find.byIcon(Icons.settings_rounded)).dx));
    container.read(_profile.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.support_agent_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mobile menu stays anchored, labels Telegram, and closes on Escape',
      (tester) async {
    await _pumpHeader(tester, width: 360, headers: {
      'support-url': ' https://t.me/support ',
      'support-email': 'help@example.com',
    });
    await tester.tap(find.byIcon(Icons.support_agent_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(2));
    expect(find.text('Telegram'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.byType(AdaptiveSheetScaffold), findsNothing);
    final menu = tester.getRect(find.byType(MenuItemButton).first);
    expect(menu.left, greaterThanOrEqualTo(0));
    expect(menu.right, lessThanOrEqualTo(360));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final contacts in [
    {'support-url': ' https://example.com/help '},
    {'support-email': ' help@example.com '},
    {'support-email': 'mailto:help@example.com'},
  ]) {
    testWidgets('one contact goes directly to link handling: $contacts',
        (tester) async {
      await _pumpHeader(tester, headers: contacts);
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.support_agent_rounded));
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(find.byType(AdaptiveSheetScaffold), findsNothing);
      if (contacts.containsKey('support-url')) {
        final link = tester.widget<SelectableText>(find.byType(SelectableText));
        expect(link.textSpan!.toPlainText(), 'https://example.com/help');
        expect(launcher.urls, isEmpty);
        globalState.navigatorKey.currentState!.pop(false);
      } else {
        expect(find.byType(SelectableText), findsNothing);
        expect(launcher.urls, ['mailto:help@example.com']);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop menu opens the selected website or email',
      (tester) async {
    await _pumpHeader(tester, headers: {
      'support-url': 'https://example.com/help',
      'support-email': 'help@example.com',
    });
    for (final method in ['Website', 'Email']) {
      await tester.tap(find.byIcon(Icons.support_agent_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text(method));
      await tester
          .pump(); // Menu actions run after focus is restored this frame.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      if (method == 'Website') {
        final link = tester.widget<SelectableText>(find.byType(SelectableText));
        expect(link.textSpan!.toPlainText(), 'https://example.com/help');
        expect(launcher.urls, isEmpty);
        globalState.navigatorKey.currentState!.pop(false);
      } else {
        expect(find.byType(SelectableText), findsNothing);
        expect(launcher.urls, ['mailto:help@example.com']);
      }
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en'), const Locale('ru')]) {
    for (final width in [320.0, 360.0, 390.0]) {
      testWidgets('mobile header shows support label ($locale, $width)',
          (tester) async {
        var settingsOpened = false;
        await _pumpHeader(tester,
            width: width,
            locale: locale,
            headers: {'support-url': 'https://example.com'},
            onSettings: () => settingsOpened = true);
        final label =
            find.text(locale.languageCode == 'ru' ? 'Поддержка' : 'Support');
        expect(label, findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
        final button = tester.getRect(find.byType(FilledButton));
        expect(button.left, greaterThanOrEqualTo(0));
        expect(button.right, lessThanOrEqualTo(width));
        await tester.tap(find.byIcon(Icons.settings_rounded));
        expect(settingsOpened, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('narrow header with large text uses accessible icon buttons',
      (tester) async {
    await _pumpHeader(tester,
        width: 320,
        textScale: 2,
        headers: {'support-url': 'https://example.com'});
    expect(find.text('Support'), findsNothing);
    expect(find.byTooltip('Support'), findsOneWidget);
    for (final icon in [Icons.support_agent_rounded, Icons.settings_rounded]) {
      final button = find.ancestor(
          of: find.byIcon(icon), matching: find.byType(IconButton));
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final supportVisual = find.descendant(
        of: find.ancestor(
            of: find.byIcon(Icons.support_agent_rounded),
            matching: find.byType(IconButton)),
        matching: find.byType(Material));
    final settingsVisual = find.descendant(
        of: find.ancestor(
            of: find.byIcon(Icons.settings_rounded),
            matching: find.byType(IconButton)),
        matching: find.byType(Material));
    expect(
        tester.getRect(settingsVisual).left -
            tester.getRect(supportVisual).right,
        12);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'header has matching 40dp visuals and 48dp targets ($brightness)',
        (tester) async {
      await _pumpHeader(tester,
          brightness: brightness,
          headers: {'support-url': 'https://example.com'});
      final support = find.byType(FilledButton);
      final settings = find.ancestor(
          of: find.byIcon(Icons.settings_rounded),
          matching: find.byType(IconButton));
      final supportVisual =
          find.descendant(of: support, matching: find.byType(Material));
      final settingsVisual =
          find.descendant(of: settings, matching: find.byType(Material));
      expect(tester.getSize(supportVisual).height, 40);
      expect(tester.getSize(settingsVisual), const Size(40, 40));
      expect(tester.getSize(support).height, 48);
      expect(tester.getSize(settings), const Size(48, 48));
      expect(tester.getCenter(supportVisual).dy,
          tester.getCenter(settingsVisual).dy);
      expect(
          tester.getRect(settingsVisual).left -
              tester.getRect(supportVisual).right,
          12);
      expect(
          IconTheme.of(tester.element(find.byIcon(Icons.settings_rounded)))
              .size,
          24);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV offers focusable sheet methods and returns to the header',
      (tester) async {
    await _pumpHeader(tester, tv: true, headers: {
      'support-url': 'https://example.com/help',
      'support-email': 'help@example.com',
    });
    await tester.tap(find.byIcon(Icons.support_agent_rounded));
    await tester.pumpAndSettle();
    final sheet = tester
        .widget<AdaptiveSheetScaffold>(find.byType(AdaptiveSheetScaffold));
    expect(sheet.type, SheetType.tvDialog);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(Focus.of(tester.element(find.text('Website'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Email'))).hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveSheetScaffold), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
