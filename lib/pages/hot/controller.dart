import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:PiliPalaX/http/video.dart';
import 'package:PiliPalaX/models/model_hot_video_item.dart';

class HotController extends GetxController {
  final ScrollController scrollController = ScrollController();
  final int _count = 20;
  int _currentPage = 1;
  RxList<HotVideoItemModel> videoList = <HotVideoItemModel>[].obs;
  bool isLoadingMore = false;
  bool flag = false;
  OverlayEntry? popupDialog;

  // 获取推荐
  Future queryHotFeed(type) async {
    if (type != 'onLoad') {
      _currentPage = 1;
    }
    var res = await VideoHttp.hotVideoList(
      pn: _currentPage,
      ps: _count,
    );
    if (res['status']) {
      if (type == 'init') {
        videoList.value = res['data'];
      } else if (type == 'onRefresh') {
        // videoList.insertAll(0, res['data']);
        videoList.value = res['data'];
      } else if (type == 'onLoad') {
        videoList.addAll(res['data']);
      }
      _currentPage += 1;
      if (_currentPage == 2) queryHotFeed('onLoad');
    }
    isLoadingMore = false;
    return res;
  }

  // 下拉刷新
  Future onRefresh() async {
    await queryHotFeed('onRefresh');
  }

  // 上拉加载
  Future onLoad() async {
    await queryHotFeed('onLoad');
  }

  // 返回顶部
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
