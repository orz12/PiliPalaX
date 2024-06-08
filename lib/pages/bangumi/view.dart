import 'dart:async';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:nil/nil.dart';
import 'package:PiliPalaX/common/constants.dart';
import 'package:PiliPalaX/common/widgets/http_error.dart';
import 'package:PiliPalaX/pages/home/index.dart';
import 'package:PiliPalaX/pages/main/index.dart';

import '../../utils/grid.dart';
import 'controller.dart';
import 'widgets/bangumi_card_v.dart';

class BangumiPage extends StatefulWidget {
  const BangumiPage({super.key});

  @override
  State<BangumiPage> createState() => _BangumiPageState();
}

class _BangumiPageState extends State<BangumiPage>
    with AutomaticKeepAliveClientMixin {
  final BangumiController _bangumiController = Get.put(BangumiController());
  late Future? _futureBuilderFuture;
  late Future? _futureBuilderFutureFollow;
  late ScrollController scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    scrollController = _bangumiController.scrollController;
    StreamController<bool> mainStream =
        Get.find<MainController>().bottomBarStream;
    StreamController<bool> searchBarStream =
        Get.find<HomeController>().searchBarStream;
    _futureBuilderFuture = _bangumiController.queryBangumiListFeed();
    _futureBuilderFutureFollow = _bangumiController.queryBangumiFollow();
    scrollController.addListener(
      () async {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          EasyThrottle.throttle('my-throttler', const Duration(seconds: 1), () {
            _bangumiController.isLoadingMore = true;
            _bangumiController.onLoad();
          });
        }

        final ScrollDirection direction =
            scrollController.position.userScrollDirection;
        if (direction == ScrollDirection.forward) {
          mainStream.add(true);
          searchBarStream.add(true);
        } else if (direction == ScrollDirection.reverse) {
          mainStream.add(false);
          searchBarStream.add(false);
        }
      },
    );
  }

  @override
  void dispose() {
    scrollController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async {
        await _bangumiController.queryBangumiListFeed();
        return _bangumiController.queryBangumiFollow();
      },
      child: CustomScrollView(
        controller: _bangumiController.scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Obx(
              () => Visibility(
                visible: _bangumiController.userLogin.value,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          top: StyleString.safeSpace, bottom: 10, left: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '最近追番',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            tooltip: '刷新',
                            onPressed: () {
                              setState(() {
                                _futureBuilderFutureFollow =
                                    _bangumiController.queryBangumiFollow();
                              });
                            },
                            icon: const Icon(
                              Icons.refresh,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: Grid.maxRowWidth * 1,
                      child: FutureBuilder(
                        future: _futureBuilderFutureFollow,
                        builder:
                            (BuildContext context, AsyncSnapshot snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            if (snapshot.data == null) {
                              return const SizedBox();
                            }
                            Map data = snapshot.data as Map;
                            List list = _bangumiController.bangumiFollowList;
                            if (data['status']) {
                              return Obx(
                                () => list.isNotEmpty
                                    ? ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: list.length,
                                        itemBuilder: (context, index) {
                                          return Container(
                                            width: Grid.maxRowWidth / 2,
                                            height: Grid.maxRowWidth * 1,
                                            margin: EdgeInsets.only(
                                                left: StyleString.safeSpace,
                                                right: index ==
                                                        _bangumiController
                                                                .bangumiFollowList
                                                                .length -
                                                            1
                                                    ? StyleString.safeSpace
                                                    : 0),
                                            child: BangumiCardV(
                                              bangumiItem: _bangumiController
                                                  .bangumiFollowList[index],
                                            ),
                                          );
                                        },
                                      )
                                    : const SizedBox(
                                        child: Center(
                                          child: Text('还没有追番'),
                                        ),
                                      ),
                              );
                            } else {
                              return nil;
                            }
                          } else {
                            return nil;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10, left: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '推荐',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                StyleString.safeSpace, 0, StyleString.safeSpace, 0),
            sliver: FutureBuilder(
              future: _futureBuilderFuture,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  Map data = snapshot.data as Map;
                  if (data['status']) {
                    return Obx(() => contentGrid(
                        _bangumiController, _bangumiController.bangumiList));
                  } else {
                    return HttpError(
                      errMsg: data['msg'],
                      fn: () {
                        _futureBuilderFuture =
                            _bangumiController.queryBangumiListFeed();
                      },
                    );
                  }
                } else {
                  return contentGrid(_bangumiController, []);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget contentGrid(ctr, bangumiList) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithExtentAndRatio(
        // 行间距
        mainAxisSpacing: StyleString.cardSpace - 2,
        // 列间距
        crossAxisSpacing: StyleString.cardSpace,
        // 最大宽度
        maxCrossAxisExtent: Grid.maxRowWidth / 3 * 2,
        childAspectRatio: 0.65,
        mainAxisExtent: MediaQuery.textScalerOf(context).scale(60),
      ),
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return bangumiList!.isNotEmpty
              ? BangumiCardV(bangumiItem: bangumiList[index])
              : nil;
        },
        childCount: bangumiList!.isNotEmpty ? bangumiList!.length : 10,
      ),
    );
  }
}
