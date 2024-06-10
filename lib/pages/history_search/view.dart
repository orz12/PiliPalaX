import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/pages/history/widgets/item.dart';

import '../../common/constants.dart';
import '../../utils/grid.dart';
import 'controller.dart';

class HistorySearchPage extends StatefulWidget {
  const HistorySearchPage({super.key});

  @override
  State<HistorySearchPage> createState() => _HistorySearchPageState();
}

class _HistorySearchPageState extends State<HistorySearchPage> {
  final HistorySearchController _historySearchCtr =
      Get.put(HistorySearchController());
  late ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = _historySearchCtr.scrollController;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 300) {
          EasyThrottle.throttle('history', const Duration(seconds: 1), () {
            _historySearchCtr.onLoad();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    scrollController.removeListener(() {});
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          IconButton(
              tooltip: '搜索',
              onPressed: () => _historySearchCtr.submit(),
              icon: const Icon(Icons.search_outlined, size: 22)),
          const SizedBox(width: 10)
        ],
        title: Obx(
          () => TextField(
            autofocus: true,
            focusNode: _historySearchCtr.searchFocusNode,
            controller: _historySearchCtr.controller.value,
            textInputAction: TextInputAction.search,
            onChanged: (value) => _historySearchCtr.onChange(value),
            decoration: InputDecoration(
              hintText: _historySearchCtr.hintText,
              border: InputBorder.none,
              suffixIcon: IconButton(
                tooltip: '清空',
                icon: Icon(
                  Icons.clear,
                  size: 22,
                  color: Theme.of(context).colorScheme.outline,
                ),
                onPressed: () => _historySearchCtr.onClear(),
              ),
            ),
            onSubmitted: (String value) => _historySearchCtr.submit(),
          ),
        ),
      ),
      body: Obx(
        () => _historySearchCtr.loadingStatus.value == 'init'
            ? const SizedBox()
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: scrollController,
                slivers: [
                  Obx(() => SliverGrid(
                      gridDelegate: SliverGridDelegateWithExtentAndRatio(
                          mainAxisSpacing: StyleString.cardSpace,
                          crossAxisSpacing: StyleString.safeSpace,
                          maxCrossAxisExtent: Grid.maxRowWidth * 2,
                          childAspectRatio: StyleString.aspectRatio * 2.3,
                          mainAxisExtent: 0),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return HistoryItem(
                            videoItem: _historySearchCtr.historyList[index],
                            ctr: _historySearchCtr,
                            onChoose: null,
                            onUpdateMultiple: () => null,
                          );
                        },
                        childCount: _historySearchCtr.historyList.length,
                      )))
                ],
              ),
      ),
    );
  }
}
