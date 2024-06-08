import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/http/user.dart';
import 'package:PiliPalaX/models/user/history.dart';
import 'package:PiliPalaX/utils/storage.dart';

class HistoryController extends GetxController {
  final ScrollController scrollController = ScrollController();
  RxList<HisListItem> historyList = <HisListItem>[].obs;
  RxBool isLoadingMore = false.obs;
  RxBool pauseStatus = false.obs;
  Box localCache = GStorage.localCache;
  RxBool isLoading = false.obs;
  RxBool enableMultiple = false.obs;
  RxInt checkedCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    historyStatus();
  }

  Future queryHistoryList({type = 'init'}) async {
    int max = 0;
    int viewAt = 0;
    if (type == 'onload') {
      max = historyList.last.history!.oid!;
      viewAt = historyList.last.viewAt!;
    }
    isLoadingMore.value = true;
    var res = await UserHttp.historyList(max, viewAt);
    isLoadingMore.value = false;
    if (res['status']) {
      if (type == 'onload') {
        historyList.addAll(res['data'].list);
      } else {
        historyList.value = res['data'].list;
      }
    }
    return res;
  }

  Future onLoad() async {
    queryHistoryList(type: 'onload');
  }

  Future onRefresh() async {
    queryHistoryList(type: 'onRefresh');
  }

  // 暂停观看历史
  Future onPauseHistory(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content:
              Text(!pauseStatus.value ? '啊叻？你要暂停历史记录功能吗？' : '啊叻？要恢复历史记录功能吗？'),
          actions: [
            TextButton(
                onPressed: () => Get.back(),
                child: const Text('取消')),
            TextButton(
              onPressed: () async {
                SmartDialog.showLoading(msg: '请求中');
                var res = await UserHttp.pauseHistory(!pauseStatus.value);
                SmartDialog.dismiss();
                if (res.data['code'] == 0) {
                  SmartDialog.showToast(
                      !pauseStatus.value ? '暂停观看历史' : '恢复观看历史');
                  pauseStatus.value = !pauseStatus.value;
                  localCache.put(LocalCacheKey.historyPause, pauseStatus.value);
                }
                Get.back();
              },
              child: Text(!pauseStatus.value ? '确认暂停' : '确认恢复'),
            )
          ],
        );
      },
    );
  }

  // 观看历史暂停状态
  Future historyStatus() async {
    var res = await UserHttp.historyStatus();
    if (res['status']) {
      pauseStatus.value = res['data'];
      localCache.put(LocalCacheKey.historyPause, res['data']);
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  // 清空观看历史
  Future onClearHistory(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('啊叻？你要清空历史记录功能吗？'),
          actions: [
            TextButton(
                onPressed: () => Get.back(),
                child: const Text('取消')),
            TextButton(
              onPressed: () async {
                SmartDialog.showLoading(msg: '请求中');
                var res = await UserHttp.clearHistory();
                SmartDialog.dismiss();
                if (res.data['code'] == 0) {
                  SmartDialog.showToast('清空观看历史');
                }
                Get.back();
                historyList.clear();
              },
              child: const Text('确认清空'),
            )
          ],
        );
      },
    );
  }

  // 删除某条历史记录
  Future delHistory(kid, business) async {
    String resKid = 'archive_$kid';
    if (business == 'live') {
      resKid = 'live_$kid';
    } else if (business.contains('article')) {
      resKid = 'article_$kid';
    }

    var res = await UserHttp.delHistory(resKid);
    if (res['status']) {
      historyList.removeWhere((e) => e.kid == kid);
      SmartDialog.showToast(res['msg']);
    }
  }

  // 删除已看历史记录
  Future onDelHistory() async {
    /// TODO 优化
    List<HisListItem> result =
        historyList.where((e) => e.progress == -1).toList();
    for (HisListItem i in result) {
      String resKid = 'archive_${i.kid}';
      await UserHttp.delHistory(resKid);
      historyList.removeWhere((e) => e.kid == i.kid);
    }
    SmartDialog.showToast('操作完成');
  }

  // 删除选中的记录
  Future onDelCheckedHistory(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: const Text('确认删除所选历史记录吗？'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                '取消',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                /// TODO 优化
                Get.back();
                SmartDialog.showLoading(msg: '请求中');
                List<HisListItem> result =
                    historyList.where((e) => e.checked!).toList();
                for (HisListItem i in result) {
                  String str = 'archive';
                  try {
                    str = i.history!.business!;
                  } catch (_) {}
                  String resKid = '${str}_${i.kid}';
                  await UserHttp.delHistory(resKid);
                  historyList.removeWhere((e) => e.kid == i.kid);
                }
                checkedCount.value = 0;
                SmartDialog.dismiss();
                enableMultiple.value = false;
              },
              child: const Text('确认'),
            )
          ],
        );
      },
    );
  }
}
