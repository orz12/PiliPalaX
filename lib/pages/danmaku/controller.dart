import 'package:PiliPalaX/http/danmaku.dart';
import 'package:PiliPalaX/models/danmaku/dm.pb.dart';
import 'package:flutter/cupertino.dart';

class PlDanmakuController {
  PlDanmakuController(this.cid, this.danmakuWeightNotifier, this.danmakuFilterNotifier);
  final int cid;
  final ValueNotifier<int> danmakuWeightNotifier;
  final ValueNotifier<List<Map<String, dynamic>>> danmakuFilterNotifier;
  int danmakuWeight = 0;
  List<Map<String, dynamic>> danmakuFilter = [];
  Map<int, List<DanmakuElem>> dmSegMap = {};
  // 已请求的段落标记
  List<bool> requestedSeg = [];

  bool get initiated => requestedSeg.isNotEmpty;

  static int segmentLength = 60 * 6 * 1000;

  void initiate(int videoDuration, int progress) {
    if (videoDuration <= 0) {
      return;
    }
    danmakuWeightNotifier.addListener(() {
      print(
          "danmakuWeight changed from $danmakuWeight to ${danmakuWeightNotifier.value}");
      danmakuWeight = danmakuWeightNotifier.value;
    });
    danmakuFilterNotifier.addListener(() {
      print("danmakuFilter changed from $danmakuFilter to ${danmakuFilterNotifier.value}");
      danmakuFilter = danmakuFilterNotifier.value;
    });
    if (requestedSeg.isEmpty) {
      int segCount = (videoDuration / segmentLength).ceil();
      requestedSeg = List<bool>.generate(segCount, (index) => false);
    }
    queryDanmaku(calcSegment(progress));
  }

  void dispose() {
    danmakuWeightNotifier.removeListener(() {});
    danmakuFilterNotifier.removeListener(() {});
    danmakuFilter.clear();
    dmSegMap.clear();
    requestedSeg.clear();
  }

  int calcSegment(int progress) {
    return progress ~/ segmentLength;
  }

  void queryDanmaku(int segmentIndex) async {
    if (requestedSeg.length <= segmentIndex) {
      return;
    }
    assert(requestedSeg[segmentIndex] == false);
    requestedSeg[segmentIndex] = true;
    final DmSegMobileReply result = await DanmakaHttp.queryDanmaku(
        cid: cid, segmentIndex: segmentIndex + 1);
    if (result.elems.isNotEmpty) {
      for (var element in result.elems) {
        int pos = element.progress ~/ 100; //每0.1秒存储一次
        if (dmSegMap[pos] == null) {
          dmSegMap[pos] = [];
        }
        dmSegMap[pos]!.add(element);
      }
    }
  }

  List<DanmakuElem>? getCurrentDanmaku(int progress) {
    int segmentIndex = calcSegment(progress);
    if (requestedSeg.length <= segmentIndex) {
      return <DanmakuElem>[];
    }
    if (!requestedSeg[segmentIndex]) {
      queryDanmaku(segmentIndex);
    }
    if (danmakuWeight == 0 && danmakuFilter.isEmpty) {
      return dmSegMap[progress ~/ 100];
    } else {
      return dmSegMap[progress ~/ 100]
          ?.where((element) => element.weight >= danmakuWeight)
          .where(filterDanmaku)
          .toList();
    }
  }

  bool filterDanmaku(DanmakuElem elem) {
    for (var filter in danmakuFilter) {
      switch (filter['type']) {
        case 0:
          if (elem.content.contains(filter['filter'])) {
            return false;
          }
          break;
        case 1:
          if (RegExp(filter['filter']).hasMatch(elem.content)) {
            return false;
          }
          break;
        case 2:
          if (elem.idStr == filter['filter']) {
            return false;
          }
          break;
      }
    }
    return true;
  }
}
