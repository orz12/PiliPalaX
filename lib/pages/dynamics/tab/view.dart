import 'dart:async';

import 'package:PiliPalaX/utils/storage.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/constants.dart';
import 'package:PiliPalaX/common/widgets/http_error.dart';
import 'package:PiliPalaX/common/widgets/no_data.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../../../common/skeleton/dynamic_card.dart';
import '../../../models/dynamics/result.dart';
import '../../../utils/grid.dart';

import '../index.dart';
import '../widgets/dynamic_panel.dart';
import 'controller.dart';

class DynamicsTabPage extends StatefulWidget {
  const DynamicsTabPage({Key? key, required this.dynamicsType})
      : super(key: key);

  final String dynamicsType;

  @override
  State<DynamicsTabPage> createState() => _DynamicsTabPageState();
}

class _DynamicsTabPageState extends State<DynamicsTabPage>
    with AutomaticKeepAliveClientMixin {
  late DynamicsTabController _dynamicsTabController;
  late Future _futureBuilderFuture;
  late ScrollController scrollController;
  late bool dynamicsWaterfallFlow;
  late final DynamicsController dynamicsController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dynamicsTabController =
        Get.put(DynamicsTabController(), tag: widget.dynamicsType);
    dynamicsController = Get.find<DynamicsController>();

    _futureBuilderFuture = _dynamicsTabController.queryFollowDynamic(
        'init', widget.dynamicsType, dynamicsController.mid.value);
    scrollController = _dynamicsTabController.scrollController
      ..addListener(() {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          if (!_dynamicsTabController.isLoadingMore.value) {
            EasyThrottle.throttle('_dynamicsTabController_onLoad',
                const Duration(milliseconds: 500), () {
              _dynamicsTabController.isLoadingMore.value = true;
              _dynamicsTabController.onLoad();
              _dynamicsTabController.isLoadingMore.value = false;
            });
          }
        }
      });
    dynamicsController.mid.listen((mid) {
      print('midListen: $mid');
      scrollController.jumpTo(0);
      _futureBuilderFuture = _dynamicsTabController.queryFollowDynamic(
          'init', widget.dynamicsType, mid);
    });
    dynamicsWaterfallFlow = GStorage.setting
        .get(SettingBoxKey.dynamicsWaterfallFlow, defaultValue: true);
  }

  @override
  void dispose() {
    scrollController.removeListener(() {});
    dynamicsController.mid.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // print(widget.dynamicsType + widget.mid.value.toString());
    return RefreshIndicator(
        // key:
        //     ValueKey<String>(widget.dynamicsType + widget.mid.value.toString()),
        onRefresh: () async {
          dynamicsWaterfallFlow = GStorage.setting
              .get(SettingBoxKey.dynamicsWaterfallFlow, defaultValue: true);
          await Future.wait(<Future>[
            _dynamicsTabController.onRefresh(),
            dynamicsController.queryFollowUp()
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _dynamicsTabController.scrollController,
          slivers: [
            FutureBuilder(
              future: _futureBuilderFuture,
              builder: (context, snapshot) {
                // print(snapshot);
                // print(widget.dynamicsType + "${widget.mid?.value}");
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.data == null) {
                    return const NoData();
                  }
                  Map data = snapshot.data;
                  // print('data: $data');
                  if (data['status']) {
                    List<DynamicItemModel> list =
                        _dynamicsTabController.dynamicsList;
                    // print('list: $list');
                    return Obx(
                      () {
                        if (list.isEmpty) {
                          if (_dynamicsTabController.isLoadingMore.value) {
                            return skeleton();
                          }
                          return const NoData();
                        }
                        if (!dynamicsWaterfallFlow) {
                          return SliverCrossAxisGroup(
                            slivers: [
                              const SliverFillRemaining(),
                              SliverConstrainedCrossAxis(
                                  maxExtent: Grid.maxRowWidth * 2,
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if ((dynamicsController
                                                        .tabController.index ==
                                                    4 &&
                                                dynamicsController.mid.value !=
                                                    -1) ||
                                            !dynamicsController.tempBannedList
                                                .contains(list[index]
                                                    .modules
                                                    ?.moduleAuthor
                                                    ?.mid)) {
                                          return DynamicPanel(
                                              item: list[index]);
                                        }
                                        return const SizedBox();
                                      },
                                      childCount: list.length,
                                    ),
                                  )),
                              const SliverFillRemaining(),
                            ],
                          );
                        }
                        return SliverWaterfallFlow.extent(
                          maxCrossAxisExtent: Grid.maxRowWidth * 2,
                          //cacheExtent: 0.0,
                          crossAxisSpacing: StyleString.cardSpace / 2,
                          mainAxisSpacing: StyleString.cardSpace / 2,

                          lastChildLayoutTypeBuilder: (index) =>
                              index == list.length
                                  ? LastChildLayoutType.foot
                                  : LastChildLayoutType.none,
                          children: [
                            if (dynamicsController.tabController.index == 4 &&
                                dynamicsController.mid.value != -1) ...[
                              for (var i in list) DynamicPanel(item: i),
                            ] else ...[
                              for (var i in list)
                                if (!dynamicsController.tempBannedList
                                    .contains(i.modules?.moduleAuthor?.mid))
                                  DynamicPanel(item: i),
                            ]
                          ],
                        );
                      },
                    );
                  } else {
                    return HttpError(
                      errMsg: data['msg'],
                      fn: () {
                        // setState(() {
                        _futureBuilderFuture =
                            _dynamicsTabController.queryFollowDynamic(
                                'init',
                                widget.dynamicsType,
                                dynamicsController.mid.value);
                        // });
                        dynamicsController.onRefresh();
                      },
                    );
                  }
                } else {
                  // 骨架屏
                  return skeleton();
                }
              },
            )
          ],
        ));
  }

  Widget skeleton() {
    if (!dynamicsWaterfallFlow) {
      return SliverCrossAxisGroup(slivers: [
        const SliverFillRemaining(),
        SliverConstrainedCrossAxis(
          maxExtent: Grid.maxRowWidth * 2,
          sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
            return const DynamicCardSkeleton();
          }, childCount: 10)),
        ),
        const SliverFillRemaining()
      ]);
    }
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithExtentAndRatio(
          crossAxisSpacing: StyleString.cardSpace / 2,
          mainAxisSpacing: StyleString.cardSpace / 2,
          maxCrossAxisExtent: Grid.maxRowWidth * 2,
          childAspectRatio: StyleString.aspectRatio,
          mainAxisExtent: 50),
      delegate: SliverChildBuilderDelegate((context, index) {
        return const DynamicCardSkeleton();
      }, childCount: 10),
    );
  }
}
