import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';

import '../../../http/dynamics.dart';
import '../../../models/dynamics/result.dart';
// import '../../../utils/storage.dart';

class DynamicsTabController extends GetxController {
  String offset = '';
  ScrollController scrollController = ScrollController();
  RxList<DynamicItemModel> dynamicsList = <DynamicItemModel>[].obs;
  RxBool isLoadingMore = false.obs;
  String dynamicsType = 'all';
  // Box userInfoCache = GStorage.userInfo;
  // bool userLogin = false;
  int mid = -1;

  Future queryFollowDynamic(String type, String dynamicsType, int? mid) async {
    this.dynamicsType = dynamicsType;
    if (mid != null) this.mid = mid;
    if (type != 'onLoad') {
      dynamicsList.clear();
      offset = '';
    }
    // // 下拉刷新数据渲染时会触发onLoad
    // if (type == 'onLoad' && page == 1) {
    //   return;
    // }
    isLoadingMore.value = true;
    var res = await DynamicsHttp.followDynamic(
      type: dynamicsType == "up" ? "all" : dynamicsType,
      offset: offset,
      mid: dynamicsType == "up" ? mid : -1,
    );
    isLoadingMore.value = false;
    if (res['status']) {
      if (type == 'onLoad' && res['data'].items.isEmpty) {
        SmartDialog.showToast('没有更多了');
        return;
      }
      if (type == 'onLoad') {
        dynamicsList.addAll(res['data'].items);
      } else {
        dynamicsList.value = res['data'].items;
      }
      // print('dynamicsList: $dynamicsList');
      dynamicsList.refresh();
      offset = res['data'].offset;
      // print("page: $page[dynamicsType]!");
    }
    return res;
  }

  // 下拉刷新
  Future onRefresh() async {
    await queryFollowDynamic('onRefresh', dynamicsType, mid);
  }

  // 上拉加载
  Future onLoad() async {
    await queryFollowDynamic('onLoad', dynamicsType, mid);
  }

  // 返回顶部并刷新
  void animateToTop() async {
    if (scrollController.offset >=
        MediaQuery.of(Get.context!).size.height * 5) {
      scrollController.jumpTo(0);
    } else {
      await scrollController.animateTo(0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }
}
