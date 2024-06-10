import 'package:PiliPalaX/common/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../utils/feed_back.dart';
import './controller.dart';

class RankPage extends StatefulWidget {
  const RankPage({Key? key}) : super(key: key);

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final RankController _rankController = Get.put(RankController());
  late int _selectedTabIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _rankController.tabController =
        TabController(vsync: this, length: _rankController.tabs.length);
    _selectedTabIndex = _rankController.initialIndex.value;
    _rankController.tabController.addListener(() {
      if (!_rankController.tabController.indexIsChanging) {
        // _rankController.onRefresh();
        setState(() {
          _selectedTabIndex = _rankController.tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _rankController.tabController.removeListener(() {});
    _rankController.tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Row(
      children: [
        const SizedBox(
          width: StyleString.cardSpace,
        ),
        // SizedBox(
        //     width: 55,
        //     child: NavigationRail(
        //
        //       backgroundColor: Colors.transparent,
        //       minWidth: 50.0,
        //       // elevation: 0,
        //       selectedIndex: _selectedTabIndex,
        //       onDestinationSelected: (int index) {
        //         feedBack();
        //         if (_selectedTabIndex == index) {
        //           _rankController.tabsCtrList[index]().animateToTop();
        //         } else {
        //           setState(() {
        //             _rankController.tabController.index = index;
        //             _selectedTabIndex = index;
        //           });
        //         }
        //       },
        //       labelType: NavigationRailLabelType.none,
        //       destinations: [
        //         for (var tab in _rankController.tabs)
        //           NavigationRailDestination(
        //             padding: EdgeInsets.zero,
        //             icon: Text(tab['label']),
        //             // selectedIcon: Text(tab['label']),
        //             label: const SizedBox.shrink(),
        //           ),
        //       ],
        //       trailing: const SizedBox(height: 100),
        //     )),
        LayoutBuilder(builder: (context, constraint) {
          return SingleChildScrollView(
              child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraint.maxHeight),
                  child: IntrinsicHeight(
                      child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    minWidth: 50.0,
                    // elevation: 0,
                    selectedIndex: _selectedTabIndex,
                    onDestinationSelected: (int index) {
                      feedBack();
                      if (_selectedTabIndex == index) {
                        _rankController.tabsCtrList[index]().animateToTop();
                      } else {
                        setState(() {
                          _rankController.tabController.index = index;
                          _selectedTabIndex = index;
                        });
                      }
                    },
                    labelType: NavigationRailLabelType.none,
                    destinations: [
                      for (var tab in _rankController.tabs)
                        NavigationRailDestination(
                          icon: Text(tab['label']),
                          // selectedIcon: Text(tab['label']),
                          label: const SizedBox.shrink(),
                        ),
                    ],
                    trailing: const SizedBox(height: 100),
                  ))));
        }),
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _rankController.tabController,
            children: _rankController.tabsPageList,
          ),
        ),
      ],
    );
  }
}
