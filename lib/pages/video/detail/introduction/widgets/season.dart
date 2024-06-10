import 'package:PiliPalaX/common/widgets/list_sheet.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/models/video_detail_res.dart';
import 'package:PiliPalaX/pages/video/detail/index.dart';

class SeasonPanel extends StatefulWidget {
  const SeasonPanel({
    super.key,
    required this.ugcSeason,
    this.cid,
    required this.changeFuc,
    required this.heroTag,
  });
  final UgcSeason ugcSeason;
  final int? cid;
  final Function changeFuc;
  final String heroTag;

  @override
  State<SeasonPanel> createState() => _SeasonPanelState();
}

class _SeasonPanelState extends State<SeasonPanel> {
  List<EpisodeItem>? episodes;
  late int cid;
  int currentIndex = 0;
  // final String heroTag = Get.arguments['heroTag'];
  late final String heroTag;
  late VideoDetailController _videoDetailController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    cid = widget.cid!;
    heroTag = widget.heroTag;
    _videoDetailController = Get.find<VideoDetailController>(tag: heroTag);

    /// 根据 cid 找到对应集，找到对应 episodes
    /// 有多个episodes时，只显示其中一个
    /// TODO 同时显示多个合集
    final List<SectionItem> sections = widget.ugcSeason.sections!;
    for (int i = 0; i < sections.length; i++) {
      final List<EpisodeItem> episodesList = sections[i].episodes!;
      for (int j = 0; j < episodesList.length; j++) {
        if (episodesList[j].cid == cid) {
          episodes = episodesList;
          continue;
        }
      }
    }
    if (episodes == null) {
      return;
    }

    /// 取对应 season_id 的 episodes
    // episodes = widget.ugcSeason.sections!
    //     .firstWhere((e) => e.seasonId == widget.ugcSeason.id)
    //     .episodes!;
    currentIndex = episodes!.indexWhere((EpisodeItem e) => e.cid == cid);
    _videoDetailController.cid.listen((int p0) {
      cid = p0;
      currentIndex = episodes!.indexWhere((EpisodeItem e) => e.cid == cid);
      if (!mounted) return;
      setState(() {});
    });
  }

  // void changeFucCall(item, int i) async {
  //   await widget.changeFuc!(
  //     IdUtils.av2bv(item.aid),
  //     item.cid,
  //     item.aid,
  //   );
  //   currentIndex = i;
  //   Get.back();
  //   setState(() {});
  // }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (episodes == null) {
      return const SizedBox();
    }
    return Builder(builder: (BuildContext context) {
      return Container(
        margin: const EdgeInsets.only(
          top: 8,
          left: 2,
          right: 2,
          bottom: 2,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.onInverseSurface,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () {
              ListSheet(
                      episodes: episodes,
                      // bvid: IdUtils.av2bv(episodes!.first.aid!),
                      // aid: episodes!.first.aid!,
                      currentCid: cid,
                      changeFucCall: widget.changeFuc,
                      context: context)
                  .buildShowBottomSheet();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '合集：${widget.ugcSeason.title!}',
                      style: Theme.of(context).textTheme.labelMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Image.asset(
                    'assets/images/live.png',
                    color: Theme.of(context).colorScheme.primary,
                    height: 12,
                    semanticLabel: "正在播放：",
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${currentIndex + 1}/${episodes!.length}',
                    style: Theme.of(context).textTheme.labelMedium,
                    semanticsLabel:
                        '第${currentIndex + 1}集，共${episodes!.length}集',
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios_outlined,
                    size: 13,
                    semanticLabel: '查看',
                  )
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
