import 'dart:async';

import 'package:PiliPalaX/models/common/dynamics_type.dart';
import 'package:PiliPalaX/models/common/up_panel_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';

import 'controller.dart';
import 'widgets/up_panel.dart';

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends State<DynamicsPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final DynamicsController _dynamicsController = Get.put(DynamicsController());
  late Future _futureBuilderFutureUp;
  Box userInfoCache = GStorage.userInfo;
  late ScrollController scrollController;
  late UpPanelPosition upPanelPosition;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _futureBuilderFutureUp = _dynamicsController.queryFollowUp();
    // _dynamicsController.tabController =
    //     TabController(vsync: this, length: DynamicsType.values.length);
    // ..addListener(() {
    //   if (!_dynamicsController.tabController.indexIsChanging) {
    //     // if (!mounted) return;
    //     // print('indexChanging: ${_dynamicsController.tabController.index}');
    //     _dynamicsController
    //         .onSelectType(_dynamicsController.tabController.index);
    //   }
    // });
    _dynamicsController.userLogin.listen((status) {
      if (mounted) {
        setState(() {
          _futureBuilderFutureUp = _dynamicsController.queryFollowUp();
        });
      }
    });
    upPanelPosition = UpPanelPosition.values[setting.get(
        SettingBoxKey.upPanelPosition,
        defaultValue: UpPanelPosition.leftFixed.code)];
    print('upPanelPosition: $upPanelPosition');
    scrollController = _dynamicsController.scrollController;
  }

  @override
  void dispose() {
    _dynamicsController.tabController.removeListener(() {});
    _dynamicsController.tabController.dispose();
    super.dispose();
  }

  Widget upPanelPart() {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          //抽屉模式增加底色
          color: upPanelPosition.code > 1
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          width: 56,
          child: FutureBuilder(
            future: _futureBuilderFutureUp,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.data == null) {
                  return const SizedBox();
                }
                Map data = snapshot.data;
                if (data['status']) {
                  return Obx(() => UpPanel(
                      _dynamicsController.upData.value, scrollController));
                } else {
                  return const SizedBox();
                }
              } else {
                return const SizedBox(
                  width: 56,
                  child: UpPanelSkeleton(),
                );
              }
            },
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    print('upPanelPosition1: $upPanelPosition');
    super.build(context);
    return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: 50,
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness:
                Theme.of(context).brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
          ),
          title: SizedBox(
              height: 50,
              child: TabBar(
                  controller: _dynamicsController.tabController,
                  isScrollable: true,
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  tabAlignment: TabAlignment.center,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
                  labelStyle: TextStyle(
                    fontSize: Theme.of(context).textTheme.labelMedium!.fontSize,
                  ),
                  tabs: DynamicsType.values
                      .map((e) => Tab(text: e.labels))
                      .toList(),
                  onTap: (index) {
                    print('index: $index');
                    feedBack();
                    tabsConfig[_dynamicsController.tabController.index]['ctr']
                        .animateToTop();
                    // _dynamicsController.tabController
                    // _dynamicsController.tabController.index = index;
                    // _dynamicsController.onSelectType(index);
                    // _
                  })),
        ),
        drawer: upPanelPosition == UpPanelPosition.leftDrawer
            ? upPanelPart()
            : null,
        drawerEnableOpenDragGesture: true,
        endDrawer: upPanelPosition == UpPanelPosition.rightDrawer
            ? upPanelPart()
            : null,
        endDrawerEnableOpenDragGesture: true,
        body: Row(children: [
          if (upPanelPosition == UpPanelPosition.leftFixed) upPanelPart(),
          Expanded(
              child: TabBarView(
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _dynamicsController.tabController,
            children: _dynamicsController.tabsPageList,
          )),
          if (upPanelPosition == UpPanelPosition.rightFixed) upPanelPart(),
        ]));
  }
}
