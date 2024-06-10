import 'dart:async';
import 'dart:io';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/http/constants.dart';
import 'package:PiliPalaX/http/video.dart';
import 'package:PiliPalaX/models/common/reply_type.dart';
import 'package:PiliPalaX/models/common/search_type.dart';
import 'package:PiliPalaX/models/video/play/quality.dart';
import 'package:PiliPalaX/models/video/play/url.dart';
import 'package:PiliPalaX/models/video/reply/item.dart';
import 'package:PiliPalaX/pages/video/detail/reply_reply/index.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/utils/utils.dart';
import 'package:PiliPalaX/utils/video_utils.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../utils/id_utils.dart';
import 'widgets/header_control.dart';

class VideoDetailController extends GetxController
    with GetSingleTickerProviderStateMixin {
  /// 路由传参
  String bvid = Get.parameters['bvid']!;
  RxInt cid = int.parse(Get.parameters['cid']!).obs;
  RxInt danmakuCid = 0.obs;
  String heroTag = Get.arguments['heroTag'];
  // 视频详情
  Map videoItem = {};
  // 视频类型 默认投稿视频
  SearchType videoType = Get.arguments['videoType'] ?? SearchType.video;

  /// tabs相关配置
  int tabInitialIndex = 0;
  late TabController tabCtr;
  RxList<String> tabs = <String>['简介', '评论'].obs;

  // 请求返回的视频信息
  late PlayUrlModel data;
  // 请求状态
  RxBool isLoading = false.obs;

  /// 播放器配置 画质 音质 解码格式
  late VideoQuality currentVideoQa;
  AudioQuality? currentAudioQa;
  late VideoDecodeFormats currentDecodeFormats;
  // 是否开始自动播放 存在多p的情况下，第二p需要为true
  RxBool autoPlay = true.obs;
  // 视频资源是否有效
  RxBool isEffective = true.obs;
  // 封面图的展示
  RxBool isShowCover = true.obs;
  // 硬解
  RxBool enableHA = true.obs;
  RxString hwdec = 'auto-safe'.obs;

  /// 本地存储
  Box userInfoCache = GStrorage.userInfo;
  Box localCache = GStrorage.localCache;
  Box setting = GStrorage.setting;

  RxInt oid = 0.obs;
  // 评论id 请求楼中楼评论使用
  int fRpid = 0;

  ReplyItemModel? firstFloor;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  RxString bgCover = ''.obs;
  PlPlayerController plPlayerController = PlPlayerController.getInstance();

  late VideoItem firstVideo;
  late AudioItem firstAudio;
  late String videoUrl;
  late String audioUrl;
  late Duration defaultST;
  // 亮度
  double? brightness;
  // 默认记录历史记录
  bool enableHeart = true;
  var userInfo;
  late bool isFirstTime = true;
  Floating? floating;
  late PreferredSizeWidget headerControl;

  late bool enableCDN;
  late int? cacheVideoQa;
  late String cacheDecode;
  late String cacheSecondDecode;
  late int cacheAudioQa;

  PersistentBottomSheetController? replyReplyBottomSheetCtr;

  @override
  void onInit() {
    super.onInit();
    final Map argMap = Get.arguments;
    userInfo = userInfoCache.get('userInfoCache');
    var keys = argMap.keys.toList();
    if (keys.isNotEmpty) {
      if (keys.contains('videoItem')) {
        var args = argMap['videoItem'];
        if (args.pic != null && args.pic != '') {
          videoItem['pic'] = args.pic;
        }
      }
      if (keys.contains('pic')) {
        videoItem['pic'] = argMap['pic'];
      }
    }
    bool defaultShowComment =
        setting.get(SettingBoxKey.defaultShowComment, defaultValue: false);
    tabCtr = TabController(
        length: 2, vsync: this, initialIndex: defaultShowComment ? 1 : 0);
    autoPlay.value =
        setting.get(SettingBoxKey.autoPlayEnable, defaultValue: true);
    enableHA.value = setting.get(SettingBoxKey.enableHA, defaultValue: true);
    hwdec.value = setting.get(SettingBoxKey.hardwareDecoding,
        defaultValue: Platform.isAndroid ? 'auto-safe' : 'auto');
    if (userInfo == null ||
        localCache.get(LocalCacheKey.historyPause) == true) {
      enableHeart = false;
    }
    danmakuCid.value = cid.value;

    ///
    if (Platform.isAndroid) {
      floating = Floating();
    }
    headerControl = HeaderControl(
      controller: plPlayerController,
      videoDetailCtr: this,
      floating: floating,
      heroTag: heroTag,
    );
    // CDN优化
    enableCDN = setting.get(SettingBoxKey.enableCDN, defaultValue: true);
    // 预设的画质
    cacheVideoQa = setting.get(SettingBoxKey.defaultVideoQa,
        defaultValue: VideoQuality.values.last.code);
    // 预设的解码格式
    cacheDecode = setting.get(SettingBoxKey.defaultDecode,
        defaultValue: VideoDecodeFormats.values.last.code);
    cacheSecondDecode = setting.get(SettingBoxKey.secondDecode,
        defaultValue: VideoDecodeFormats.values[1].code);
    cacheAudioQa = setting.get(SettingBoxKey.defaultAudioQa,
        defaultValue: AudioQuality.hiRes.code);
    oid.value = IdUtils.bv2av(Get.parameters['bvid']!);
  }

  showReplyReplyPanel() {
    replyReplyBottomSheetCtr =
        scaffoldKey.currentState?.showBottomSheet((BuildContext context) {
      return VideoReplyReplyPanel(
        oid: oid.value,
        rpid: fRpid,
        closePanel: () => {
          fRpid = 0,
        },
        firstFloor: firstFloor,
        replyType: ReplyType.video,
        source: 'videoDetail',
      );
    });
    replyReplyBottomSheetCtr?.closed.then((value) {
      fRpid = 0;
    });
  }

  /// 更新画质、音质
  /// TODO 继续进度播放
  updatePlayer() {
    isShowCover.value = false;
    defaultST = plPlayerController.position.value;
    plPlayerController.removeListeners();
    plPlayerController.isBuffering.value = false;
    plPlayerController.buffered.value = Duration.zero;

    /// 根据currentVideoQa和currentDecodeFormats 重新设置videoUrl
    List<VideoItem> videoList =
        data.dash!.video!.where((i) => i.id == currentVideoQa.code).toList();

    final List supportDecodeFormats = videoList.map((e) => e.codecs!).toList();
    VideoDecodeFormats defaultDecodeFormats =
        VideoDecodeFormatsCode.fromString(cacheDecode)!;
    VideoDecodeFormats secondDecodeFormats =
        VideoDecodeFormatsCode.fromString(cacheSecondDecode)!;
    try {
      // 当前视频没有对应格式返回第一个
      int flag = 0;
      for (var i in supportDecodeFormats) {
        if (i.startsWith(currentDecodeFormats.code)) {
          flag = 1;
          break;
        } else if (i.startsWith(defaultDecodeFormats.code)) {
          flag = 2;
        } else if (i.startsWith(secondDecodeFormats.code)) {
          if (flag == 0) {
            flag = 4;
          }
        }
      }
      if (flag == 1) {
        //currentDecodeFormats
        firstVideo = videoList.first;
      } else {
        if (currentVideoQa == VideoQuality.dolbyVision) {
          currentDecodeFormats =
              VideoDecodeFormatsCode.fromString(videoList.first.codecs!)!;
          firstVideo = videoList.first;
        } else if (flag == 2) {
          //defaultDecodeFormats
          currentDecodeFormats = defaultDecodeFormats;
          firstVideo = videoList.firstWhere(
            (i) => i.codecs!.startsWith(defaultDecodeFormats.code),
          );
        } else if (flag == 4) {
          //secondDecodeFormats
          currentDecodeFormats = secondDecodeFormats;
          firstVideo = videoList.firstWhere(
            (i) => i.codecs!.startsWith(secondDecodeFormats.code),
          );
        } else if (flag == 0) {
          currentDecodeFormats =
              VideoDecodeFormatsCode.fromString(supportDecodeFormats.first)!;
          firstVideo = videoList.first;
        }
      }
    } catch (err) {
      SmartDialog.showToast('DecodeFormats error: $err');
    }

    videoUrl = firstVideo.baseUrl!;

    /// 根据currentAudioQa 重新设置audioUrl
    if (currentAudioQa != null) {
      final AudioItem firstAudio = data.dash!.audio!.firstWhere(
        (AudioItem i) => i.id == currentAudioQa!.code,
        orElse: () => data.dash!.audio!.first,
      );
      audioUrl = firstAudio.baseUrl ?? '';
    }

    playerInit();
  }

  Future playerInit({
    video,
    audio,
    seekToTime,
    duration,
    bool autoplay = true,
  }) async {
    /// 设置/恢复 屏幕亮度
    if (brightness != null) {
      ScreenBrightness().setScreenBrightness(brightness!);
    } else {
      ScreenBrightness().resetScreenBrightness();
    }
    await plPlayerController.setDataSource(
      DataSource(
        videoSource: video ?? videoUrl,
        audioSource: audio ?? audioUrl,
        type: DataSourceType.network,
        httpHeaders: {
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36',
          'referer': HttpString.baseUrl
        },
      ),
      // 硬解
      enableHA: enableHA.value,
      hwdec: hwdec.value,
      seekTo: seekToTime ?? defaultST,
      duration: duration ?? data.timeLength == null
          ? null
          : Duration(milliseconds: data.timeLength!),
      // 宽>高 水平 否则 垂直
      direction: firstVideo.width != null && firstVideo.height != null
          ? ((firstVideo.width! - firstVideo.height!) > 0
              ? 'horizontal'
              : 'vertical')
          : null,
      bvid: bvid,
      cid: cid.value,
      enableHeart: enableHeart,
      autoplay: autoplay,
    );

    /// 开启自动全屏时，在player初始化完成后立即传入headerControl
    plPlayerController.headerControl = headerControl;
  }

  // 视频链接
  Future queryVideoUrl() async {
    var result = await VideoHttp.videoUrl(cid: cid.value, bvid: bvid);
    if (result['status']) {
      data = result['data'];
      if (data.acceptDesc!.isNotEmpty && data.acceptDesc!.contains('试看')) {
        SmartDialog.showToast(
          '该视频为专属视频，仅提供试看',
          displayTime: const Duration(seconds: 3),
        );
      }
      if (data.dash == null && data.durl != null) {
        videoUrl = data.durl!.first.url!;
        audioUrl = '';
        defaultST = Duration.zero;
        // 实际为FLV/MP4格式，但已被淘汰，这里仅做兜底处理
        firstVideo = VideoItem(
          id: data.quality!,
          baseUrl: videoUrl,
          codecs: 'avc1',
          quality: VideoQualityCode.fromCode(data.quality!)!
        );
        currentDecodeFormats = VideoDecodeFormatsCode.fromString('avc1')!;
        currentVideoQa = VideoQualityCode.fromCode(data.quality!)!;
        if (autoPlay.value) {
          await playerInit();
          isShowCover.value = false;
        }
        return result;
      }
      if (data.dash == null) {
        SmartDialog.showToast('视频资源不存在');
        isShowCover.value = false;
        return result;
      }
      final List<VideoItem> allVideosList = data.dash!.video!;
      // print("allVideosList:${allVideosList}");
      // 当前可播放的最高质量视频
      int currentHighVideoQa = allVideosList.first.quality!.code;
      // 预设的画质为null，则当前可用的最高质量
      cacheVideoQa ??= currentHighVideoQa;
      int resVideoQa = currentHighVideoQa;
      if (cacheVideoQa! <= currentHighVideoQa) {
        // 如果预设的画质低于当前最高
        final List<int> numbers =
            data.acceptQuality!.where((e) => e <= currentHighVideoQa).toList();
        resVideoQa = Utils.findClosestNumber(cacheVideoQa!, numbers);
      }
      currentVideoQa = VideoQualityCode.fromCode(resVideoQa)!;

      /// 取出符合当前画质的videoList
      final List<VideoItem> videosList =
          allVideosList.where((e) => e.quality!.code == resVideoQa).toList();

      /// 优先顺序 设置中指定解码格式 -> 当前可选的首个解码格式
      final List<FormatItem> supportFormats = data.supportFormats!;
      // 根据画质选编码格式
      final List supportDecodeFormats = supportFormats
          .firstWhere((e) => e.quality == resVideoQa,
              orElse: () => supportFormats.first)
          .codecs!;
      // 默认从设置中取AV1
      currentDecodeFormats = VideoDecodeFormatsCode.fromString(cacheDecode)!;
      VideoDecodeFormats secondDecodeFormats =
          VideoDecodeFormatsCode.fromString(cacheSecondDecode)!;
      // 当前视频没有对应格式返回第一个
      int flag = 0;
      for (var i in supportDecodeFormats) {
        if (i.startsWith(currentDecodeFormats.code)) {
          flag = 1;
          break;
        } else if (i.startsWith(secondDecodeFormats.code)) {
          flag = 2;
        }
      }
      if (flag == 2) {
        currentDecodeFormats = secondDecodeFormats;
      } else if (flag == 0) {
        currentDecodeFormats =
            VideoDecodeFormatsCode.fromString(supportDecodeFormats.first)!;
      }

      /// 取出符合当前解码格式的videoItem
      firstVideo = videosList.firstWhere(
          (e) => e.codecs!.startsWith(currentDecodeFormats.code),
          orElse: () => videosList.first);

      videoUrl = enableCDN
          ? VideoUtils.getCdnUrl(firstVideo)
          : (firstVideo.backupUrl ?? firstVideo.baseUrl!);

      /// 优先顺序 设置中指定质量 -> 当前可选的最高质量
      late AudioItem? firstAudio;
      final List<AudioItem> audiosList = data.dash!.audio!;

      if (data.dash!.dolby?.audio != null && data.dash!.dolby!.audio!.isNotEmpty) {
        // 杜比
        audiosList.insert(0, data.dash!.dolby!.audio!.first);
      }

      if (data.dash!.flac?.audio != null) {
        // 无损
        audiosList.insert(0, data.dash!.flac!.audio!);
      }

      if (audiosList.isNotEmpty) {
        final List<int> numbers = audiosList.map((map) => map.id!).toList();
        int closestNumber = Utils.findClosestNumber(cacheAudioQa, numbers);
        if (!numbers.contains(cacheAudioQa) &&
            numbers.any((e) => e > cacheAudioQa)) {
          closestNumber = 30280;
        }
        firstAudio = audiosList.firstWhere((e) => e.id == closestNumber,
            orElse: () => audiosList.first);
      } else {
        firstAudio = AudioItem();
      }

      audioUrl = enableCDN
          ? VideoUtils.getCdnUrl(firstAudio)
          : (firstAudio.backupUrl ?? firstAudio.baseUrl!);
      //
      if (firstAudio.id != null) {
        currentAudioQa = AudioQualityCode.fromCode(firstAudio.id!)!;
      }
      defaultST = Duration(milliseconds: data.lastPlayTime!);
      if (autoPlay.value) {
        await playerInit();
        isShowCover.value = false;
      }
    } else {
      if (result['code'] == -404) {
        isShowCover.value = false;
        SmartDialog.showToast('视频不存在或已被删除');
      }
      if (result['code'] == 87008) {
        SmartDialog.showToast("当前视频可能是专属视频，可能需包月充电观看(${result['msg']})");
      } else {
        SmartDialog.showToast("错误（${result['code']}）：${result['msg']}");
      }
    }
    return result;
  }

  // mob端全屏状态关闭二级回复
  hiddenReplyReplyPanel() {
    replyReplyBottomSheetCtr != null
        ? replyReplyBottomSheetCtr!.close()
        : print('replyReplyBottomSheetCtr is null');
  }
}
