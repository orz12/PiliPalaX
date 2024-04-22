import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../utils/storage.dart';

//横屏
Future<void> landScape() async {
  dynamic document;
  try {
    if (kIsWeb) {
      await document.documentElement?.requestFullscreen();
    } else if (Platform.isAndroid || Platform.isIOS) {
      await AutoOrientation.landscapeAutoMode(forceSensor: true);
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await const MethodChannel('com.alexmercerind/media_kit_video')
          .invokeMethod(
        'Utils.EnterNativeFullscreen',
      );
    }
  } catch (exception, stacktrace) {
    debugPrint(exception.toString());
    debugPrint(stacktrace.toString());
  }
}

//竖屏
Future<void> verticalScreenForTwoSeconds() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  Future.delayed(const Duration(seconds: 2), () {
    autoScreen();
  });
}

//竖屏
Future<void> verticalScreen() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
}

//全向
Future<void> autoScreen() async {
  if (!GStrorage.setting
      .get(SettingBoxKey.allowRotateScreen, defaultValue: true)) {
    return;
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

Future<void> hideStatusBar() async {
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
}

//退出全屏显示
Future<void> showStatusBar() async {
  dynamic document;
  late SystemUiMode mode = SystemUiMode.edgeToEdge;
  try {
    if (kIsWeb) {
      document.exitFullscreen();
    } else if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.isAndroid &&
          (await DeviceInfoPlugin().androidInfo).version.sdkInt < 29) {
        mode = SystemUiMode.manual;
      }
      await SystemChrome.setEnabledSystemUIMode(
        mode,
        overlays: SystemUiOverlay.values,
      );
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await const MethodChannel('com.alexmercerind/media_kit_video')
          .invokeMethod(
        'Utils.ExitNativeFullscreen',
      );
    }
  } catch (exception, stacktrace) {
    debugPrint(exception.toString());
    debugPrint(stacktrace.toString());
  }
}
