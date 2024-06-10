import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/models/bangumi/info.dart';
import 'package:PiliPalaX/pages/video/detail/index.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:PiliPalaX/common/widgets/list_sheet.dart';

class BangumiPanel extends StatefulWidget {
  const BangumiPanel({
    super.key,
    required this.pages,
    this.cid,
    required this.changeFuc,
  });

  final List<EpisodeItem> pages;
  final int? cid;
  final Function changeFuc;

  @override
  State<BangumiPanel> createState() => _BangumiPanelState();
}

class _BangumiPanelState extends State<BangumiPanel> {
  late int currentIndex;
  final ScrollController listViewScrollCtr = ScrollController();
  final ScrollController listViewScrollCtr_2 = ScrollController();
  Box userInfoCache = GStrorage.userInfo;
  dynamic userInfo;
  // 默认未开通
  int vipStatus = 0;
  late int cid;
  String heroTag = Get.arguments['heroTag'];
  late final VideoDetailController videoDetailCtr;
  final ItemScrollController itemScrollController = ItemScrollController();

  @override
  void initState() {
    super.initState();
    cid = widget.cid!;
    currentIndex = widget.pages.indexWhere((e) => e.cid == cid);
    scrollToIndex();
    userInfo = userInfoCache.get('userInfoCache');
    if (userInfo != null) {
      vipStatus = userInfo.vipStatus;
    }
    videoDetailCtr = Get.find<VideoDetailController>(tag: heroTag);

    videoDetailCtr.cid.listen((int p0) {
      cid = p0;
      currentIndex = widget.pages.indexWhere((EpisodeItem e) => e.cid == cid);
      if (!mounted) return;
      setState(() {});
      scrollToIndex();
    });
  }

  @override
  void dispose() {
    listViewScrollCtr.dispose();
    listViewScrollCtr_2.dispose();
    super.dispose();
  }

  // void changeFucCall(item, i) async {
  //   if (item.badge != null && item.badge == '会员' && vipStatus != 1) {
  //     SmartDialog.showToast('需要大会员');
  //     return;
  //   }
  //   await widget.changeFuc!(
  //     item.bvid,
  //     item.cid,
  //     item.aid,
  //   );
  //   currentIndex = i;
  //   setState(() {});
  //   scrollToIndex();
  // }

  void scrollToIndex() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 在回调函数中获取更新后的状态
      listViewScrollCtr.animateTo(currentIndex * 150,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('合集 '),
              Expanded(
                child: Text(
                  ' 正在播放：${widget.pages[currentIndex].longTitle}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 34,
                child: TextButton(
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    ListSheet(
                            episodes: widget.pages,
                            bvid: widget.pages[currentIndex].bvid!,
                            aid: widget.pages[currentIndex].aid!,
                            currentCid: cid,
                            changeFucCall: widget.changeFuc,
                            context: context)
                        .buildShowBottomSheet();
                  },
                  child: Text(
                    '全${widget.pages.length}话',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 60,
          child: ListView.builder(
            controller: listViewScrollCtr,
            scrollDirection: Axis.horizontal,
            itemCount: widget.pages.length,
            itemExtent: 150,
            itemBuilder: (BuildContext context, int i) {
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 10),
                child: Material(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  borderRadius: BorderRadius.circular(6),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: () {
                      if (widget.pages[i].badge != null &&
                          widget.pages[i].badge == '会员' &&
                          vipStatus != 1) {
                        SmartDialog.showToast('需要大会员');
                        return;
                      }
                      widget.changeFuc(
                        widget.pages[i].bvid,
                        widget.pages[i].cid,
                        widget.pages[i].aid,
                      );
                      // currentIndex = i;
                      // setState(() {});
                      // scrollToIndex();
                    },
                    //changeFucCall(widget.pages[i], i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: [
                              if (i == currentIndex) ...<Widget>[
                                Image.asset(
                                  'assets/images/live.png',
                                  color: Theme.of(context).colorScheme.primary,
                                  height: 12,
                                  semanticLabel: "正在播放：",
                                ),
                                const SizedBox(width: 6)
                              ],
                              Expanded(
                                  child: Text(
                                widget.pages[i].title ?? '第${i + 1}话',
                                maxLines: (widget.pages[i].longTitle != null &&
                                        widget.pages[i].longTitle != '')
                                    ? 1
                                    : 2,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: i == currentIndex
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                              )),
                              const SizedBox(width: 2),
                              if (widget.pages[i].badge != null) ...[
                                const Spacer(),
                                if (widget.pages[i].badge == '会员') ...[
                                  Image.asset(
                                    'assets/images/big-vip.png',
                                    height: 16,
                                    semanticLabel: "大会员",
                                  ),
                                ],
                                if (widget.pages[i].badge != '会员') ...[
                                  Text(
                                    widget.pages[i].badge!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ]
                            ],
                          ),
                          if (widget.pages[i].longTitle != null &&
                              widget.pages[i].longTitle != '') ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.pages[i].longTitle!,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: i == currentIndex
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                              overflow: TextOverflow.ellipsis,
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}
