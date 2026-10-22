import 'package:flutter/material.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/dialog.dart';

class BaseNavigator {
  static Future<T?> push<T>(BuildContext context, Widget child) async {
    if (globalState.appState.viewMode != ViewMode.mobile) {
      return Navigator.of(context).push<T>(
        CommonDesktopRoute(
          builder: (context) => child,
        ),
      );
    }
    return Navigator.of(context).push<T>(
      CommonRoute(
        builder: (context) => child,
      ),
    );
  }

  static Future<T?> modal<T>(BuildContext context, Widget child) async {
    if (globalState.appState.viewMode != ViewMode.mobile) {
      return globalState.showCommonDialog<T>(
        child: CommonModal(
          child: child,
        ),
      );
    }
    return Navigator.of(context).push<T>(
      CommonRoute(
        builder: (context) => child,
      ),
    );
  }
}

/// Shared route motion also applies to routes opened directly with
/// MaterialPageRoute, rather than only the BaseNavigator helpers.
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: PredictiveBackFullscreenPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
  },
);

/// Wide layouts use the same themed page transitions as mobile layouts.
class CommonDesktopRoute<T> extends CommonRoute<T> {
  CommonDesktopRoute({required super.builder});
}

class CommonRoute<T> extends MaterialPageRoute<T> {
  CommonRoute({required super.builder});
}
