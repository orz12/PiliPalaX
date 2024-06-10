import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/widgets/video_card_h.dart';
import 'package:PiliPalaX/utils/utils.dart';
import '../../common/constants.dart';
import '../../common/widgets/http_error.dart';
import '../../utils/grid.dart';
import 'controller.dart';

class MemberArchivePage extends StatefulWidget {
  const MemberArchivePage({super.key});

  @override
  State<MemberArchivePage> createState() => _MemberArchivePageState();
}

class _MemberArchivePageState extends State<MemberArchivePage> {
  late MemberArchiveController _memberArchivesController;
  late Future _futureBuilderFuture;
  late ScrollController scrollController;
  late int mid;

  @override
  void initState() {
    super.initState();
    mid = int.parse(Get.parameters['mid']!);
    final String heroTag = Utils.makeHeroTag(mid);
    _memberArchivesController =
        Get.put(MemberArchiveController(), tag: heroTag);
    _futureBuilderFuture = _memberArchivesController.getMemberArchive('init');
    scrollController = _memberArchivesController.scrollController;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          EasyThrottle.throttle(
              'member_archives', const Duration(milliseconds: 500), () {
            _memberArchivesController.onLoad();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Text('Ta的投稿', style: Theme.of(context).textTheme.titleMedium),
        actions: [
          Obx(
            () => TextButton.icon(
              icon: const Icon(Icons.sort, size: 20),
              onPressed: _memberArchivesController.toggleSort,
              label: Text(_memberArchivesController.currentOrder['label']!),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _memberArchivesController.scrollController,
        slivers: [
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: StyleString.safeSpace),
            sliver: FutureBuilder(
              future: _futureBuilderFuture,
              builder: (BuildContext context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.data != null) {
                    Map data = snapshot.data as Map;
                    List list = _memberArchivesController.archivesList;
                    if (data['status']) {
                      return Obx(
                        () => list.isNotEmpty
                            ? SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithExtentAndRatio(
                                        mainAxisSpacing: StyleString.safeSpace,
                                        crossAxisSpacing: StyleString.safeSpace,
                                        maxCrossAxisExtent:
                                            Grid.maxRowWidth * 2,
                                        childAspectRatio:
                                            StyleString.aspectRatio * 2.3,
                                        mainAxisExtent: 0),
                                delegate: SliverChildBuilderDelegate(
                                  (BuildContext context, index) {
                                    return VideoCardH(
                                      videoItem: list[index],
                                      showOwner: false,
                                      showPubdate: true,
                                    );
                                  },
                                  childCount: list.length,
                                ),
                              )
                            : const SliverToBoxAdapter(),
                      );
                    } else {
                      return HttpError(
                        errMsg: snapshot.data['msg'],
                        fn: () {},
                      );
                    }
                  } else {
                    return HttpError(
                      errMsg: "投稿页出现错误",
                      fn: () {},
                    );
                  }
                } else {
                  return const SliverToBoxAdapter();
                }
              },
            ),
          )
        ],
      ),
    );
  }
}
