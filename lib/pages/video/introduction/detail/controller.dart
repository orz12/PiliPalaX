import 'dart:async';
import 'dart:convert';

import 'package:PiliPalaX/plugin/pl_player/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/http/constants.dart';
import 'package:PiliPalaX/http/user.dart';
import 'package:PiliPalaX/http/video.dart';
import 'package:PiliPalaX/models/user/fav_folder.dart';
import 'package:PiliPalaX/models/video/ai.dart';
import 'package:PiliPalaX/models/video_detail_res.dart';
import 'package:PiliPalaX/pages/video/controller.dart';
import 'package:PiliPalaX/pages/video/reply/index.dart';
import 'package:PiliPalaX/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/id_utils.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:PiliPalaX/pages/member/controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:PiliPalaX/services/service_locator.dart';

import '../../../../../http/search.dart';
import '../../../../../models/model_hot_video_item.dart';
import '../../related/index.dart';
import '../widgets/group_panel.dart';

class VideoIntroController extends GetxController {
  // 视频bvid
  late String bvid;

  // 是否预渲染 骨架屏
  bool preRender = false;

  // 视频详情 上个页面传入
  Map? videoItem = {};

  // 请求状态
  RxBool isLoading = false.obs;

  // 视频详情 请求返回
  Rx<VideoDetailData> videoDetail = VideoDetailData().obs;

  // up主粉丝数
  Rx<Map<String, dynamic>> userStat =
      Rx<Map<String, dynamic>>({'follower': '-'});

  // 是否点赞
  RxBool hasLike = false.obs;
  // 是否点踩
  RxBool hasDislike = false.obs;
  // 是否投币
  RxBool hasCoin = false.obs;
  // 是否收藏
  RxBool hasFav = false.obs;
  Box userInfoCache = GStorage.userInfo;
  bool userLogin = false;
  Rx<FavFolderData> favFolderData = FavFolderData().obs;
  List addMediaIdsNew = [];
  List delMediaIdsNew = [];
  // 关注状态 默认未关注
  RxMap followStatus = {}.obs;

  RxInt lastPlayCid = 0.obs;
  var userInfo;

  // 同时观看
  bool isShowOnlineTotal = false;
  RxString total = '1'.obs;
  Timer? timer;
  bool isPaused = false;
  String heroTag = '';
  Rx<Map<String, dynamic>> queryVideoIntroData =
      Rx<Map<String, dynamic>>({"status": true});

  @override
  void onInit() {
    super.onInit();
    userInfo = userInfoCache.get('userInfoCache');
    try {
      heroTag = Get.arguments['heroTag'];
      bvid = Get.parameters['bvid']!;
    } catch (_) {}
    if (Get.arguments.isNotEmpty) {
      if (Get.arguments.containsKey('videoItem')) {
        preRender = true;
        var args = Get.arguments['videoItem'];
        var keys = Get.arguments.keys.toList();
        videoItem!['pic'] = args.pic;
        if (args.title is String) {
          videoItem!['title'] = args.title;
        } else {
          String str = '';
          for (Map map in args.title) {
            str += map['text'];
          }
          videoItem!['title'] = str;
        }
        videoItem!['stat'] = keys.contains('stat') ? args.stat : null;
        videoItem!['pubdate'] = keys.contains('pubdate') ? args.pubdate : null;
        videoItem!['owner'] = keys.contains('owner') ? args.owner : null;
      }
    }
    userLogin = userInfo != null;
    lastPlayCid.value = int.parse(Get.parameters['cid']!);
    isShowOnlineTotal =
        setting.get(SettingBoxKey.enableOnlineTotal, defaultValue: false);
    if (isShowOnlineTotal) {
      queryOnlineTotal();
      startTimer(); // 在页面加载时启动定时器
    }
    queryVideoIntro();

    videoDetail.listen((value) {
      if ((value.pages?.length ?? 0) > 1) {
        final VideoDetailController videoDetailCtr =
            Get.find<VideoDetailController>(tag: heroTag);
        final cid = videoDetailCtr.cid.value;
        final current =
            value.pages?.firstWhere((element) => element.cid == cid);

        videoPlayerServiceHandler.onVideoDetailChange(
            current?.pagePart ?? "",
            value.title ?? "",
            Duration(seconds: current?.duration ?? 0),
            value.pic ?? "");
      } else {
        videoPlayerServiceHandler.onVideoDetailChange(
            value.title ?? "",
            value.owner?.name ?? "",
            Duration(seconds: value.duration ?? 0),
            value.pic ?? "");
      }
    });
  }

