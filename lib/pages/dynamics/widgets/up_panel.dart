import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/models/dynamics/up.dart';
import 'package:PiliPalaX/models/live/item.dart';
import 'package:PiliPalaX/pages/dynamics/controller.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/utils/utils.dart';

class UpPanel extends StatefulWidget {
  final FollowUpModel? upData;
  const UpPanel(this.upData, {Key? key}) : super(key: key);

  @override
  State<UpPanel> createState() => _UpPanelState();
}

class _UpPanelState extends State<UpPanel> {
  final ScrollController scrollController = ScrollController();
  int currentMid = -1;
  late double contentWidth = 56;
  List<UpItem> upList = [];
  List<LiveUserItem> liveList = [];
  static const itemPadding = EdgeInsets.symmetric(horizontal: 5, vertical: 0);
  Box userInfoCache = GStrorage.userInfo;
  var userInfo;

  @override
  void initState() {
    super.initState();
    userInfo = userInfoCache.get('userInfoCache');
  }

  @override
  Widget build(BuildContext context) {
    upList = widget.upData!.upList!;
    if (widget.upData!.liveUsers != null) {
      liveList = widget.upData!.liveUsers!.items!;
    }
    return SliverPersistentHeader(
      floating: true,
      pinned: false,
      delegate: _SliverHeaderDelegate(
          height: 126,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Theme.of(context).colorScheme.background,
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('最新关注'),
                    GestureDetector(
                      onTap: () {
                        feedBack();
                        Get.toNamed('/follow?mid=${userInfo.mid}');
                      },
                      child: Container(
                        padding: const EdgeInsets.only(top: 5, bottom: 5),
                        child: Text(
                          '查看全部',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 90,
                color: Theme.of(context).colorScheme.background,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        controller: scrollController,
                        children: [
                          const SizedBox(width: 10),
                          if (liveList.isNotEmpty) ...[
                            for (int i = 0; i < liveList.length; i++) ...[
                              upItemBuild(liveList[i], i)
                            ],
                            VerticalDivider(
                              indent: 20,
                              endIndent: 40,
                              width: 26,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.5),
                            ),
                          ],
                          upItemBuild(
                              UpItem(face: '', uname: '全部动态', mid: -1), 0),
                          upItemBuild(
                              UpItem(
                                face: userInfo.face,
                                uname: '我',
                                mid: userInfo.mid,
                              ),
                              1),
                          for (int i = 0; i < upList.length; i++) ...[
                            upItemBuild(upList[i], i + 2)
                          ],
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 6,
                color: Theme.of(context)
                    .colorScheme
                    .onInverseSurface
                    .withOpacity(0.5),
              ),
            ],
          )),
    );
  }

  Widget upItemBuild(data, i) {
    bool isCurrent = currentMid == data.mid || currentMid == -1;
    return InkWell(
      onTap: () {
        feedBack();
        if (data.type == 'up') {
          currentMid = data.mid;
          Get.find<DynamicsController>().mid.value = data.mid;
          Get.find<DynamicsController>().upInfo.value = data;
          Get.find<DynamicsController>().onSelectUp(data.mid);
          int liveLen = liveList.length;
          int upLen = upList.length;
          double itemWidth = contentWidth + itemPadding.horizontal;
          double screenWidth = MediaQuery.sizeOf(context).width;
          double moveDistance = 0.0;
          if (itemWidth * (upList.length + liveList.length) <= screenWidth) {
          } else if ((upLen - i - 0.5) * itemWidth > screenWidth / 2) {
            moveDistance =
                (i + liveLen + 0.5) * itemWidth + 46 - screenWidth / 2;
          } else {
            moveDistance = (upLen + liveLen) * itemWidth + 46 - screenWidth;
          }
          data.hasUpdate = false;
          scrollController.animateTo(
            moveDistance,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );

          setState(() {});
        } else if (data.type == 'live') {
          LiveItemModel liveItem = LiveItemModel.fromJson({
            'title': data.title,
            'uname': data.uname,
            'face': data.face,
            'roomid': data.roomId,
          });
          Get.toNamed(
            '/liveRoom?roomid=${data.roomId}',
            arguments: {'liveItem': liveItem},
          );
        }
      },
      onLongPress: () {
        feedBack();
        if (data.mid == -1) {
          return;
        }
        String heroTag = Utils.makeHeroTag(data.mid);
        Get.toNamed('/member?mid=${data.mid}',
            arguments: {'face': data.face, 'heroTag': heroTag});
      },
      child: Padding(
        padding: itemPadding,
        child: AnimatedOpacity(
          opacity: isCurrent ? 1 : 0.3,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                smallSize: 8,
                label: data.type == 'live' ? const Text('Live') : null,
                textColor: Theme.of(context).colorScheme.onSecondaryContainer,
                alignment: data.type == 'live'
                    ? AlignmentDirectional.topCenter
                    : AlignmentDirectional.topEnd,
                padding: const EdgeInsets.only(left: 6, right: 6),
                isLabelVisible: data.type == 'live' ||
                    (data.type == 'up' && (data.hasUpdate ?? false)),
                backgroundColor: data.type == 'live'
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.primary,
                child: data.face != ''
                    ? NetworkImgLayer(
                        width: 50,
                        height: 50,
                        src: data.face,
                        type: 'avatar',
                      )
                    : const CircleAvatar(
                        radius: 25,
                        backgroundImage: AssetImage(
                          'assets/images/noface.jpeg',
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: contentWidth,
                  child: Text(
                    data.uname,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: currentMid == data.mid
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        fontSize:
                            Theme.of(context).textTheme.labelMedium!.fontSize),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SliverHeaderDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

class UpPanelSkeleton extends StatelessWidget {
  const UpPanelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      itemBuilder: ((context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 45,
                height: 12,
                color: Theme.of(context).colorScheme.onInverseSurface,
              ),
            ],
          ),
        );
      }),
    );
  }
}
