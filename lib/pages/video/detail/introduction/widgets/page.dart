import 'dart:math';

import 'package:PiliPalaX/common/widgets/list_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/models/video_detail_res.dart';
import 'package:PiliPalaX/pages/video/detail/index.dart';

import '../../../../../utils/id_utils.dart';

class PagesPanel extends StatefulWidget {
  const PagesPanel({
    super.key,
    required this.pages,
    this.cid,
    required this.bvid,
    required this.changeFuc,
    required this.heroTag,
  });
  final List<Part> pages;
  final int? cid;
  final String bvid;
  final Function changeFuc;
  final String heroTag;

  @override
  State<PagesPanel> createState() => _PagesPanelState();
}

class _PagesPanelState extends State<PagesPanel> {
  late List<Part> episodes;
  late int cid;
  late int currentIndex;
  // final String heroTag = Get.arguments['heroTag'];
  late final String heroTag;
  late VideoDetailController _videoDetailController;
  final ScrollController _scrollController2 = ScrollController();

  @override
  void initState() {
    super.initState();
    cid = widget.cid!;
    episodes = widget.pages;
    heroTag = widget.heroTag;
    _videoDetailController = Get.find<VideoDetailController>(tag: heroTag);
    currentIndex = episodes.indexWhere((Part e) => e.cid == cid);
    _videoDetailController.cid.listen((int p0) {
      cid = p0;
      currentIndex = episodes.indexWhere((Part e) => e.cid == cid);
      if (!mounted) return;
      const double itemWidth = 150; // 每个列表项的宽度
      final double targetOffset = min(
          (currentIndex * itemWidth) - (itemWidth / 2),
          _scrollController2.position.maxScrollExtent);
      // 滑动至目标位置
      _scrollController2.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300), // 滑动动画持续时间
        curve: Curves.easeInOut, // 滑动动画曲线
      );
    });
  }

  @override
  void dispose() {
    _scrollController2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('视频选集 '),
              Expanded(
                child: Text(
                  ' 正在播放：${widget.pages[currentIndex].pagePart}',
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
                      episodes: episodes,
                      bvid: widget.bvid,
                      aid: IdUtils.bv2av(widget.bvid),
                      currentCid: cid,
                      changeFucCall: widget.changeFuc,
                      context: context,
                    ).buildShowBottomSheet();
                  },
                  child: Text(
                    '共${widget.pages.length}集',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 35,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.builder(
            controller: _scrollController2,
            scrollDirection: Axis.horizontal,
            itemCount: widget.pages.length,
            itemExtent: 150,
            itemBuilder: (BuildContext context, int i) {
              bool isCurrentIndex = currentIndex == i;
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 10),
                child: Material(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  borderRadius: BorderRadius.circular(6),
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    onTap: () => {
                      widget.changeFuc(widget.bvid, widget.pages[i].cid,
                          IdUtils.bv2av(widget.bvid))
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 8),
                      child: Row(
                        children: <Widget>[
                          if (isCurrentIndex) ...<Widget>[
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
                            widget.pages[i].pagePart!,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 13,
                                color: isCurrentIndex
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface),
                            overflow: TextOverflow.ellipsis,
                          ))
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
