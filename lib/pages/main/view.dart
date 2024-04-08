import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/models/common/dynamic_badge_mode.dart';
import 'package:PiliPalaX/pages/dynamics/index.dart';
import 'package:PiliPalaX/pages/home/index.dart';
import 'package:PiliPalaX/pages/media/index.dart';
import 'package:PiliPalaX/pages/rank/index.dart';
import 'package:PiliPalaX/utils/event_bus.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';
import './controller.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with SingleTickerProviderStateMixin {
  final MainController _mainController = Get.put(MainController());
  final HomeController _homeController = Get.put(HomeController());
  final RankController _rankController = Get.put(RankController());
  final DynamicsController _dynamicController = Get.put(DynamicsController());
  final MediaController _mediaController = Get.put(MediaController());

  int? _lastSelectTime; //上次点击时间
  Box setting = GStrorage.setting;
  late bool enableMYBar;
  late bool horizontalScreen;

  @override
  void initState() {
    super.initState();
    _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
    _mainController.pageController =
        PageController(initialPage: _mainController.selectedIndex);
    enableMYBar = setting.get(SettingBoxKey.enableMYBar, defaultValue: true);
    horizontalScreen = setting.get(SettingBoxKey.horizontalScreen, defaultValue: false);
  }

  void setIndex(int value) async {
    feedBack();
    _mainController.pageController.jumpToPage(value);
    var currentPage = _mainController.pages[value];
    if (currentPage is HomePage) {
      if (_homeController.flag) {
        // 单击返回顶部 双击并刷新
        if (DateTime.now().millisecondsSinceEpoch - _lastSelectTime! < 500) {
          _homeController.onRefresh();
        } else {
          _homeController.animateToTop();
        }
        _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
      }
      _homeController.flag = true;
    } else {
      _homeController.flag = false;
    }

    if (currentPage is RankPage) {
      if (_rankController.flag) {
        // 单击返回顶部 双击并刷新
        if (DateTime.now().millisecondsSinceEpoch - _lastSelectTime! < 500) {
          _rankController.onRefresh();
        } else {
          _rankController.animateToTop();
        }
        _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
      }
      _rankController.flag = true;
    } else {
      _rankController.flag = false;
    }

    if (currentPage is DynamicsPage) {
      if (_dynamicController.flag) {
        // 单击返回顶部 双击并刷新
        if (DateTime.now().millisecondsSinceEpoch - _lastSelectTime! < 500) {
          _dynamicController.onRefresh();
        } else {
          _dynamicController.animateToTop();
        }
        _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
      }
      _dynamicController.flag = true;
      _mainController.clearUnread();
    } else {
      _dynamicController.flag = false;
    }

    if (currentPage is MediaPage) {
      _mediaController.queryFavFolder();
    }
  }

  @override
  void dispose() async {
    await GStrorage.close();
    EventBus().off(EventName.loginEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        _mainController.onBackPressed(context);
      },
      child: horizontalScreen
      ? AdaptiveScaffold(
        body: (_) => PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _mainController.pageController,
          onPageChanged: (index) {
            _mainController.selectedIndex = index;
            setState(() {});
          },
          children: _mainController.pages,
        ),
        destinations: _mainController.navigationBars.map((e) => NavigationDestination(
          icon: Badge(
            label: _mainController.dynamicBadgeType ==
                    DynamicBadgeMode.number
                ? Text(e['count'].toString())
                : null,
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
            isLabelVisible:
                _mainController.dynamicBadgeType !=
                        DynamicBadgeMode.hidden &&
                    e['count'] > 0,
            child: e['icon'],
            backgroundColor:
                Theme.of(context).colorScheme.primary,
            textColor: Theme.of(context)
                .colorScheme
                .onInverseSurface,
          ),
          selectedIcon: e['selectIcon'],
          label: e['label'],
        )).toList(),
        onSelectedIndexChange: (value) => setIndex(value),
        selectedIndex: _mainController.selectedIndex,
        useDrawer: false
      )
      : Scaffold(
        extendBody: true,
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _mainController.pageController,
          onPageChanged: (index) {
            _mainController.selectedIndex = index;
            setState(() {});
          },
          children: _mainController.pages,
        ),
        bottomNavigationBar: StreamBuilder(
          stream: _mainController.hideTabBar
              ? _mainController.bottomBarStream.stream
              : StreamController<bool>.broadcast().stream,
          initialData: true,
          builder: (context, AsyncSnapshot snapshot) {
            return AnimatedSlide(
              curve: Curves.easeInOutCubicEmphasized,
              duration: const Duration(milliseconds: 500),
              offset: Offset(0, snapshot.data ? 0 : 1),
              child: enableMYBar
                  ? NavigationBar(
                      onDestinationSelected: (value) => setIndex(value),
                      selectedIndex: _mainController.selectedIndex,
                      destinations: <Widget>[
                        ..._mainController.navigationBars.map((e) {
                          return NavigationDestination(
                            icon: Badge(
                              label: _mainController.dynamicBadgeType ==
                                      DynamicBadgeMode.number
                                  ? Text(e['count'].toString())
                                  : null,
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                              isLabelVisible:
                                  _mainController.dynamicBadgeType !=
                                          DynamicBadgeMode.hidden &&
                                      e['count'] > 0,
                              child: e['icon'],
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              textColor: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface,
                            ),
                            selectedIcon: e['selectIcon'],
                            label: e['label'],
                          );
                        }).toList(),
                      ],
                    )
                  : BottomNavigationBar(
                      currentIndex: _mainController.selectedIndex,
                      onTap: (value) => setIndex(value),
                      iconSize: 16,
                      selectedFontSize: 12,
                      unselectedFontSize: 12,
                      type: BottomNavigationBarType.fixed,
                      // selectedItemColor:
                      //     Theme.of(context).colorScheme.primary, // 选中项的颜色
                      // unselectedItemColor:
                      //     Theme.of(context).colorScheme.onSurface,
                      items: [
                        ..._mainController.navigationBars.map((e) {
                          return BottomNavigationBarItem(
                            icon: Badge(
                              label: _mainController.dynamicBadgeType ==
                                      DynamicBadgeMode.number
                                  ? Text(e['count'].toString())
                                  : null,
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                              isLabelVisible:
                                  _mainController.dynamicBadgeType !=
                                          DynamicBadgeMode.hidden &&
                                      e['count'] > 0,
                              child: e['icon'],
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              textColor: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface,
                            ),
                            activeIcon: e['selectIcon'],
                            label: e['label'],
                          );
                        }).toList(),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}
