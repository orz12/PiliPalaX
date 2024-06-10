import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/constants.dart';
import 'package:PiliPalaX/common/widgets/animated_dialog.dart';
import 'package:PiliPalaX/common/widgets/overlay_pop.dart';
import 'package:PiliPalaX/common/skeleton/video_card_h.dart';
import 'package:PiliPalaX/common/widgets/http_error.dart';
import 'package:PiliPalaX/common/widgets/video_card_h.dart';
import 'package:PiliPalaX/pages/home/index.dart';
import 'package:PiliPalaX/pages/hot/controller.dart';
import 'package:PiliPalaX/pages/main/index.dart';

import '../../utils/grid.dart';

class HotPage extends StatefulWidget {
  const HotPage({Key? key}) : super(key: key);

  @override
  State<HotPage> createState() => _HotPageState();
}

class _HotPageState extends State<HotPage> with AutomaticKeepAliveClientMixin {
  final HotController _hotController = Get.put(HotController());
  List videoList = [];
  Future? _futureBuilderFuture;
  late ScrollController scrollController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = _hotController.queryHotFeed('init');
    scrollController = _hotController.scrollController;
    StreamController<bool> mainStream =
        Get.find<MainController>().bottomBarStream;
    StreamController<bool> searchBarStream =
        Get.find<HomeController>().searchBarStream;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          if (!_hotController.isLoadingMore) {
            _hotController.isLoadingMore = true;
            _hotController.onLoad();
          }
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
        return await _hotController.onRefresh();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _hotController.scrollController,
        slivers: [
          SliverPadding(
            // 单列布局 EdgeInsets.zero
            padding: const EdgeInsets.fromLTRB(
                StyleString.safeSpace, StyleString.safeSpace - 5, 0, 0),
            sliver: FutureBuilder(
              future: _futureBuilderFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  Map data = snapshot.data as Map;
                  if (data['status']) {
                    return Obx(
                      () => SliverGrid(
                        gridDelegate: SliverGridDelegateWithExtentAndRatio(
                            mainAxisSpacing: StyleString.safeSpace,
                            crossAxisSpacing: StyleString.safeSpace,
                            maxCrossAxisExtent: Grid.maxRowWidth * 2,
                            childAspectRatio: StyleString.aspectRatio * 2.3,
                            mainAxisExtent: 0),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return VideoCardH(
                            videoItem: _hotController.videoList[index],
                            showPubdate: true,
                            longPress: () {
                              _hotController.popupDialog = _createPopupDialog(
                                  _hotController.videoList[index]);
                              Overlay.of(context)
                                  .insert(_hotController.popupDialog!);
                            },
                            longPressEnd: () {
                              _hotController.popupDialog?.remove();
                            },
                          );
                        }, childCount: _hotController.videoList.length),
                      ),
                    );
                  } else {
                    return HttpError(
                      errMsg: data['msg'],
                      fn: () {
                        setState(() {
                          _futureBuilderFuture =
                              _hotController.queryHotFeed('init');
                        });
                      },
                    );
                  }
                } else {
                  // 骨架屏
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        mainAxisSpacing: StyleString.cardSpace,
                        crossAxisSpacing: StyleString.cardSpace,
                        maxCrossAxisExtent: Grid.maxRowWidth * 2,
                        childAspectRatio: StyleString.aspectRatio * 2.3),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return const VideoCardHSkeleton();
                    }, childCount: 10),
                  );
                }
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 10,
            ),
          )
        ],
      ),
    );
  }

  OverlayEntry _createPopupDialog(videoItem) {
    return OverlayEntry(
      builder: (context) => AnimatedDialog(
        closeFn: _hotController.popupDialog?.remove,
        child: OverlayPop(
            videoItem: videoItem, closeFn: _hotController.popupDialog?.remove),
      ),
    );
  }
}
