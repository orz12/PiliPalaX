import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

import '../../http/user.dart';
import '../../http/video.dart';
import '../../pages/mine/controller.dart';
import '../../utils/storage.dart';

class VideoPopupMenu extends StatelessWidget {
  final double? size;
  final double? iconSize;
  final dynamic videoItem;
  final double menuItemHeight = 45;

  const VideoPopupMenu({
    Key? key,
    required this.size,
    required this.iconSize,
    required this.videoItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.more_vert_outlined,
          color: Theme.of(context).colorScheme.outline,
          size: iconSize,
        ),
        position: PopupMenuPosition.under,
        onSelected: (String type) {},
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            onTap: () async {
              var res =
                  await UserHttp.toViewLater(bvid: videoItem.bvid as String);
              SmartDialog.showToast(res['msg']);
            },
            value: 'pause',
            height: menuItemHeight,
            child: const Row(
              children: [
                Icon(CupertinoIcons.clock, size: 16),
                SizedBox(width: 6),
                Text('稍后再看', style: TextStyle(fontSize: 13))
              ],
            ),
          ),
          PopupMenuItem<String>(
            onTap: () async {
              Get.toNamed('/member?mid=${videoItem.owner.mid}', arguments: {
                'face': videoItem.owner.face,
                'heroTag': '${videoItem.owner.mid}',
              });
            },
            value: 'visit',
            height: menuItemHeight,
            child: Row(
              children: [
                const Icon(CupertinoIcons.person, size: 16),
                const SizedBox(width: 6),
                Text('访问：${videoItem.owner.name}',
                    style: const TextStyle(fontSize: 13))
              ],
            ),
          ),
          // 不感兴趣
          PopupMenuItem<String>(
            onTap: () async {
              // var res = await VideoHttp.dislike(bvid: videoItem.bvid as String);
              // SmartDialog.showToast(res['msg']);
              SmartDialog.showToast("暂未实现");
            },
            value: 'dislike',
            height: menuItemHeight,
            child: const Row(
              children: [
                Icon(CupertinoIcons.hand_thumbsdown, size: 16),
                SizedBox(width: 6),
                Text('不感兴趣', style: TextStyle(fontSize: 13))
              ],
            ),
          ),
          PopupMenuItem<String>(
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('提示'),
                    content: Text(
                        '确定拉黑:${videoItem.owner.name}(${videoItem.owner.mid})?'
                        '\n\n注：被拉黑的Up可以在隐私设置-黑名单管理中解除'),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text(
                          '点错了',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          var res = await VideoHttp.relationMod(
                            mid: videoItem.owner.mid,
                            act: 5,
                            reSrc: 11,
                          );
                          List<int> blackMidsList = GStrorage.setting
                              .get(SettingBoxKey.blackMidsList,
                                  defaultValue: [-1])
                              .map<int>((i) => i as int)
                              .toList();
                          blackMidsList.insert(0, videoItem.owner.mid);
                          GStrorage.setting
                              .put(SettingBoxKey.blackMidsList, blackMidsList);
                          Get.back();
                          SmartDialog.showToast(res['msg'] ?? '成功');
                        },
                        child: const Text('确认'),
                      )
                    ],
                  );
                },
              );
            },
            value: 'block',
            height: menuItemHeight,
            child: Row(
              children: [
                const Icon(CupertinoIcons.nosign, size: 16),
                const SizedBox(width: 6),
                Text('拉黑：${videoItem.owner.name}',
                    style: const TextStyle(fontSize: 13))
              ],
            ),
          ),
          // PopupMenuItem<String>(
          //   onTap: () async {
          //     SmartDialog.showToast("还没做");
          //   },
          //   value: 'anonymize',
          //   height: menuItemHeight,
          //   child: const Row(
          //     children: [
          //       Icon(Icons.visibility_off_outlined, size: 16),
          //       SizedBox(width: 6),
          //       Text('无痕播放',
          //           style: TextStyle(fontSize: 13))
          //     ],
          //   ),
          // ),
          PopupMenuItem<String>(
            onTap: () {
              MineController.onChangeAnonymity(context);
            },
            value: 'anonymous',
            height: menuItemHeight,
            child: Row(
              children: [
                Icon(
                  MineController.anonymity
                      ? CupertinoIcons.shield_slash
                      : CupertinoIcons.checkmark_shield,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text("${MineController.anonymity ? '退出' : '进入'}无痕模式",
                    style: const TextStyle(fontSize: 13))
              ],
            ),
          ),
        ],
      ),
    );
  }
}
