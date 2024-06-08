import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/pages/member_dynamics/index.dart';
import 'package:PiliPalaX/utils/utils.dart';

import '../../common/constants.dart';
import '../../common/widgets/http_error.dart';
import '../../utils/grid.dart';
import '../../utils/storage.dart';
import '../dynamics/widgets/dynamic_panel.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class MemberDynamicsPage extends StatefulWidget {
  const MemberDynamicsPage({super.key});

  @override
  State<MemberDynamicsPage> createState() => _MemberDynamicsPageState();
}

class _MemberDynamicsPageState extends State<MemberDynamicsPage> {
  late MemberDynamicsController _memberDynamicController;
  late Future _futureBuilderFuture;
  late ScrollController scrollController;
  late int mid;
  late bool dynamicsWaterfallFlow;

  @override
  void initState() {
    super.initState();
    mid = int.parse(Get.parameters['mid']!);
    final String heroTag = Utils.makeHeroTag(mid);
    _memberDynamicController =
        Get.put(MemberDynamicsController(), tag: heroTag);
    _futureBuilderFuture =
        _memberDynamicController.getMemberDynamic('onRefresh');
    scrollController = _memberDynamicController.scrollController;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          EasyThrottle.throttle(
              'member_dynamics', const Duration(milliseconds: 1000), () {
            _memberDynamicController.onLoad();
          });
        }
      },
    );
    dynamicsWaterfallFlow = GStorage.setting
        .get(SettingBoxKey.dynamicsWaterfallFlow, defaultValue: true);
  }

  @override
  void dispose() {
    _memberDynamicController.scrollController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Text('Ta的动态', style: Theme.of(context).textTheme.titleMedium),
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _memberDynamicController.scrollController,
        slivers: [
          FutureBuilder(
            future: _futureBuilderFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.data != null) {
                  Map data = snapshot.data as Map;
                  List list = _memberDynamicController.dynamicsList;
                  if (data['status']) {
                    return Obx(() {
                      if (list.isEmpty) {
                        return const SliverToBoxAdapter();
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
                                      return DynamicPanel(item: list[index]);
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
                          crossAxisSpacing: StyleString.safeSpace,
                          mainAxisSpacing: StyleString.safeSpace,

                          /// follow max child trailing layout offset and layout with full cross axis extend
                          /// last child as loadmore item/no more item in [GridView] and [WaterfallFlow]
                          /// with full cross axis extend
                          //  LastChildLayoutType.fullCrossAxisExtend,

                          /// as foot at trailing and layout with full cross axis extend
                          /// show no more item at trailing when children are not full of viewport
                          /// if children is full of viewport, it's the same as fullCrossAxisExtend
                          //  LastChildLayoutType.foot,
                          lastChildLayoutTypeBuilder: (index) =>
                              index == list.length
                                  ? LastChildLayoutType.foot
                                  : LastChildLayoutType.none,
                          children: [
                            for (var i in list) DynamicPanel(item: i),
                          ]);
                    });
                  } else {
                    return HttpError(
                      errMsg: snapshot.data['msg'],
                      fn: () {},
                    );
                  }
                } else {
                  return HttpError(
                    errMsg: snapshot.data['msg'],
                    fn: () {},
                  );
                }
              } else {
                return const SliverToBoxAdapter();
              }
            },
          ),
        ],
      ),
    );
  }
}
