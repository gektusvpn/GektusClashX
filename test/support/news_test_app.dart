import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/services/news/feed.dart';
import 'package:gektusclashx/services/news/repository.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/dashboard/widgets/hero_connect.dart';
import 'package:gektusclashx/widgets/progress_theme.dart';

import '../fixtures/news_feed.dart';

void initializeNewsTestState() {
  globalState.config = const Config(themeProps: ThemeProps());
  globalState.appState = AppState(
      version: 1,
      viewSize: const Size(1000, 900),
      pageLabel: PageLabel.dashboard,
      requests: FixedList(1),
      logs: FixedList(1),
      traffics: FixedList(1),
      totalTraffic: Traffic());
}

Widget newsTestApp(
    {bool withNews = true,
    Brightness brightness = Brightness.dark,
    NewsFeedRepository? repository,
    String newsUrl = 'https://news.example/feed',
    Widget? child}) {
  final profile = Profile(
      id: 'news-test',
      label: 'Test service',
      autoUpdateDuration: const Duration(hours: 1),
      subscriptionInfo:
          const SubscriptionInfo(total: 350000000000, download: 81000000000),
      providerHeaders: {
        'gektusclashx-servicename': 'Gektus VPN',
        'support-email': 'support@example.com',
        if (withNews) 'gektusclashx-news-url': newsUrl,
      });
  return ProviderScope(
      overrides: [
        isAndroidTVProvider.overrideWith((ref) async => false),
        startButtonSelectorStateProvider.overrideWith((ref) =>
            const StartButtonSelectorState(
                isInit: true, hasProfile: true, hasProxiesInit: false)),
        currentProfileProvider.overrideWith((ref) => profile),
        newsRepositoryProvider
            .overrideWithValue(repository ?? _FixtureNewsRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.delegate.supportedLocales,
        theme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: appPageTransitionsTheme,
            brightness: brightness,
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xffaecc8b), brightness: brightness),
            progressIndicatorTheme: materialProgressTheme,
            fontFamily: 'GoogleSansFlex'),
        home: Scaffold(
            appBar: AppBar(title: const Text('Главная')),
            body: child ?? const HeroConnect()),
      ));
}

class _FixtureNewsRepository extends NewsFeedRepository {
  @override
  Stream<NewsFeedResult> watch(String url, {bool refresh = false}) async* {
    yield await load(url, refresh: refresh);
  }

  @override
  Future<NewsFeedResult> load(String url, {bool refresh = false}) async =>
      NewsFeedResult(NewsFeed.parse(sampleNewsFeed, Uri.parse(url)));
}
