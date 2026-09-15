import 'dart:io';

import 'package:gektusclashx/plugins/app.dart';
import 'package:gektusclashx/state.dart';

class Android {
  Future<void> init() async {
    app?.onExit = () async {
      await globalState.appController.savePreferences();
    };
  }
}

final android = Platform.isAndroid ? Android() : null;
