import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:floating/floating.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:nil/nil.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/http/user.dart';
import 'package:PiliPalaX/models/common/search_type.dart';
import 'package:PiliPalaX/pages/bangumi/introduction/index.dart';
import 'package:PiliPalaX/pages/danmaku/view.dart';
import 'package:PiliPalaX/pages/video/detail/reply/index.dart';
import 'package:PiliPalaX/pages/video/detail/controller.dart';
import 'package:PiliPalaX/pages/video/detail/introduction/index.dart';
import 'package:PiliPalaX/pages/video/detail/related/index.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPalaX/services/service_locator.dart';
import 'package:PiliPalaX/utils/storage.dart';

import '../../../services/shutdown_timer_service.dart';
import 'widgets/header_control.dart';

class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({Key? key}) : super(key: key);

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();
}

class _VideoDetailPageState extends State<VideoDetailPage>
    with TickerProviderStateMixin, RouteAware {
  late VideoDetailController videoDetailController;
  PlPlayerController? plPlayerController;
  late StreamController<double> appbarStream;
  late VideoIntroController videoIntroController;
  late BangumiIntroController bangumiIntroController;
  late String heroTag;

  PlayerStatus playerStatus = PlayerStatus.playing;
  double doubleOffset = 0;

  final Box<dynamic> localCache = GStrorage.localCache;
  final Box<dynamic> setting = GStrorage.setting;
  late Future _futureBuilderFuture;
  // 自动退出全屏
  late bool autoExitFullcreen;
  late bool autoPlayEnable;
  late bool horizontalScreen;
  late bool enableVerticalExpand;
  late bool autoPiP;
  late bool pipNoDanmaku;
  late bool removeSafeArea;
  late bool showStatusBarBackgroundColor;
  final Floating floating = Floating();
  // 生命周期监听
  // late final AppLifecycleListener _lifecycleListener;
  bool isShowing = true;
  RxBool isFullScreen = false.obs;
  late StreamSubscription<bool> fullScreenStatusListener;
  late final MethodChannel onUserLeaveHintListener;
  // StreamSubscription<Duration>? _bufferedListener;

  @override
  void initState() {
    super.initState();
    if (Get.arguments != null && Get.arguments['heroTag'] != null) {
      heroTag = Get.arguments['heroTag'];
    }
    videoDetailController = Get.put(VideoDetailController(), tag: heroTag);
    videoIntroController = Get.put(VideoIntroController(), tag: heroTag);
    videoIntroController.videoDetail.listen((value) {
      videoPlayerServiceHandler.onVideoDetailChange(
          value, videoDetailController.cid.value);
    });
    bangumiIntroController = Get.put(BangumiIntroController(), tag: heroTag);
    bangumiIntroController.bangumiDetail.listen((value) {
      videoPlayerServiceHandler.onVideoDetailChange(
          value, videoDetailController.cid.value);
    });
    videoDetailController.cid.listen((p0) {
      videoPlayerServiceHandler.onVideoDetailChange(
          bangumiIntroController.bangumiDetail.value, p0);
    });
    autoExitFullcreen =
        setting.get(SettingBoxKey.enableAutoExit, defaultValue: true);
    horizontalScreen =
        setting.get(SettingBoxKey.horizontalScreen, defaultValue: false);
    autoPlayEnable =
        setting.get(SettingBoxKey.autoPlayEnable, defaultValue: true);
    autoPiP = setting.get(SettingBoxKey.autoPiP, defaultValue: false);
    pipNoDanmaku = setting.get(SettingBoxKey.pipNoDanmaku, defaultValue: true);
    enableVerticalExpand =
        setting.get(SettingBoxKey.enableVerticalExpand, defaultValue: false);
    removeSafeArea = setting.get(SettingBoxKey.videoPlayerRemoveSafeArea,
        defaultValue: false);
    showStatusBarBackgroundColor = setting.get(
        SettingBoxKey.videoPlayerShowStatusBarBackgroundColor,
        defaultValue: false);
    if (removeSafeArea) hideStatusBar();
    videoSourceInit();
    appbarStreamListen();
    // lifecycleListener();
    autoScreen();
    onUserLeaveHintListener = const MethodChannel("onUserLeaveHint");
    onUserLeaveHintListener.setMethodCallHandler((call) async {
      if (call.method == 'onUserLeaveHint') {
        if (autoPiP) {
          autoEnterPip();
        }
      }
    });
    // _animationController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(milliseconds: 300),
    // );
    // _animation = Tween<double>(
    //   begin: MediaQuery.of(context).orientation == Orientation.landscape
    //       ? context.height
    //       : ((enableVerticalExpand &&
    //               plPlayerController?.direction.value == 'vertical')
    //           ? context.width * 5 / 4
    //           : context.width * 9 / 16),
    //   end: 0,
    // ).animate(_animationController);
  }

  // 获取视频资源，初始化播放器
  Future<void> videoSourceInit() async {
    _futureBuilderFuture = videoDetailController.queryVideoUrl();
    if (videoDetailController.autoPlay.value) {
      plPlayerController = videoDetailController.plPlayerController;
      plPlayerController!.addStatusLister(playerListener);
      listenFullScreenStatus();
      await plPlayerController!.autoEnterFullscreen();
    }
  }

  // 流
  appbarStreamListen() {
    appbarStream = StreamController<double>();
  }

  // 播放器状态监听
  void playerListener(PlayerStatus? status) async {
    playerStatus = status!;
    if (status == PlayerStatus.completed) {
      shutdownTimerService.handleWaitingFinished();
      bool notExitFlag = false;

      /// 顺序播放 列表循环
      if (plPlayerController!.playRepeat != PlayRepeat.pause &&
          plPlayerController!.playRepeat != PlayRepeat.singleCycle) {
        if (videoDetailController.videoType == SearchType.video) {
          notExitFlag = videoIntroController.nextPlay();
        }
        if (videoDetailController.videoType == SearchType.media_bangumi) {
          notExitFlag = bangumiIntroController.nextPlay();
        }
      }

      /// 单个循环
      if (plPlayerController!.playRepeat == PlayRepeat.singleCycle) {
        notExitFlag = true;
        plPlayerController!.seekTo(Duration.zero);
        plPlayerController!.play();
      }

      // 结束播放退出全屏
      if (!notExitFlag && autoExitFullcreen) {
        plPlayerController!.triggerFullScreen(status: false);
      }
      // 播放完展示控制栏
      if (videoDetailController.floating != null) {
        PiPStatus currentStatus =
            await videoDetailController.floating!.pipStatus;
        if (currentStatus == PiPStatus.disabled) {
          plPlayerController!.onLockControl(false);
        }
      }
    }
  }

  // 继续播放或重新播放
  void continuePlay() async {
    plPlayerController!.play();
  }

  /// 未开启自动播放时触发播放
  Future<void> handlePlay() async {
    await videoDetailController.playerInit();
    plPlayerController = videoDetailController.plPlayerController;
    plPlayerController!.addStatusLister(playerListener);
    listenFullScreenStatus();
    await plPlayerController!.autoEnterFullscreen();
    videoDetailController.autoPlay.value = true;
    videoDetailController.isShowCover.value = false;
  }

  // // 生命周期监听
  // void lifecycleListener() {
  //   _lifecycleListener = AppLifecycleListener(
  //     onResume: () => _handleTransition('resume'),
  //     // 后台
  //     onInactive: () => _handleTransition('inactive'),
  //     // 在Android和iOS端不生效
  //     onHide: () => _handleTransition('hide'),
  //     onShow: () => _handleTransition('show'),
  //     onPause: () => _handleTransition('pause'),
  //     onRestart: () => _handleTransition('restart'),
  //     onDetach: () => _handleTransition('detach'),
  //     // 只作用于桌面端
  //     onExitRequested: () {
  //       ScaffoldMessenger.maybeOf(context)
  //           ?.showSnackBar(const SnackBar(content: Text("拦截应用退出")));
  //       return Future.value(AppExitResponse.cancel);
  //     },
  //   );
  // }

  void listenFullScreenStatus() {
    fullScreenStatusListener =
        plPlayerController!.isFullScreen.listen((bool status) {
      if (status) {
        videoDetailController.hiddenReplyReplyPanel();
        // hideStatusBar();
      }
      isFullScreen.value = status;
      if (mounted) {
        setState(() {});
      }
      // if (!status) {
      // showStatusBar();
      // if (horizontalScreen) {
      //   autoScreen();
      // } else {
      //   verticalScreenForTwoSeconds();
      // }
      // }
    });
  }

  @override
  void dispose() {
    videoDetailController.floating?.dispose();
    floating.dispose();
    videoIntroController.videoDetail.close();
    bangumiIntroController.bangumiDetail.close();
    videoDetailController.cid.close();
    if (!horizontalScreen) {
      AutoOrientation.portraitUpMode();
    }
    shutdownTimerService.handleWaitingFinished();
    // _bufferedListener?.cancel();
    if (plPlayerController != null) {
      plPlayerController!.removeStatusLister(playerListener);
      fullScreenStatusListener.cancel();
      plPlayerController!.dispose();
    }
    videoPlayerServiceHandler.onVideoDetailDispose();
    // _lifecycleListener.dispose();
    showStatusBar();
    // _animationController.dispose();
    super.dispose();
  }

  @override
  // 离开当前页面时
  void didPushNext() async {
    // _bufferedListener?.cancel();

    /// 开启
    if (setting.get(SettingBoxKey.enableAutoBrightness, defaultValue: false)
        as bool) {
      videoDetailController.brightness = plPlayerController!.brightness.value;
    }
    if (plPlayerController != null) {
      videoDetailController.defaultST = plPlayerController!.position.value;
      videoIntroController.isPaused = true;
      plPlayerController!.removeStatusLister(playerListener);
      fullScreenStatusListener.cancel();
      plPlayerController!.pause();
    }
    isShowing = false;
    if (mounted) {
      setState(() => {});
    }
    super.didPushNext();
  }

  @override
  // 返回当前页面时
  void didPopNext() async {
    isShowing = true;
    if (mounted) {
      setState(() => {});
    }
    super.didPopNext();
    videoDetailController.isFirstTime = false;
    final bool autoplay = autoPlayEnable;
    await videoDetailController.playerInit(autoplay: autoplay);

    /// 未开启自动播放时，未播放跳转下一页返回/播放后跳转下一页返回
    videoDetailController.autoPlay.value =
        !videoDetailController.isShowCover.value;
    videoIntroController.isPaused = false;
    // if (autoplay) {
    //   // await Future.delayed(const Duration(milliseconds: 300));
    //   print(plPlayerController);
    //   if (plPlayerController?.buffered.value == Duration.zero) {
    //     _bufferedListener = plPlayerController?.buffered.listen((p0) {
    //       print("p0");
    //       print(p0);
    //       if (p0 > Duration.zero) {
    //         _bufferedListener!.cancel();
    //         plPlayerController?.seekTo(videoDetailController.defaultST);
    //         plPlayerController?.play();
    //       }
    //     });
    //   } else {
    //     plPlayerController?.seekTo(videoDetailController.defaultST);
    //     plPlayerController?.play();
    //   }
    // }
    Future.delayed(const Duration(milliseconds: 600), () {
      AutoOrientation.fullAutoMode();
    });
    plPlayerController?.addStatusLister(playerListener);
    if (plPlayerController != null) {
      listenFullScreenStatus();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    VideoDetailPage.routeObserver
        .subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  // void _handleTransition(String name) {
  //   switch (name) {
  //     case 'inactive':
  //       if (plPlayerController != null &&
  //           playerStatus == PlayerStatus.playing) {
  //         autoEnterPip();
  //       }
  //       break;
  //   }
  // }

  void autoEnterPip() {
    final String routePath = Get.currentRoute;

    if (autoPiP && routePath.startsWith('/video')) {
      floating.enable(
          aspectRatio: Rational(
        videoDetailController.data.dash!.video!.first.width!,
        videoDetailController.data.dash!.video!.first.height!,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget plPlayer = FutureBuilder(
        future: _futureBuilderFuture,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData && snapshot.data['status']) {
            return Obx(
              () => !videoDetailController.autoPlay.value ||
                      plPlayerController == null ||
                      plPlayerController!.videoController == null
                  ? nil
                  : PLVideoPlayer(
                      controller: plPlayerController!,
                      videoIntroController:
                          videoDetailController.videoType == SearchType.video
                              ? videoIntroController
                              : null,
                      bangumiIntroController: videoDetailController.videoType ==
                              SearchType.media_bangumi
                          ? bangumiIntroController
                          : null,
                      headerControl: videoDetailController.headerControl,
                      danmuWidget: Obx(
                        () => PlDanmaku(
                          key: Key(videoDetailController.danmakuCid.value
                              .toString()),
                          cid: videoDetailController.danmakuCid.value,
                          playerController: plPlayerController!,
                        ),
                      ),
                    ),
            );
          } else {
            return const SizedBox();
          }
        });
    Widget manualPlayerWidget = Obx(
      () => Visibility(
          visible: videoDetailController.isShowCover.value &&
              videoDetailController.isEffective.value,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  primary: false,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,
                  actions: [
                    IconButton(
                      tooltip: '稍后再看',
                      onPressed: () async {
                        var res = await UserHttp.toViewLater(
                            bvid: videoDetailController.bvid);
                        SmartDialog.showToast(res['msg']);
                      },
                      icon: const Icon(Icons.history_outlined),
                    ),
                    const SizedBox(width: 14)
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 10,
                child: IconButton(
                    tooltip: '播放',
                    onPressed: () => handlePlay(),
                    icon: Image.asset(
                      'assets/images/play.png',
                      width: 60,
                      height: 60,
                    )),
              ),
            ],
          )),
    );
    Widget childWhenDisabled = SafeArea(
      top: !removeSafeArea &&
          MediaQuery.of(context).orientation == Orientation.portrait &&
          isFullScreen.value == true,
      bottom: !removeSafeArea &&
          MediaQuery.of(context).orientation == Orientation.portrait &&
          isFullScreen.value == true,
      left: false, //isFullScreen != true,
      right: false, //isFullScreen != true,
      child: Stack(
        children: [
          Scaffold(
              resizeToAvoidBottomInset: false,
              key: videoDetailController.scaffoldKey,
              // backgroundColor: Colors.black,
              appBar: removeSafeArea
                  ? null
                  : AppBar(
                      backgroundColor:
                          showStatusBarBackgroundColor ? null : Colors.black,
                      elevation: 0,
                      toolbarHeight: 0,
                      systemOverlayStyle: SystemUiOverlayStyle(
                          statusBarIconBrightness:
                              Theme.of(context).brightness == Brightness.dark ||
                                      !showStatusBarBackgroundColor
                                  ? Brightness.light
                                  : Brightness.dark,
                          systemNavigationBarColor: Colors.transparent),
                    ),
              body: Column(
                children: [
                  Obx(
                    () {
                      double videoheight = context.width * 9 / 16;
                      final double videowidth = context.width;
                      // print(videoDetailController.tabCtr.index);
                      if (enableVerticalExpand &&
                          plPlayerController?.direction.value == 'vertical') {
                        videoheight = context.width;
                      }
                      if (MediaQuery.of(context).orientation ==
                              Orientation.landscape &&
                          !horizontalScreen &&
                          !isFullScreen.value &&
                          isShowing &&
                          mounted) {
                        hideStatusBar();
                      }
                      if (MediaQuery.of(context).orientation ==
                              Orientation.portrait &&
                          !isFullScreen.value &&
                          isShowing &&
                          mounted) {
                        if (!removeSafeArea) showStatusBar();
                      }
                      return Container(
                        color:
                            showStatusBarBackgroundColor ? null : Colors.black,
                        height: MediaQuery.of(context).orientation ==
                                    Orientation.landscape ||
                                isFullScreen.value == true
                            ? MediaQuery.sizeOf(context).height -
                                (MediaQuery.of(context).orientation ==
                                            Orientation.landscape ||
                                        removeSafeArea
                                    ? 0
                                    : MediaQuery.of(context).padding.top)
                            : videoheight,
                        width: context.width,
                        child: PopScope(
                            canPop: isFullScreen.value != true &&
                                (horizontalScreen ||
                                    MediaQuery.of(context).orientation ==
                                        Orientation.portrait),
                            onPopInvoked: (bool didPop) {
                              if (isFullScreen.value == true) {
                                plPlayerController!
                                    .triggerFullScreen(status: false);
                              }
                              if (MediaQuery.of(context).orientation ==
                                      Orientation.landscape &&
                                  !horizontalScreen) {
                                verticalScreenForTwoSeconds();
                              }
                            },
                            child: Stack(
                              children: <Widget>[
                                if (isShowing) plPlayer,

                                /// 关闭自动播放时 手动播放
                                if (!videoDetailController
                                    .autoPlay.value) ...<Widget>[
                                  Obx(
                                    () => Visibility(
                                      visible: videoDetailController
                                          .isShowCover.value,
                                      child: Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {
                                            handlePlay();
                                          },
                                          child: NetworkImgLayer(
                                            type: 'emote',
                                            src: videoDetailController
                                                .videoItem['pic'],
                                            width: videowidth,
                                            height: videoheight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  manualPlayerWidget,
                                ]
                              ],
                            )),
                      );
                    },
                  ),
                  Expanded(
                    child: ColoredBox(
                      key: Key(heroTag),
                      color: Theme.of(context).colorScheme.background,
                      child: Column(
                        children: [
                          Opacity(
                            opacity: 0,
                            child: SizedBox(
                              width: context.width,
                              height: 0,
                              child: Obx(
                                () => TabBar(
                                  controller: videoDetailController.tabCtr,
                                  dividerColor: Colors.transparent,
                                  indicatorColor:
                                      Theme.of(context).colorScheme.background,
                                  tabs: videoDetailController.tabs
                                      .map((String name) => Tab(text: name))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TabBarView(
                              physics: const BouncingScrollPhysics(),
                              controller: videoDetailController.tabCtr,
                              children: <Widget>[
                                CustomScrollView(
                                  key: const PageStorageKey<String>('简介'),
                                  slivers: <Widget>[
                                    if (videoDetailController.videoType ==
                                        SearchType.video) ...[
                                      VideoIntroPanel(heroTag: heroTag),
                                    ] else if (videoDetailController
                                            .videoType ==
                                        SearchType.media_bangumi) ...[
                                      Obx(() => BangumiIntroPanel(
                                          heroTag: heroTag,
                                          cid:
                                              videoDetailController.cid.value)),
                                    ],
                                    SliverToBoxAdapter(
                                      child: Divider(
                                        indent: 12,
                                        endIndent: 12,
                                        color: Theme.of(context)
                                            .dividerColor
                                            .withOpacity(0.06),
                                      ),
                                    ),
                                    RelatedVideoPanel(heroTag: heroTag),
                                  ],
                                ),
                                Obx(
                                  () => VideoReplyPanel(
                                    bvid: videoDetailController.bvid,
                                    oid: videoDetailController.oid.value,
                                    heroTag: heroTag,
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
    Widget childWhenDisabledAlmostSquareInner = Obx(() {
      if (enableVerticalExpand &&
          plPlayerController?.direction.value == 'vertical') {
        final double videoheight = context.height -
            (removeSafeArea
                ? 0
                : (MediaQuery.of(context).padding.top +
                    MediaQuery.of(context).padding.bottom));
        final double videowidth = videoheight * 9 / 16;
        return Row(children: [
          SizedBox(
            height: videoheight,
            width: isFullScreen.value == true ? context.width : videowidth,
            child: PopScope(
              canPop: isFullScreen.value != true,
              onPopInvoked: (bool didPop) {
                if (isFullScreen.value == true) {
                  plPlayerController!.triggerFullScreen(status: false);
                }
                if (MediaQuery.of(context).orientation ==
                        Orientation.landscape &&
                    !horizontalScreen) {
                  verticalScreenForTwoSeconds();
                }
              },
              child: Stack(children: <Widget>[
                if (isShowing) plPlayer,

                /// 关闭自动播放时 手动播放
                if (!videoDetailController.autoPlay.value) ...<Widget>[
                  Obx(
                    () => Visibility(
                      visible: videoDetailController.isShowCover.value,
                      child: Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            handlePlay();
                          },
                          child: NetworkImgLayer(
                            type: 'emote',
                            src: videoDetailController.videoItem['pic'],
                            width: videowidth,
                            height: videoheight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  manualPlayerWidget,
                ]
              ]),
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const BouncingScrollPhysics(),
              controller: videoDetailController.tabCtr,
              children: <Widget>[
                CustomScrollView(
                  key: const PageStorageKey<String>('简介'),
                  slivers: <Widget>[
                    if (videoDetailController.videoType ==
                        SearchType.video) ...[
                      VideoIntroPanel(heroTag: heroTag),
                    ] else if (videoDetailController.videoType ==
                        SearchType.media_bangumi) ...[
                      Obx(() => BangumiIntroPanel(
                          heroTag: heroTag,
                          cid: videoDetailController.cid.value)),
                    ],
                    SliverToBoxAdapter(
                      child: Divider(
                        indent: 12,
                        endIndent: 12,
                        color: Theme.of(context).dividerColor.withOpacity(0.06),
                      ),
                    ),
                    RelatedVideoPanel(heroTag: heroTag),
                  ],
                ),
                Obx(
                  () => VideoReplyPanel(
                    bvid: videoDetailController.bvid,
                    oid: videoDetailController.oid.value,
                    heroTag: heroTag,
                  ),
                )
              ],
            ),
          ),
        ]);
      }
      final double videoheight = context.height / 2.5;
      final double videowidth = context.width;
      return Column(
        children: [
          SizedBox(
            width: videowidth,
            height: isFullScreen.value == true
                ? context.height -
                    (removeSafeArea
                        ? 0
                        : (MediaQuery.of(context).padding.top +
                            MediaQuery.of(context).padding.bottom))
                : videoheight,
            child: PopScope(
              canPop: isFullScreen.value != true,
              onPopInvoked: (bool didPop) {
                if (isFullScreen.value == true) {
                  plPlayerController!.triggerFullScreen(status: false);
                }
                if (MediaQuery.of(context).orientation ==
                        Orientation.landscape &&
                    !horizontalScreen) {
                  verticalScreenForTwoSeconds();
                }
              },
              child: Stack(children: <Widget>[
                if (isShowing) plPlayer,

                /// 关闭自动播放时 手动播放
                if (!videoDetailController.autoPlay.value) ...<Widget>[
                  Obx(
                    () => Visibility(
                      visible: videoDetailController.isShowCover.value,
                      child: Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            handlePlay();
                          },
                          child: NetworkImgLayer(
                            type: 'emote',
                            src: videoDetailController.videoItem['pic'],
                            width: videowidth,
                            height: videoheight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  manualPlayerWidget,
                ]
              ]),
            ),
          ),
          Expanded(
              child: Row(children: [
            Expanded(
                child: CustomScrollView(
              key: PageStorageKey<String>('简介${videoDetailController.bvid}'),
              slivers: <Widget>[
                if (videoDetailController.videoType == SearchType.video) ...[
                  VideoIntroPanel(heroTag: heroTag),
                  RelatedVideoPanel(heroTag: heroTag),
                ] else if (videoDetailController.videoType ==
                    SearchType.media_bangumi) ...[
                  Obx(() => BangumiIntroPanel(
                      heroTag: heroTag, cid: videoDetailController.cid.value)),
                ]
              ],
            )),
            Expanded(
              child: Obx(
                () => VideoReplyPanel(
                  bvid: videoDetailController.bvid,
                  oid: videoDetailController.oid.value,
                  heroTag: heroTag,
                ),
              ),
            )
          ]))
        ],
      );
    });
    Widget childWhenDisabledLandscapeInner = Obx(() {
      if (enableVerticalExpand &&
          plPlayerController?.direction.value == 'vertical') {
        final double videoheight = context.height -
            (removeSafeArea ? 0 : MediaQuery.of(context).padding.top);
        final double videowidth = videoheight * 9 / 16;
        return Row(
          children: [
            SizedBox(
              height: videoheight,
              width: isFullScreen.value == true ? context.width : videowidth,
              child: PopScope(
                canPop: isFullScreen.value != true,
                onPopInvoked: (bool didPop) {
                  if (isFullScreen.value == true) {
                    plPlayerController!.triggerFullScreen(status: false);
                  }
                  if (MediaQuery.of(context).orientation ==
                          Orientation.landscape &&
                      !horizontalScreen) {
                    verticalScreenForTwoSeconds();
                  }
                },
                child: Stack(
                  children: <Widget>[
                    if (isShowing) plPlayer,

                    /// 关闭自动播放时 手动播放
                    if (!videoDetailController.autoPlay.value) ...<Widget>[
                      Obx(
                        () => Visibility(
                          visible: videoDetailController.isShowCover.value,
                          child: Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                handlePlay();
                              },
                              child: NetworkImgLayer(
                                type: 'emote',
                                src: videoDetailController.videoItem['pic'],
                                width: videowidth,
                                height: videoheight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      manualPlayerWidget,
                    ]
                  ],
                ),
              ),
            ),
            Expanded(
                child: Row(children: [
              Expanded(
                  child: CustomScrollView(
                key: PageStorageKey<String>('简介${videoDetailController.bvid}'),
                slivers: <Widget>[
                  if (videoDetailController.videoType == SearchType.video) ...[
                    VideoIntroPanel(heroTag: heroTag),
                    RelatedVideoPanel(heroTag: heroTag),
                  ] else if (videoDetailController.videoType ==
                      SearchType.media_bangumi) ...[
                    Obx(() => BangumiIntroPanel(
                        heroTag: heroTag,
                        cid: videoDetailController.cid.value)),
                  ]
                ],
              )),
              Expanded(
                child: Obx(
                  () => VideoReplyPanel(
                    bvid: videoDetailController.bvid,
                    oid: videoDetailController.oid.value,
                    heroTag: heroTag,
                  ),
                ),
              )
            ]))
            // Expanded(
            //   child: TabBarView(
            //     physics: const BouncingScrollPhysics(),
            //     controller: videoDetailController.tabCtr,
            //     children: <Widget>[
            //       CustomScrollView(
            //         key: const PageStorageKey<String>('简介'),
            //         slivers: <Widget>[
            //           if (videoDetailController.videoType ==
            //               SearchType.video) ...[
            //             const VideoIntroPanel(),
            //           ] else if (videoDetailController.videoType ==
            //               SearchType.media_bangumi) ...[
            //             Obx(() => BangumiIntroPanel(
            //                 cid: videoDetailController.cid.value)),
            //           ],
            //           SliverToBoxAdapter(
            //             child: Divider(
            //               indent: 12,
            //               endIndent: 12,
            //               color: Theme.of(context).dividerColor.withOpacity(0.06),
            //             ),
            //           ),
            //           const RelatedVideoPanel(),
            //         ],
            //       ),
            //       Obx(
            //             () => VideoReplyPanel(
            //           bvid: videoDetailController.bvid,
            //           oid: videoDetailController.oid.value,
            //         ),
            //       )
            //     ],
            //   ),
            // ),
          ],
        );
      }
      final double videowidth =
          max(context.height / context.width * 1.04, 1 / 2) * context.width;
      final double videoheight = videowidth * 9 / 16;
      return Row(
        children: [
          Column(
            children: [
              SizedBox(
                  width:
                      isFullScreen.value == true ? context.width : videowidth,
                  height:
                      isFullScreen.value == true ? context.height : videoheight,
                  child: PopScope(
                      canPop: isFullScreen.value != true,
                      onPopInvoked: (bool didPop) {
                        if (isFullScreen.value == true) {
                          plPlayerController!.triggerFullScreen(status: false);
                        }
                        if (MediaQuery.of(context).orientation ==
                                Orientation.landscape &&
                            !horizontalScreen) {
                          verticalScreenForTwoSeconds();
                        }
                      },
                      child: Stack(
                        children: <Widget>[
                          if (isShowing) plPlayer,

                          /// 关闭自动播放时 手动播放
                          if (!videoDetailController
                              .autoPlay.value) ...<Widget>[
                            Obx(
                              () => Visibility(
                                visible:
                                    videoDetailController.isShowCover.value,
                                child: Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      handlePlay();
                                    },
                                    child: NetworkImgLayer(
                                      type: 'emote',
                                      src: videoDetailController
                                          .videoItem['pic'],
                                      width: videowidth,
                                      height: videoheight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            manualPlayerWidget,
                          ]
                        ],
                      ))),
              SizedBox(
                  width:
                      isFullScreen.value == true ? context.width : videowidth,
                  height: isFullScreen.value == true
                      ? 0
                      : context.height -
                          videoheight -
                          (removeSafeArea
                              ? 0
                              : MediaQuery.of(context).padding.top),
                  child: CustomScrollView(
                    key: PageStorageKey<String>(
                        '简介${videoDetailController.bvid}'),
                    slivers: <Widget>[
                      if (videoDetailController.videoType ==
                          SearchType.video) ...[
                        VideoIntroPanel(heroTag: heroTag),
                        RelatedVideoPanel(heroTag: heroTag),
                      ] else if (videoDetailController.videoType ==
                          SearchType.media_bangumi) ...[
                        Obx(() => BangumiIntroPanel(
                            heroTag: heroTag,
                            cid: videoDetailController.cid.value)),
                      ]
                    ],
                  ))
            ],
          ),
          SizedBox(
              width: isFullScreen.value == true
                  ? 0
                  : (context.width -
                      videowidth -
                      (removeSafeArea
                          ? 0
                          : (MediaQuery.of(context).padding.left +
                              MediaQuery.of(context).padding.right))),
              height: context.height -
                  (removeSafeArea ? 0 : MediaQuery.of(context).padding.top),
              child:
                  // TabBarView(
                  //   physics: const BouncingScrollPhysics(),
                  //   controller: videoDetailController.tabCtr,
                  //   children: <Widget>[
                  //     if (videoDetailController.videoType == SearchType.video)
                  //       const CustomScrollView(
                  //         slivers: [
                  //           RelatedVideoPanel(),
                  //         ],
                  //       ),
                  Obx(
                () => VideoReplyPanel(
                  bvid: videoDetailController.bvid,
                  oid: videoDetailController.oid.value,
                  heroTag: heroTag,
                ),
              )
              //   ],
              // ),
              )
        ],
      );
    });
    Widget childWhenDisabledLandscape = Stack(children: [
      Scaffold(
          resizeToAvoidBottomInset: false,
          key: videoDetailController.scaffoldKey,
          // backgroundColor: Colors.black,
          appBar: removeSafeArea
              ? null
              : AppBar(
                  backgroundColor:
                      showStatusBarBackgroundColor ? null : Colors.black,
                  elevation: 0,
                  toolbarHeight: 0,
                  systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarIconBrightness:
                          Theme.of(context).brightness == Brightness.dark ||
                                  !showStatusBarBackgroundColor
                              ? Brightness.light
                              : Brightness.dark,
                      systemNavigationBarColor: Colors.transparent),
                ),
          body: Container(
              color: Theme.of(context).colorScheme.background,
              child: SafeArea(
                  left: !removeSafeArea && isFullScreen.value != true,
                  right: !removeSafeArea && isFullScreen.value != true,
                  top: !removeSafeArea,
                  bottom: false, //!removeSafeArea,
                  child: childWhenDisabledLandscapeInner)))
    ]);
    Widget childWhenDisabledAlmostSquare = Stack(children: [
      Scaffold(
          resizeToAvoidBottomInset: false,
          key: videoDetailController.scaffoldKey,
          // backgroundColor: Colors.black,
          appBar: removeSafeArea
              ? null
              : AppBar(
                  backgroundColor:
                      showStatusBarBackgroundColor ? null : Colors.black,
                  elevation: 0,
                  toolbarHeight: 0,
                  systemOverlayStyle: SystemUiOverlayStyle(
                      statusBarIconBrightness:
                          Theme.of(context).brightness == Brightness.dark ||
                                  !showStatusBarBackgroundColor
                              ? Brightness.light
                              : Brightness.dark,
                      systemNavigationBarColor: Colors.transparent),
                ),
          body: Container(
              color: Theme.of(context).colorScheme.background,
              child: SafeArea(
                  left: !removeSafeArea && isFullScreen.value != true,
                  right: !removeSafeArea && isFullScreen.value != true,
                  top: !removeSafeArea,
                  bottom: false, //!removeSafeArea,
                  child: childWhenDisabledAlmostSquareInner)))
    ]);
    Widget childWhenEnabled = Obx(
      () => !videoDetailController.autoPlay.value
          ? const SizedBox()
          : PLVideoPlayer(
              controller: plPlayerController!,
              videoIntroController:
                  videoDetailController.videoType == SearchType.video
                      ? videoIntroController
                      : null,
              bangumiIntroController:
                  videoDetailController.videoType == SearchType.media_bangumi
                      ? bangumiIntroController
                      : null,
              headerControl: HeaderControl(
                controller: plPlayerController,
                videoDetailCtr: videoDetailController,
                heroTag: heroTag,
              ),
              danmuWidget: pipNoDanmaku
                  ? null
                  : Obx(
                      () => PlDanmaku(
                        key: Key(
                            videoDetailController.danmakuCid.value.toString()),
                        cid: videoDetailController.danmakuCid.value,
                        playerController: plPlayerController!,
                      ),
                    ),
            ),
    );
    Widget autoChoose(Widget childWhenDisabled) {
      if (Platform.isAndroid) {
        return PiPSwitcher(
          childWhenDisabled: childWhenDisabled,
          childWhenEnabled: childWhenEnabled,
          floating: floating,
        );
      }
      return childWhenDisabled;
    }

    if (!horizontalScreen) {
      return autoChoose(childWhenDisabled);
    }

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      if (!isShowing) {
        return ColoredBox(color: Theme.of(context).colorScheme.background);
      }
      if (constraints.maxWidth > constraints.maxHeight * 1.25) {
//             hideStatusBar();
//             videoDetailController.hiddenReplyReplyPanel();
        return autoChoose(childWhenDisabledLandscape);
      } else if (constraints.maxWidth * (9 / 16) <
          (2 / 5) * constraints.maxHeight) {
        if (!isFullScreen.value) {
          if (!removeSafeArea) showStatusBar();
        }
        return autoChoose(childWhenDisabled);
      } else {
        if (!isFullScreen.value) {
          if (!removeSafeArea) showStatusBar();
        }
        return autoChoose(childWhenDisabledAlmostSquare);
      }
      //
      // final Orientation orientation =
      //     constraints.maxWidth > constraints.maxHeight * 1.25
      //         ? Orientation.landscape
      //         : Orientation.portrait;
      // if (orientation == Orientation.landscape) {
      //   if (!horizontalScreen) {
      //     hideStatusBar();
      //     videoDetailController.hiddenReplyReplyPanel();
      //   }
      // } else {
      //   if (!isFullScreen.value) {
      //     showStatusBar();
      //   }
      // }
      // if (Platform.isAndroid) {
      //   return PiPSwitcher(
      //     childWhenDisabled:
      //         !horizontalScreen || orientation == Orientation.portrait
      //             ? childWhenDisabled
      //             : childWhenDisabledLandscape,
      //     childWhenEnabled: childWhenEnabled,
      //     floating: floating,
      //   );
      // }
      // return !horizontalScreen || orientation == Orientation.portrait
      //     ? childWhenDisabled
      //     : childWhenDisabledLandscape;
    });
  }
}
