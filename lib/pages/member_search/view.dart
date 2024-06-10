import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/skeleton/video_card_h.dart';
import 'package:PiliPalaX/common/widgets/http_error.dart';
import 'package:PiliPalaX/common/widgets/no_data.dart';
import 'package:PiliPalaX/common/widgets/video_card_h.dart';

import '../../common/constants.dart';
import '../../utils/grid.dart';
import 'controller.dart';

class MemberSearchPage extends StatefulWidget {
  const MemberSearchPage({super.key});

  @override
  State<MemberSearchPage> createState() => _MemberSearchPageState();
}

class _MemberSearchPageState extends State<MemberSearchPage>
    with SingleTickerProviderStateMixin {
  final MemberSearchController _memberSearchCtr =
      Get.put(MemberSearchController());
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = _memberSearchCtr.scrollController;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 300) {
          EasyThrottle.throttle('history', const Duration(seconds: 1), () {
            _memberSearchCtr.onLoad();
          });
        }
      },
    );
    // _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          actions: [
            IconButton(
                tooltip: '搜索',
                onPressed: () => _memberSearchCtr.submit(),
                icon: const Icon(CupertinoIcons.search, size: 22)),
            const SizedBox(width: 10)
          ],
          title: Obx(
            () => TextField(
              autofocus: true,
              focusNode: _memberSearchCtr.searchFocusNode,
              controller: _memberSearchCtr.controller.value,
              textInputAction: TextInputAction.search,
              onChanged: (value) => _memberSearchCtr.onChange(value),
              decoration: InputDecoration(
                hintText: _memberSearchCtr.hintText,
                border: InputBorder.none,
                suffixIcon: IconButton(
                  tooltip: '清空',
                  icon: Icon(
                    Icons.clear,
                    size: 22,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  onPressed: () => _memberSearchCtr.onClear(),
                ),
              ),
              onSubmitted: (String value) => _memberSearchCtr.submit(),
            ),
          ),
        ),
        body: Obx(
          () {
            if (_memberSearchCtr.loadingStatus.value == 'init') {
              return Center(
                child: Text('搜索「${_memberSearchCtr.uname.value}」的动态、视频'),
              );
            }
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: scrollController,
              slivers: <Widget>[
                FutureBuilder(
                  future: _memberSearchCtr.searchArchives(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      Map data = snapshot.data as Map;
                      if (data['status']) {
                        return SliverPadding(
                            padding:
                                const EdgeInsets.all(StyleString.safeSpace),
                            sliver: Obx(
                              () => _memberSearchCtr.archiveList.isNotEmpty
                                  ? SliverGrid(
                                      gridDelegate:
                                          SliverGridDelegateWithExtentAndRatio(
                                              mainAxisSpacing: StyleString
                                                  .safeSpace,
                                              crossAxisSpacing: StyleString
                                                  .safeSpace,
                                              maxCrossAxisExtent: Grid.maxRowWidth *
                                                  2,
                                              childAspectRatio:
                                                  StyleString.aspectRatio * 2.3,
                                              mainAxisExtent: 0),
                                      delegate: SliverChildBuilderDelegate(
                                          (context, index) {
                                        return VideoCardH(
                                            videoItem: _memberSearchCtr
                                                .archiveList[index]);
                                      },
                                          childCount: _memberSearchCtr.archiveList
                                              .length))
                                  : _memberSearchCtr.loadingStatus.value ==
                                          'loading'
                                      ? SliverGrid(
                                          gridDelegate:
                                              SliverGridDelegateWithExtentAndRatio(
                                                  mainAxisSpacing:
                                                      StyleString.cardSpace,
                                                  crossAxisSpacing:
                                                      StyleString.safeSpace,
                                                  maxCrossAxisExtent:
                                                      Grid.maxRowWidth * 2,
                                                  childAspectRatio:
                                                      StyleString.aspectRatio *
                                                          2.1,
                                                  mainAxisExtent: 0),
                                          delegate: SliverChildBuilderDelegate(
                                              (context, index) {
                                            return const VideoCardHSkeleton();
                                          }, childCount: 10))
                                      : const NoData(),
                            ));
                      } else {
                        return HttpError(
                          errMsg: data['msg'],
                          fn: () => setState(() {}),
                        );
                      }
                    } else {
                      // 骨架屏
                      return SliverPadding(
                          padding: const EdgeInsets.all(StyleString.safeSpace),
                          sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithExtentAndRatio(
                                      mainAxisSpacing: StyleString.cardSpace,
                                      crossAxisSpacing: StyleString.safeSpace,
                                      maxCrossAxisExtent: Grid.maxRowWidth * 2,
                                      childAspectRatio:
                                          StyleString.aspectRatio * 2.3,
                                      mainAxisExtent: 0),
                              delegate:
                                  SliverChildBuilderDelegate((context, index) {
                                return const VideoCardHSkeleton();
                              }, childCount: 10)));
                    }
                  },
                ),
              ],
            );
          },
        ));
  }
}
