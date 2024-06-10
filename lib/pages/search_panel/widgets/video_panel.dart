import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/widgets/video_card_h.dart';
import 'package:PiliPalaX/models/common/search_type.dart';
import 'package:PiliPalaX/pages/search_panel/index.dart';

import '../../../common/constants.dart';
import '../../../utils/grid.dart';

class SearchVideoPanel extends StatelessWidget {
  SearchVideoPanel({
    required this.ctr,
    required this.list,
    Key? key,
  }) : super(key: key);

  final SearchPanelController ctr;
  final List list;

  final VideoPanelController controller = Get.put(VideoPanelController());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 分类筛选
        Container(
          width: context.width,
          height: 34,
          padding: const EdgeInsets.only(
              left: StyleString.safeSpace, top: 0, right: 12),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Obx(
                    () => Wrap(
                      // spacing: ,
                      children: [
                        for (var i in controller.filterList) ...[
                          CustomFilterChip(
                            label: i['label'],
                            type: i['type'],
                            selectedType: controller.selectedType.value,
                            callFn: (bool selected) async {
                              print('selected: $selected');
                              controller.selectedType.value = i['type'];
                              ctr.order.value =
                                  i['type'].toString().split('.').last;
                              SmartDialog.showLoading(msg: 'loading');
                              await ctr.onRefresh();
                              SmartDialog.dismiss();
                            },
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(indent: 7, endIndent: 8),
              const SizedBox(width: 3),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  tooltip: '筛选',
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () => controller.onShowFilterDialog(context, ctr),
                  icon: Icon(
                    Icons.filter_list_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
            child: CustomScrollView(
          controller: ctr.scrollController,
          slivers: [
            SliverPadding(
                padding: const EdgeInsets.all(StyleString.safeSpace),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithExtentAndRatio(
                      mainAxisSpacing: StyleString.safeSpace,
                      crossAxisSpacing: StyleString.safeSpace,
                      maxCrossAxisExtent: Grid.maxRowWidth * 2,
                      childAspectRatio: StyleString.aspectRatio * 2.3,
                      mainAxisExtent: 0),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      return VideoCardH(
                          videoItem: list[index], showPubdate: true);
                    },
                    childCount: list.length,
                  ),
                )),
          ],
        )),
      ],
    );
  }
}

class CustomFilterChip extends StatelessWidget {
  const CustomFilterChip({
    this.label,
    this.type,
    this.selectedType,
    this.callFn,
    Key? key,
  }) : super(key: key);

  final String? label;
  final ArchiveFilterType? type;
  final ArchiveFilterType? selectedType;
  final Function? callFn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilterChip(
        padding: const EdgeInsets.only(left: 8, right: 8),
        labelPadding: EdgeInsets.zero,
        label: Text(
          label!,
          style: const TextStyle(fontSize: 13),
        ),
        labelStyle: TextStyle(
            color: type == selectedType
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline),
        selected: type == selectedType,
        showCheckmark: false,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selectedColor: Colors.transparent,
        // backgroundColor:
        //     Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        backgroundColor: Colors.transparent,
        side: BorderSide.none,
        onSelected: (bool selected) => callFn!(selected),
      ),
    );
  }
}

class VideoPanelController extends GetxController {
  RxList<Map> filterList = [{}].obs;
  Rx<ArchiveFilterType> selectedType = ArchiveFilterType.values.first.obs;
  List<Map<String, dynamic>> timeFiltersList = [
    {'label': '全部时长', 'value': 0},
    {'label': '0-10分钟', 'value': 1},
    {'label': '10-30分钟', 'value': 2},
    {'label': '30-60分钟', 'value': 3},
    {'label': '60分钟+', 'value': 4},
  ];
  RxInt currentTimeFilterval = 0.obs;

  @override
  void onInit() {
    List<Map<String, dynamic>> list = ArchiveFilterType.values
        .map((type) => {
              'label': type.description,
              'type': type,
            })
        .toList();
    filterList.value = list;
    super.onInit();
  }

  onShowFilterDialog(BuildContext context, SearchPanelController searchPanelCtr) {
    showDialog(
    context: context,
    builder: (context) {
        TextStyle textStyle = Theme.of(context).textTheme.titleMedium!;
        return AlertDialog(
          title: const Text('时长筛选'),
          contentPadding: const EdgeInsets.fromLTRB(0, 15, 0, 20),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i in timeFiltersList) ...[
                  RadioListTile(
                    value: i['value'],
                    autofocus: true,
                    title: Text(i['label'], style: textStyle),
                    groupValue: currentTimeFilterval.value,
                    onChanged: (value) async {
                      currentTimeFilterval.value = value!;
                      setState(() {});
                      SmartDialog.dismiss();
                      SmartDialog.showToast("「${i['label']}」的筛选结果");
                      SearchPanelController ctr =
                          Get.find<SearchPanelController>(
                              tag: 'video${searchPanelCtr.keyword!}');
                      ctr.duration.value = i['value'];
                      SmartDialog.showLoading(msg: 'loading');
                      await ctr.onRefresh();
                      SmartDialog.dismiss();
                    },
                  ),
                ],
              ],
            );
          }),
        );
      },
    );
  }
}
