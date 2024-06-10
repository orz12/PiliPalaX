import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/utils/utils.dart';

import '../../../common/constants.dart';
import '../../../utils/grid.dart';

Widget searchUserPanel(BuildContext context, ctr, list) {
  TextStyle style = TextStyle(
      fontSize: Theme.of(context).textTheme.labelSmall!.fontSize,
      color: Theme.of(context).colorScheme.outline);

  return CustomScrollView(controller: ctr.scrollController, slivers: [
    SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisSpacing: StyleString.cardSpace,
            crossAxisSpacing: StyleString.safeSpace,
            maxCrossAxisExtent: Grid.maxRowWidth * 2,
            mainAxisExtent: 56),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int index) {
            var i = list![index];
            String heroTag = Utils.makeHeroTag(i!.mid);
            return InkWell(
              onTap: () => Get.toNamed('/member?mid=${i.mid}',
                  arguments: {'heroTag': heroTag, 'face': i.upic}),
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  Hero(
                    tag: heroTag,
                    child: NetworkImgLayer(
                      width: 42,
                      height: 42,
                      src: i.upic,
                      type: 'avatar',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            i!.uname,
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Image.asset(
                            'assets/images/lv/lv${i!.level}.png',
                            height: 11,
                            semanticLabel: '等级${i.level}',
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text('粉丝：${i.fans} ', style: style),
                          Text(' 视频：${i.videos}', style: style)
                        ],
                      ),
                      if (i.officialVerify['desc'] != '')
                        Text(
                          i.officialVerify['desc'],
                          style: style,
                        ),
                    ],
                  )
                ],
              ),
            );
          },
          childCount: list!.length,
        ))
  ]);
}
