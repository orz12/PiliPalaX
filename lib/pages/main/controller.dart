import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/http/common.dart';
import 'package:PiliPalaX/pages/dynamics/index.dart';
import 'package:PiliPalaX/pages/home/view.dart';
import 'package:PiliPalaX/pages/media/index.dart';
import 'package:PiliPalaX/pages/rank/index.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/utils/utils.dart';
import 'package:path/path.dart';
import '../../models/common/dynamic_badge_mode.dart';
import '../../models/common/nav_bar_config.dart';

class MainController extends GetxController {
  List<Widget> pages = <Widget>[
    const HomePage(),
    // const RankPage(),
    const DynamicsPage(),
    const MediaPage(),
  ];
  RxList navigationBars = defaultNavigationBars.obs;
  final StreamController<bool> bottomBarStream =
      StreamController<bool>.broadcast();
  Box setting = GStrorage.setting;
  DateTime? _lastPressedAt;
  late bool hideTabBar;
  late PageController pageController;
  int selectedIndex = 0;
  Box userInfoCache = GStrorage.userInfo;
  RxBool userLogin = false.obs;
  late DynamicBadgeMode dynamicBadgeType;

  @override
  void onInit() {
    super.onInit();
    if (setting.get(SettingBoxKey.autoUpdate, defaultValue: false)) {
      Utils.checkUpdate();
    }
    hideTabBar = setting.get(SettingBoxKey.hideTabBar, defaultValue: false);
    int defaultHomePage =
        setting.get(SettingBoxKey.defaultHomePage, defaultValue: 0) as int;
    selectedIndex = defaultNavigationBars
        .indexWhere((item) => item['id'] == defaultHomePage);
    var userInfo = userInfoCache.get('userInfoCache');
    userLogin.value = userInfo != null;
    dynamicBadgeType = DynamicBadgeMode.values[setting.get(
        SettingBoxKey.dynamicBadgeMode,
        defaultValue: DynamicBadgeMode.number.code)];
    if (dynamicBadgeType != DynamicBadgeMode.hidden) {
      getUnreadDynamic();
    }
  }

  void onBackPressed(BuildContext context) {
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      // 两次点击时间间隔超过2秒，重新记录时间戳
      _lastPressedAt = DateTime.now();
      if (selectedIndex != 0) {
        pageController.jumpTo(0);
      }
      SmartDialog.showToast("再按一次退出PiliPalaX");
      return; // 不退出应用
    }
    SystemNavigator.pop(); // 退出应用
  }

  void getUnreadDynamic() async {
    if (!userLogin.value) {
      return;
    }
    int dynamicItemIndex =
        navigationBars.indexWhere((item) => item['label'] == "动态");
    var res = await CommonHttp.unReadDynamic();
    var data = res['data'];
    if (dynamicItemIndex != -1) {
      navigationBars[dynamicItemIndex]['count'] =
          data == null ? 0 : data.length; // 修改 count 属性为新的值
    }
    navigationBars.refresh();
  }

  void clearUnread() async {
    int dynamicItemIndex =
        navigationBars.indexWhere((item) => item['label'] == "动态");
    if (dynamicItemIndex != -1) {
      navigationBars[dynamicItemIndex]['count'] = 0; // 修改 count 属性为新的值
    }
    navigationBars.refresh();
  }
}