  void openVideoDetail() {
    // if (Get.previousRoute == '/video?bvid=$bvid&cid=${lastPlayCid.value}') {
    //   Get.back();
    //   return;
    // }

    VideoDetailController? videoDetailCtr;
    try {
      videoDetailCtr = Get.find<VideoDetailController>(tag: heroTag);
    } catch (_) {}
    print("videoDetailCtr: $videoDetailCtr");
    if (videoDetailCtr == null) {
      Get.toNamed('/video?bvid=$bvid&cid=${lastPlayCid.value}&resume=true',
          arguments: {'heroTag': heroTag});
      return;
    }
    videoDetailCtr.resumePlay = true;
    popRouteStackContinuously = '/video?bvid=$bvid&cid=${lastPlayCid.value}';
    Get.until((Route<dynamic> route) {
      print(route.settings.name);
      print(route.settings.arguments);
      print(route.settings.arguments.runtimeType);
      if (route.settings.arguments is Map) {
        String? heroTagCurr =
            (route.settings.arguments as Map<String, dynamic>)['heroTag'];
        if (heroTagCurr != null && heroTagCurr.isNotEmpty) {
          return heroTag == heroTagCurr;
        }
      }
      // String? args = route.settings.arguments?.toString();
      // if (args != null && args.isNotEmpty) {
      //   String? heroTagCurr =jsonDecode(args)['heroTag'];
      //   if (heroTagCurr != null && heroTagCurr.isNotEmpty) {
      //     return heroTag == heroTagCurr;
      //   }
      // }
      // return route.settings.arguments!.heroTag == heroTag || route.isFirst;
      return route.settings.name?.startsWith('/video?bvid=$bvid') == true ||
          route.isFirst;
    });
    popRouteStackContinuously = "";
  }

  // 获取视频简介&分p
  void queryVideoIntro() async {
    var result = await VideoHttp.videoIntro(bvid: bvid);
    if (result['status']) {
      videoDetail.value = result['data']!;
      if (videoDetail.value.pages != null &&
          videoDetail.value.pages!.isNotEmpty &&
          lastPlayCid.value == 0) {
        lastPlayCid.value = videoDetail.value.pages!.first.cid!;
      }
      // Get.find<VideoDetailController>(tag: heroTag).tabs.value = [
      //   '简介',
      //   '评论 ${result['data']!.stat!.reply}'
      // ];
      // 获取到粉丝数再返回
      await queryUserStat();
    } else {
      SmartDialog.showToast(
          "${result['code']} ${result['msg']} ${result['data']}");
    }
    queryVideoIntroData.value = result;
    if (userLogin) {
      // 获取点赞状态
      queryHasLikeVideo();
      // 获取投币状态
      queryHasCoinVideo();
      // 获取收藏状态
      queryHasFavVideo();
      //
      queryFollowStatus();
    }
  }

  // 获取up主粉丝数
  Future queryUserStat() async {
    var result = await UserHttp.userStat(mid: videoDetail.value.owner!.mid!);
    if (result['status']) {
      print(result['data']);
      userStat.value = result['data'];
      userStat.refresh();
    }
  }

  // 获取点赞状态
  Future queryHasLikeVideo() async {
    var result = await VideoHttp.hasLikeVideo(bvid: bvid);
    // data	num	被点赞标志	0：未点赞  1：已点赞  2：已点踩
    hasLike.value = result["data"] == 1;
    hasDislike.value = result["data"] == 2;
  }

