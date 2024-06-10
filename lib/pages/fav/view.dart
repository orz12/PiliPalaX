import 'package:PiliPalaX/common/skeleton/video_card_h.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/widgets/http_error.dart';
import 'package:PiliPalaX/pages/fav/index.dart';
import 'package:PiliPalaX/pages/fav/widgets/item.dart';

import '../../common/constants.dart';
import '../../utils/grid.dart';

class FavPage extends StatefulWidget {
  const FavPage({super.key});

  @override
  State<FavPage> createState() => _FavPageState();
}

class _FavPageState extends State<FavPage> {
  final FavController _favController = Get.put(FavController());
  late Future _futureBuilderFuture;
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    _futureBuilderFuture = _favController.queryFavFolder();
    scrollController = _favController.scrollController;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 300) {
          EasyThrottle.throttle('history', const Duration(seconds: 1), () {
            _favController.onLoad();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          '我的收藏',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed(
                '/favSearch?searchType=1&mediaId=${_favController.favFolderData.value.list!.first.id}'),
            icon: const Icon(Icons.search_outlined),
            tooltip: '搜索',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder(
        future: _futureBuilderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            Map data = snapshot.data as Map;
            if (data['status']) {
              return Obx(() => CustomScrollView(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverGrid(
                          gridDelegate: SliverGridDelegateWithExtentAndRatio(
                              mainAxisSpacing: StyleString.cardSpace,
                              crossAxisSpacing: StyleString.safeSpace,
                              maxCrossAxisExtent: Grid.maxRowWidth * 2,
                              childAspectRatio: StyleString.aspectRatio * 2.3,
                              mainAxisExtent: 0),
                          delegate: SliverChildBuilderDelegate(
                            childCount:
                                _favController.favFolderData.value.list!.length,
                            (BuildContext context, int index) {
                              return FavItem(
                                  favFolderItem: _favController
                                      .favFolderData.value.list![index]);
                            },
                          ),
                        )
                      ]));
            } else {
              return CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  HttpError(
                    errMsg: data['msg'],
                    fn: () => setState(() {}),
                  ),
                ],
              );
            }
          } else {
            // 骨架屏
            return CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithExtentAndRatio(
                      mainAxisSpacing: StyleString.cardSpace,
                      crossAxisSpacing: StyleString.safeSpace,
                      maxCrossAxisExtent: Grid.maxRowWidth * 2,
                      childAspectRatio: StyleString.aspectRatio * 2.3,
                      mainAxisExtent: 0),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      return const VideoCardHSkeleton();
                    },
                    childCount: 10,
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
