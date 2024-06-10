import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/constants.dart';
import 'package:PiliPalaX/common/widgets/badge.dart';
import 'package:PiliPalaX/models/member/seasons.dart';
import 'package:PiliPalaX/pages/member_seasons/widgets/item.dart';

import '../../../utils/grid.dart';

class MemberSeasonsPanel extends StatelessWidget {
  final MemberSeasonsDataModel? data;
  const MemberSeasonsPanel({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data!.seasonsList!.length,
      itemBuilder: (context, index) {
        MemberSeasonsList item = data!.seasonsList![index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, right: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Row(
                  children: [
                    Text(
                      item.meta!.name!,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleSmall!,
                    ),
                    const SizedBox(width: 10),
                    PBadge(
                      stack: 'relative',
                      size: 'small',
                      text: item.meta!.total.toString(),
                    ),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        tooltip: '前往',
                        onPressed: () => Get.toNamed(
                            '/memberSeasons?mid=${item.meta!.mid}&seasonId=${item.meta!.seasonId}'),
                        style: ButtonStyle(
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                        ),
                        icon: const Icon(
                          Icons.arrow_forward_ios,
                          size: 20,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              LayoutBuilder(
                builder: (context, boxConstraints) {
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithExtentAndRatio(
                      mainAxisSpacing: StyleString.cardSpace,
                      crossAxisSpacing: StyleString.cardSpace,
                      maxCrossAxisExtent: Grid.maxRowWidth,
                      childAspectRatio: 0.94,
                      mainAxisExtent: 0,
                    ),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: item.archives!.length,
                    itemBuilder: (context, i) {
                      return MemberSeasonsItem(seasonItem: item.archives![i]);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