  // 获取投币状态
  Future queryHasCoinVideo() async {
    var result = await VideoHttp.hasCoinVideo(bvid: bvid);
    if (result['status']) {
      hasCoin.value = result["data"]['multiply'] != 0;
    }
  }

  // 获取收藏状态
  Future queryHasFavVideo() async {
    /// fix 延迟查询
    await Future.delayed(const Duration(milliseconds: 200));
    var result = await VideoHttp.hasFavVideo(aid: IdUtils.bv2av(bvid));
    if (result['status']) {
      hasFav.value = result["data"]['favoured'];
    } else {
      hasFav.value = false;
    }
  }

  // 一键三连
  Future actionOneThree() async {
    feedBack();
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    if (hasLike.value && hasCoin.value && hasFav.value) {
      // 已点赞、投币、收藏
      SmartDialog.showToast('已三连');
      return false;
    }
    var result = await VideoHttp.oneThree(bvid: bvid);
    if (result['status']) {
      hasLike.value = result["data"]["like"];
      hasCoin.value = result["data"]["coin"];
      hasFav.value = result["data"]["fav"];
      SmartDialog.showToast('三连成功');
    } else {
      SmartDialog.showToast(result['msg']);
    }
  }

  // （取消）点赞
  Future actionLikeVideo() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    var result = await VideoHttp.likeVideo(bvid: bvid, type: !hasLike.value);
    if (result['status']) {
      // hasLike.value = result["data"] == 1 ? true : false;
      if (!hasLike.value) {
        SmartDialog.showToast(result['data']['toast']);
        hasLike.value = true;
        hasDislike.value = false;
        videoDetail.value.stat!.like = videoDetail.value.stat!.like! + 1;
      } else if (hasLike.value) {
        SmartDialog.showToast('取消赞');
        hasLike.value = false;
        videoDetail.value.stat!.like = videoDetail.value.stat!.like! - 1;
      }
      hasLike.refresh();
    } else {
      SmartDialog.showToast(result['msg']);
    }
  }

  Future actionDislikeVideo() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    var result =
        await VideoHttp.dislikeVideo(bvid: bvid, type: !hasDislike.value);
    if (result['status']) {
      // hasLike.value = result["data"] == 1 ? true : false;
      if (!hasDislike.value) {
        SmartDialog.showToast('点踩成功');
        hasDislike.value = true;
        hasLike.value = false;
      } else {
        SmartDialog.showToast('取消踩');
        hasDislike.value = false;
      }
      // hasDislike.refresh();
    } else {
      SmartDialog.showToast(result['msg']);
    }
  }

  // 投币
  Future actionCoinVideo() async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    void coinVideo(int coin) async {
      var res = await VideoHttp.coinVideo(bvid: bvid, multiply: coin);
      if (res['status']) {
        print(res);
        SmartDialog.showToast('投币成功');
        hasCoin.value = true;
        videoDetail.value.stat!.coin = videoDetail.value.stat!.coin! + coin;
      } else {
        SmartDialog.showToast(res['msg']);
      }
    }

    showDialog(
        context: Get.context!,
        builder: (context) {
          return AlertDialog(
            title: const Text('选择投币个数'),
            contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            actions: [
              TextButton(
                  onPressed: () => Get.back(),
                  child: Text('取消',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline))),
              TextButton(
                  onPressed: () async {
                    coinVideo(1);
                    Get.back();
                  },
                  child: const Text('投 1 枚')),
              TextButton(
                  onPressed: () async {
                    coinVideo(2);
                    Get.back();
                  },
                  child: const Text('投 2 枚'))
            ],
          );
        });
  }

  // （取消）收藏
  Future actionFavVideo({type = 'choose'}) async {
    // 收藏至默认文件夹
    if (type == 'default') {
      SmartDialog.showLoading(msg: '请求中');
      await queryVideoInFolder();
      int defaultFolderId = favFolderData.value.list!.first.id!;
      int favStatus = favFolderData.value.list!.first.favState!;
      var result = await VideoHttp.favVideo(
        aid: IdUtils.bv2av(bvid),
        addIds: favStatus == 0 ? '$defaultFolderId' : '',
        delIds: favStatus == 1 ? '$defaultFolderId' : '',
      );
      SmartDialog.dismiss();
      if (result['status']) {
        // 重新获取收藏状态
        await queryHasFavVideo();
        SmartDialog.showToast('✅ 快速收藏/取消收藏成功');
      } else {
        SmartDialog.showToast(result['msg']);
      }
      return;
    }
    try {
      for (var i in favFolderData.value.list!.toList()) {
        if (i.favState == 1) {
          addMediaIdsNew.add(i.id);
        } else {
          delMediaIdsNew.add(i.id);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
    SmartDialog.showLoading(msg: '请求中');
    var result = await VideoHttp.favVideo(
        aid: IdUtils.bv2av(bvid),
        addIds: addMediaIdsNew.join(','),
        delIds: delMediaIdsNew.join(','));
    SmartDialog.dismiss();
    if (result['status']) {
      addMediaIdsNew = [];
      delMediaIdsNew = [];
      Get.back();
      // 重新获取收藏状态
      await queryHasFavVideo();
      SmartDialog.showToast('操作成功');
    } else {
      SmartDialog.showToast(result['msg']);
    }
  }

  // 分享视频
  Future actionShareVideo() async {
    showDialog(
        context: Get.context!,
        builder: (context) {
          String videoUrl = '${HttpString.baseUrl}/video/$bvid';
          return AlertDialog(
            title: const Text('请选择'),
            actions: [
              TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: videoUrl));
                    SmartDialog.showToast('已复制');
                    Get.back();
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('复制链接')),
              TextButton.icon(
                  onPressed: () {
                    launchUrl(Uri.parse(videoUrl));
                    Get.back();
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('其它app打开')),
              TextButton.icon(
                  onPressed: () async {
                    await Share.share('${videoDetail.value.title} '
                            'UP主: ${videoDetail.value.owner!.name!}'
                            ' - $videoUrl')
                        .whenComplete(() {});
                    Get.back();
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('分享视频')),
            ],
          );
        });
  }

  Future queryVideoInFolder() async {
    var result = await VideoHttp.videoInFolder(
        mid: userInfo.mid, rid: IdUtils.bv2av(bvid));
    if (result['status']) {
      favFolderData.value = result['data'];
    }
    return result;
  }

  // 选择文件夹
  onChoose(bool checkValue, int index) {
    feedBack();
    List<FavFolderItemData> datalist = favFolderData.value.list!;
    for (var i = 0; i < datalist.length; i++) {
      if (i == index) {
        datalist[i].favState = checkValue == true ? 1 : 0;
        datalist[i].mediaCount = checkValue == true
            ? datalist[i].mediaCount! + 1
            : datalist[i].mediaCount! - 1;
      }
    }
    favFolderData.value.list = datalist;
    favFolderData.refresh();
  }

  // 查询关注状态
  Future queryFollowStatus() async {
    if (videoDetail.value.owner == null) {
      return;
    }
    var result = await VideoHttp.hasFollow(mid: videoDetail.value.owner!.mid!);
    if (result['status']) {
      followStatus.value = result['data'];
    }
    return result;
  }

  // 关注/取关up
  Future actionRelationMod(BuildContext context) async {
    if (userInfo == null) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    feedBack();
    int mid = videoDetail.value.owner!.mid!;
    MemberController _ = Get.put<MemberController>(MemberController(mid: mid),
        tag: mid.toString());
    await _.getInfo();
    if (context.mounted) await _.actionRelationMod(context);
    followStatus['attribute'] = _.attribute.value;
    followStatus.refresh();
    Get.delete<MemberController>(tag: mid.toString());
  }

  // 修改分P或番剧分集
  Future changeSeasonOrbangu(bvid, cid, aid) async {
    // 重新获取视频资源
    final VideoDetailController videoDetailCtr =
        Get.find<VideoDetailController>(tag: heroTag);
    videoDetailCtr.bvid = bvid;
    videoDetailCtr.oid.value = aid ?? IdUtils.bv2av(bvid);
    videoDetailCtr.cid.value = cid;
    videoDetailCtr.danmakuCid.value = cid;
    videoDetailCtr.queryVideoUrl();
    // 重新请求相关视频
    try {
      final RelatedController relatedCtr =
          Get.find<RelatedController>(tag: heroTag);
      relatedCtr.bvid = bvid;
      relatedCtr.queryRelatedVideo();
    } catch (_) {}
    // 重新请求评论
    try {
      final VideoReplyController videoReplyCtr =
          Get.find<VideoReplyController>(tag: heroTag);
      videoReplyCtr.aid = aid;
      videoReplyCtr.queryReplyList(type: 'init');
    } catch (_) {}
    this.bvid = bvid;
    lastPlayCid.value = cid;
    queryVideoIntro();
  }

  void startTimer() {
    const duration = Duration(seconds: 10); // 设置定时器间隔为10秒
    timer = Timer.periodic(duration, (Timer timer) {
      if (!isPaused) {
        queryOnlineTotal(); // 定时器回调函数，发起请求
      }
    });
  }

  // 查看同时在看人数
  Future queryOnlineTotal() async {
    var result = await VideoHttp.onlineTotal(
      aid: IdUtils.bv2av(bvid),
      bvid: bvid,
      cid: lastPlayCid.value,
    );
    if (result['status']) {
      total.value = result['data']['total'];
    }
  }

  @override
  void onClose() {
    if (timer != null) {
      timer!.cancel(); // 销毁页面时取消定时器
    }
    super.onClose();
  }

  /// 播放上一个
  bool prevPlay() {
    final List episodes = [];
    bool isPages = false;
    if (videoDetail.value.pages != null &&
        videoDetail.value.pages!.length > 1) {
      isPages = true;
      final List<Part> pages = videoDetail.value.pages!;
      episodes.addAll(pages);
    } else if (videoDetail.value.ugcSeason != null) {
      final UgcSeason ugcSeason = videoDetail.value.ugcSeason!;
      final List<SectionItem> sections = ugcSeason.sections!;
      for (int i = 0; i < sections.length; i++) {
        final List<EpisodeItem> episodesList = sections[i].episodes!;
        episodes.addAll(episodesList);
      }
    }

    final int currentIndex =
        episodes.indexWhere((e) => e.cid == lastPlayCid.value);
    int prevIndex = currentIndex - 1;
    PlayRepeat playRepeat = PlPlayerController.getInstance().playRepeat;
    // 列表循环
    if (prevIndex < 0) {
      if (playRepeat == PlayRepeat.listCycle) {
        prevIndex = episodes.length - 1;
      } else {
        return false;
      }
    }
    final int cid = episodes[prevIndex].cid!;
    final String rBvid = isPages ? bvid : episodes[prevIndex].bvid;
    final int rAid = isPages ? IdUtils.bv2av(bvid) : episodes[prevIndex].aid!;
    changeSeasonOrbangu(rBvid, cid, rAid);
    return true;
  }

  // 是否有下一集（必须存在分p、分集）
  bool hasNextEpisode() {
    final List episodes = [];
    if (videoDetail.value.pages != null &&
        videoDetail.value.pages!.length > 1) {
      final List<Part> pages = videoDetail.value.pages!;
      episodes.addAll(pages);
    } else if (videoDetail.value.ugcSeason != null) {
      final UgcSeason ugcSeason = videoDetail.value.ugcSeason!;
      final List<SectionItem> sections = ugcSeason.sections!;
      for (int i = 0; i < sections.length; i++) {
        final List<EpisodeItem> episodesList = sections[i].episodes!;
        episodes.addAll(episodesList);
      }
    }
    if (episodes.isEmpty) {
      return false;
    }
    PlayRepeat playRepeat = PlPlayerController.getInstance().playRepeat;
    if (playRepeat == PlayRepeat.listCycle) {
      return true;
    }
    final int currentIndex =
        episodes.indexWhere((e) => e.cid == lastPlayCid.value);
    return currentIndex < episodes.length - 1;
  }

  /// 列表循环或者顺序播放时，自动播放下一个
  bool nextPlay() {
    print("entering nextPlay");
    final List episodes = [];
    bool isPages = false;
    if (videoDetail.value.pages != null &&
        videoDetail.value.pages!.length > 1) {
      isPages = true;
      final List<Part> pages = videoDetail.value.pages!;
      episodes.addAll(pages);
    } else if (videoDetail.value.ugcSeason != null) {
      final UgcSeason ugcSeason = videoDetail.value.ugcSeason!;
      final List<SectionItem> sections = ugcSeason.sections!;
      for (int i = 0; i < sections.length; i++) {
        final List<EpisodeItem> episodesList = sections[i].episodes!;
        episodes.addAll(episodesList);
      }
    }
    PlayRepeat playRepeat = PlPlayerController.getInstance().playRepeat;
    if (episodes.isEmpty) {
      if (playRepeat == PlayRepeat.autoPlayRelated) {
        return playRelated();
      }
      return false;
    }

    final int currentIndex =
        episodes.indexWhere((e) => e.cid == lastPlayCid.value);
    int nextIndex = currentIndex + 1;

    // 列表循环
    if (nextIndex >= episodes.length) {
      if (playRepeat == PlayRepeat.listCycle) {
        nextIndex = 0;
      } else if (playRepeat == PlayRepeat.autoPlayRelated) {
        return playRelated();
      } else {
        return false;
      }
    }
    final int cid = episodes[nextIndex].cid!;
    final String rBvid = isPages ? bvid : episodes[nextIndex].bvid;
    final int rAid = isPages ? IdUtils.bv2av(bvid) : episodes[nextIndex].aid!;
    changeSeasonOrbangu(rBvid, cid, rAid);
    return true;
  }

  bool playRelated() {
    late RelatedController relatedCtr;
    try {
      relatedCtr = Get.find<RelatedController>(tag: heroTag);
      if (relatedCtr.relatedVideoList.isEmpty) {
        SmartDialog.showToast('暂无相关视频，停止连播');
        return false;
      }
    } catch (_) {
      relatedCtr = Get.put(RelatedController(), tag: heroTag);
      relatedCtr.queryRelatedVideo().then((value) {
        if (value['status']) {
          playRelated();
        }
      });
      return false;
    }

    final HotVideoItemModel videoItem = relatedCtr.relatedVideoList[0];
    if (PlPlayerController.getInstance().isFullScreen.value) {
      PlPlayerController.getInstance().toggleFullScreen(false);
    }
    try {
      if (videoItem.cid != null) {
        Get.offNamed('/video?bvid=${videoItem.bvid}&cid=${videoItem.cid}',
            arguments: {'videoItem': videoItem, 'heroTag': heroTag});
        // changeSeasonOrbangu(videoItem.bvid, videoItem.cid, videoItem.aid);
      } else {
        SearchHttp.ab2c(aid: videoItem.aid, bvid: videoItem.bvid).then((cid) =>
            Get.offNamed('/video?bvid=${videoItem.bvid}&cid=${videoItem.cid}',
                arguments: {'videoItem': videoItem, 'heroTag': heroTag}));
      }
    } catch (err) {
      SmartDialog.showToast(err.toString());
    }
    return true;
  }

  // 设置关注分组
  // void setFollowGroup() {
  //   MyDialog.showCorner(
  //       context, GroupPanel(mid: videoDetail.value.owner!.mid!));
  // }

  // ai总结
  Future aiConclusion() async {
    SmartDialog.showLoading(msg: '正在查询AI总结');
    final res = await VideoHttp.aiConclusion(
      bvid: bvid,
      cid: lastPlayCid.value,
      upMid: videoDetail.value.owner!.mid!,
    );
    SmartDialog.dismiss();
    if (!res['status']) {
      SmartDialog.showNotify(
          msg: "当前视频暂未生产AI视频总结",
          notifyType: NotifyType.warning,
          displayTime: const Duration(seconds: 1));
    }
    return res;
  }
}
