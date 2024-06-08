import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../utils/storage.dart';
import '../../utils/utils.dart';

class ListSheet {
  final dynamic episodes;
  final String? bvid;
  final int? aid;
  final int currentCid;
  final Function changeFucCall;
  final BuildContext context;
  PersistentBottomSheetController? bottomSheetController;
  ListSheet({
    required this.episodes,
    this.bvid,
    this.aid,
    required this.currentCid,
    required this.changeFucCall,
    required this.context,
  });

  Widget buildEpisodeListItem(
    dynamic episode,
    int index,
    bool isCurrentIndex,
    PersistentBottomSheetController bottomSheetController,
  ) {
    Color primary = Theme.of(context).colorScheme.primary;
    late String title;
    if (episode.runtimeType.toString() == "EpisodeItem") {
      if (episode.longTitle != null && episode.longTitle != "") {
        title = "第${(episode.title ?? '${index + 1}')}话  ${episode.longTitle!}";
      } else {
        title = episode.title!;
      }
    } else if (episode.runtimeType.toString() == "PageItem") {
      title = episode.pagePart!;
    } else if (episode.runtimeType.toString() == "Part") {
      title = episode.pagePart!;
      // print("未知类型：${episode.runtimeType}");
    }
    return ListTile(
      onTap: () {
        if (episode.badge != null && episode.badge == "会员") {
          dynamic userInfo = GStorage.userInfo.get('userInfoCache');
          int vipStatus = 0;
          if (userInfo != null) {
            vipStatus = userInfo.vipStatus;
          }
          if (vipStatus != 1) {
            SmartDialog.showToast('需要大会员');
            return;
          }
        }
        SmartDialog.showToast('切换到：$title');
        bottomSheetController.close();
        if (episode.runtimeType.toString() == "EpisodeItem") {
          changeFucCall(episode.bvid, episode.cid, episode.aid);
        } else {
          changeFucCall(bvid!, episode.cid, aid!);
        }
      },
      dense: false,
      leading: isCurrentIndex
          ? Image.asset(
              'assets/images/live.png',
              color: primary,
              height: 12,
              semanticLabel: "正在播放：",
            )
          : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: isCurrentIndex
              ? primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: episode.badge == null
          ? null
          : (episode.badge == '会员'
              ? Image.asset(
                  'assets/images/big-vip.png',
                  height: 20,
                  semanticLabel: "大会员",
                )
              : Text(episode.badge)),
    );
  }

  void buildShowBottomSheet() {
    int currentIndex =
        episodes!.indexWhere((dynamic e) => e.cid == currentCid) ?? 0;
    final ItemScrollController itemScrollController = ItemScrollController();
    bottomSheetController = showBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            itemScrollController.jumpTo(index: currentIndex);
          });
          return Container(
            height: Utils.getSheetHeight(context),
            color: Theme.of(context).colorScheme.background,
            child: Column(
              children: [
                Container(
                  height: 45,
                  padding: const EdgeInsets.only(left: 14, right: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '合集（${episodes!.length}）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        tooltip: '关闭',
                        icon: const Icon(Icons.close),
                        onPressed: () => bottomSheetController!.close(),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
                Expanded(
                  child: Material(
                    child: ScrollablePositionedList.builder(
                      itemCount: episodes!.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        bool isLastItem = index == episodes!.length;
                        bool isCurrentIndex = currentIndex == index;
                        return isLastItem
                            ? SizedBox(
                                height:
                                    MediaQuery.of(context).padding.bottom + 20,
                              )
                            : buildEpisodeListItem(
                                episodes![index],
                                index,
                                isCurrentIndex,
                                bottomSheetController!,
                              );
                      },
                      itemScrollController: itemScrollController,
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
