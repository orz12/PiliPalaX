import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/models/user/fav_folder.dart';
import 'package:PiliPalaX/pages/main/index.dart';
import 'package:PiliPalaX/pages/media/index.dart';
import 'package:PiliPalaX/utils/utils.dart';

class MediaPage extends StatefulWidget {
  const MediaPage({super.key});

  @override
  State<MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<MediaPage>
    with AutomaticKeepAliveClientMixin {
  late MediaController mediaController;
  late Future _futureBuilderFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    mediaController = Get.put(MediaController());
    _futureBuilderFuture = mediaController.queryFavFolder();
    ScrollController scrollController = mediaController.scrollController;
    StreamController<bool> mainStream =
        Get.find<MainController>().bottomBarStream;

    mediaController.userLogin.listen((status) {
      setState(() {
        _futureBuilderFuture = mediaController.queryFavFolder();
      });
    });
    scrollController.addListener(
      () {
        final ScrollDirection direction =
            scrollController.position.userScrollDirection;
        if (direction == ScrollDirection.forward) {
          mainStream.add(true);
        } else if (direction == ScrollDirection.reverse) {
          mainStream.add(false);
        }
      },
    );
  }

  @override
  void dispose() {
    mediaController.scrollController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Color primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 30,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.light
                  ? Brightness.dark
                  : Brightness.light,
        ),
      ),
      body: SingleChildScrollView(
        controller: mediaController.scrollController,
        child: Column(
          children: [
            ListTile(
              leading: null,
              title: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  '媒体库',
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.titleLarge!.fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              trailing: IconButton(
                tooltip: '设置',
                onPressed: () {
                  Get.toNamed('/setting');
                },
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 20,
                ),
              ),
            ),
            // 网格视图替代 for 循环
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              child: GridView.builder(
                physics:
                    const NeverScrollableScrollPhysics(), // 禁用GridView自己的滚动，防止冲突
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 0, // 网格之间的水平间距
                  mainAxisSpacing: 10, // 网格之间的垂直间距
                  childAspectRatio: 4, // 宽高比，1表示正方形网格
                ),
                itemCount: mediaController.list.length,
                itemBuilder: (context, index) {
                  var item = mediaController.list[index];
                  return GestureDetector(
                    onTap: () => item['onTap'](),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'],
                          color: primary,
                          size: 30, // 图标大小
                        ),
                        const SizedBox(width: 8), // 图标和文字之间的间距
                        Text(
                          item['title'],
                          style: const TextStyle(fontSize: 14),
                          // textAlign: TextAlign.center, // 文字居中
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Obx(() => mediaController.userLogin.value
                ? favFolder(mediaController, context)
                : const SizedBox(height: 0))
          ],
        ),
      ),
    );
  }

  Widget favFolder(mediaController, context) {
    return Column(
      children: [
        Divider(
          height: 20,
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
        ListTile(
          onTap: () => Get.toNamed('/fav'),
          leading: null,
          dense: true,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Obx(
              () => Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '我的收藏  ',
                      style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.titleMedium!.fontSize,
                          fontWeight: FontWeight.bold),
                    ),
                    if (mediaController.favFolderData.value.count != null)
                      TextSpan(
                        text: "${mediaController.favFolderData.value.count}  ",
                        style: TextStyle(
                          fontSize:
                              Theme.of(context).textTheme.titleSmall!.fontSize,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    WidgetSpan(
                        child: Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    )),
                  ],
                ),
              ),
            ),
          ),
          trailing: IconButton(
            tooltip: '刷新',
            onPressed: () {
              setState(() {
                _futureBuilderFuture = mediaController.queryFavFolder();
              });
            },
            icon: const Icon(
              Icons.refresh,
              size: 20,
            ),
          ),
        ),
        // const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: MediaQuery.textScalerOf(context).scale(200),
          child: FutureBuilder(
              future: _futureBuilderFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.data == null) {
                    return const SizedBox();
                  }
                  Map data = snapshot.data as Map;
                  if (data['status']) {
                    List favFolderList =
                        mediaController.favFolderData.value.list!;
                    int favFolderCount =
                        mediaController.favFolderData.value.count!;
                    bool flag = favFolderCount > favFolderList.length;
                    return Obx(() => ListView.builder(
                          itemCount:
                              mediaController.favFolderData.value.list!.length +
                                  (flag ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (flag && index == favFolderList.length) {
                              return Padding(
                                  padding: const EdgeInsets.only(
                                      right: 14, bottom: 35),
                                  child: Center(
                                    child: IconButton(
                                      tooltip: '查看更多',
                                      style: ButtonStyle(
                                        padding: MaterialStateProperty.all(
                                            EdgeInsets.zero),
                                        backgroundColor:
                                            MaterialStateProperty.resolveWith(
                                                (states) {
                                          return Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withOpacity(0.5);
                                        }),
                                      ),
                                      onPressed: () => Get.toNamed('/fav'),
                                      icon: Icon(
                                        Icons.arrow_forward_ios,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ));
                            } else {
                              return FavFolderItem(
                                  item: mediaController
                                      .favFolderData.value.list![index],
                                  index: index);
                            }
                          },
                          scrollDirection: Axis.horizontal,
                        ));
                  } else {
                    return SizedBox(
                      height: 160,
                      child: Center(child: Text(data['msg'])),
                    );
                  }
                } else {
                  // 骨架屏
                  return const SizedBox();
                }
              }),
        ),
      ],
    );
  }
}

class FavFolderItem extends StatelessWidget {
  const FavFolderItem({super.key, this.item, this.index});
  final FavFolderItemData? item;
  final int? index;
  @override
  Widget build(BuildContext context) {
    String heroTag = Utils.makeHeroTag(item!.fid);

    return Container(
      margin: EdgeInsets.only(left: index == 0 ? 20 : 0, right: 14),
      child: GestureDetector(
        onTap: () => Get.toNamed('/favDetail',
            arguments: item,
            parameters: {'mediaId': item!.id.toString(), 'heroTag': heroTag}),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 180,
              height: 110,
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context)
                    .colorScheme
                    .onInverseSurface
                    .withOpacity(0.4),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .onInverseSurface
                        .withOpacity(0.4),
                    offset: const Offset(4, -12), // 阴影与容器的距离
                    blurRadius: 0.0, // 高斯的标准偏差与盒子的形状卷积。
                    spreadRadius: 0.0, // 在应用模糊之前，框应该膨胀的量。
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, BoxConstraints box) {
                  return Hero(
                    tag: heroTag,
                    child: NetworkImgLayer(
                      src: item!.cover,
                      width: box.maxWidth,
                      height: box.maxHeight,
                    ),
                  );
                },
              ),
            ),
            Text(
              ' ${item!.title}',
              overflow: TextOverflow.fade,
              maxLines: 1,
            ),
            Text(
              ' 共${item!.mediaCount}条视频',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall!
                  .copyWith(color: Theme.of(context).colorScheme.outline),
            )
          ],
        ),
      ),
    );
  }
}
