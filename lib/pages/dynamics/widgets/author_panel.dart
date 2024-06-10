import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/http/user.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/utils.dart';
import 'package:share_plus/share_plus.dart';

import '../../../http/constants.dart';
import '../controller.dart';

class AuthorPanel extends StatelessWidget {
  final dynamic item;
  final Function? addBannedList;
  const AuthorPanel({super.key, required this.item, this.addBannedList});

  @override
  Widget build(BuildContext context) {
    String heroTag = Utils.makeHeroTag(item.modules.moduleAuthor.mid);
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            // 番剧
            if (item.modules.moduleAuthor.type == 'AUTHOR_TYPE_PGC') {
              return;
            }
            feedBack();
            Get.toNamed(
              '/member?mid=${item.modules.moduleAuthor.mid}',
              arguments: {
                'face': item.modules.moduleAuthor.face,
                'heroTag': heroTag
              },
            );
          },
          child: Hero(
            tag: heroTag,
            child: NetworkImgLayer(
              width: 40,
              height: 40,
              type: 'avatar',
              src: item.modules.moduleAuthor.face,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item.modules.moduleAuthor.name,
                  // semanticsLabel: "Up主：${item.modules.moduleAuthor.name}",
                  style: TextStyle(
                    color: item.modules.moduleAuthor!.vip != null &&
                            item.modules.moduleAuthor!.vip['status'] > 0
                        ? const Color.fromARGB(255, 251, 100, 163)
                        : Theme.of(context).colorScheme.onBackground,
                    fontSize: Theme.of(context).textTheme.titleSmall!.fontSize,
                  ),
                ),
              ],
            ),
            DefaultTextStyle.merge(
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: Theme.of(context).textTheme.labelSmall!.fontSize,
              ),
              child: Row(
                children: [
                  Text(item.modules.moduleAuthor.pubTime),
                  if (item.modules.moduleAuthor.pubTime != '' &&
                      item.modules.moduleAuthor.pubAction != '')
                    const Text(' '),
                  Text(item.modules.moduleAuthor.pubAction),
                ],
              ),
            )
          ],
        ),
        const Spacer(),
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            tooltip: '更多',
            style: ButtonStyle(
              padding: MaterialStateProperty.all(EdgeInsets.zero),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                builder: (context) {
                  return MorePanel(item: item);
                },
              );
            },
            icon: const Icon(Icons.more_vert_outlined, size: 18),
          ),
        ),
      ],
    );
  }
}

class MorePanel extends StatelessWidget {
  final dynamic item;
  const MorePanel({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      // clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => Get.back(),
            child: Container(
              height: 35,
              padding: const EdgeInsets.only(bottom: 2),
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: const BorderRadius.all(Radius.circular(3))),
                ),
              ),
            ),
          ),
          if (item.type == 'DYNAMIC_TYPE_AV')
            ListTile(
              onTap: () async {
                try {
                  String bvid = item.modules.moduleDynamic.major.archive.bvid;
                  var res = await UserHttp.toViewLater(bvid: bvid);
                  SmartDialog.showToast(res['msg']);
                  Get.back();
                } catch (err) {
                  SmartDialog.showToast('出错了：${err.toString()}');
                }
              },
              minLeadingWidth: 0,
              // dense: true,
              leading: const Icon(Icons.watch_later_outlined, size: 19),
              title: Text(
                '稍后再看',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ListTile(
            title: Text(
              '分享动态',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            leading: const Icon(Icons.share_outlined, size: 19),
            onTap: () async {
              var result = await Share.share(
                      '${HttpString.baseUrl}/dynamic/${item.idStr} UP主: ${item.modules.moduleAuthor.name}')
                  .whenComplete(() {});
              return result;
            },
            minLeadingWidth: 0,
          ),
          ListTile(
            title: Text(
              '临时屏蔽：${item.modules.moduleAuthor.name}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            leading: const Icon(Icons.visibility_off_outlined, size: 19),
            onTap: () {
              Get.back();
              DynamicsController dynamicsController =
                  Get.find<DynamicsController>();
              dynamicsController.tempBannedList
                  .add(item.modules.moduleAuthor.mid);
              SmartDialog.showToast(
                  '已临时屏蔽${item.modules.moduleAuthor.name}(${item.modules.moduleAuthor.mid})，重启恢复');
            },
            minLeadingWidth: 0,
          ),
          const Divider(thickness: 0.1, height: 1),
          ListTile(
            onTap: () => Get.back(),
            minLeadingWidth: 0,
            dense: true,
            title: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
