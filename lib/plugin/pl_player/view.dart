import 'dart:async';
import 'dart:ui';

import 'package:PiliPalaX/pages/video/detail/introduction/controller.dart';
import 'package:PiliPalaX/utils/id_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:PiliPalaX/plugin/pl_player/controller.dart';
import 'package:PiliPalaX/plugin/pl_player/models/duration.dart';
import 'package:PiliPalaX/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPalaX/plugin/pl_player/utils.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:media_kit_video/media_kit_video_controls/src/controls/methods/video_state.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../common/widgets/audio_video_progress_bar.dart';
import '../../models/video_detail_res.dart';
import '../../pages/bangumi/introduction/controller.dart';
import '../../common/widgets/list_sheet.dart';
import '../../utils/utils.dart';
import 'models/bottom_control_type.dart';
import 'models/bottom_progress_behavior.dart';
import 'widgets/app_bar_ani.dart';
import 'widgets/backward_seek.dart';
import 'widgets/bottom_control.dart';
import 'widgets/common_btn.dart';
import 'widgets/forward_seek.dart';
import 'widgets/play_pause_btn.dart';

class PLVideoPlayer extends StatefulWidget {
  const PLVideoPlayer({
    required this.controller,
    this.videoIntroController,
    this.bangumiIntroController,
    this.headerControl,
    this.bottomControl,
    this.danmuWidget,
    this.bottomList,
    super.key,
  });

  final PlPlayerController controller;
  final VideoIntroController? videoIntroController;
  final BangumiIntroController? bangumiIntroController;
  final PreferredSizeWidget? headerControl;
  final PreferredSizeWidget? bottomControl;
  final Widget? danmuWidget;
  final List<BottomControlType>? bottomList;

  @override
  State<PLVideoPlayer> createState() => _PLVideoPlayerState();
}

class _PLVideoPlayerState extends State<PLVideoPlayer>
    with TickerProviderStateMixin {
  late AnimationController animationController;
  late VideoController videoController;
  late VideoIntroController? videoIntroController;
  late BangumiIntroController? bangumiIntroController;

  final GlobalKey _playerKey = GlobalKey();
  final RxBool _mountSeekBackwardButton = false.obs;
  final RxBool _mountSeekForwardButton = false.obs;
  final RxBool _hideSeekBackwardButton = false.obs;
  final RxBool _hideSeekForwardButton = false.obs;

  final RxDouble _brightnessValue = 0.0.obs;
  final RxBool _brightnessIndicator = false.obs;
  Timer? _brightnessTimer;

  final RxDouble _volumeValue = 0.0.obs;
  final RxBool _volumeIndicator = false.obs;
  Timer? _volumeTimer;

  final RxDouble _distance = 0.0.obs;
  final RxBool _volumeInterceptEventStream = false.obs;

  Box setting = GStrorage.setting;
  late FullScreenMode mode;
  late int defaultBtmProgressBehavior;
  late bool enableQuickDouble;
  late bool fullScreenGestureReverse;

  // 用于记录上一次全屏切换手势触发时间，避免误触
  DateTime? lastFullScreenToggleTime;
  // 记录上一次音量调整值作平均，避免音量调整抖动
  double lastVolume = -1.0;
  // 是否在调整固定进度条
  RxBool draggingFixedProgressBar = false.obs;
  // 阅读器限制
  Timer? _accessibilityDebounce;
  double _lastAnnouncedValue = -1;

  void onDoubleTapSeekBackward() {
    _mountSeekBackwardButton.value = true;
  }

  void onDoubleTapSeekForward() {
    _mountSeekForwardButton.value = true;
  }

  // 双击播放、暂停
  void onDoubleTapCenter() {
    final PlPlayerController _ = widget.controller;
    _.videoPlayerController!.playOrPause();
  }

  void doubleTapFuc(String type) {
    if (!enableQuickDouble) {
      onDoubleTapCenter();
      return;
    }
    switch (type) {
      case 'left':
        // 双击左边区域 👈
        onDoubleTapSeekBackward();
        break;
      case 'center':
        onDoubleTapCenter();
        break;
      case 'right':
        // 双击右边区域 👈
        onDoubleTapSeekForward();
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    videoController = widget.controller.videoController!;
    videoIntroController = widget.videoIntroController;
    bangumiIntroController = widget.bangumiIntroController;
    widget.controller.headerControl = widget.headerControl;
    widget.controller.bottomControl = widget.bottomControl;
    widget.controller.danmuWidget = widget.danmuWidget;
    defaultBtmProgressBehavior = setting.get(SettingBoxKey.btmProgressBehavior,
        defaultValue: BtmProgresBehavior.values.first.code);
    enableQuickDouble =
        setting.get(SettingBoxKey.enableQuickDouble, defaultValue: true);
    fullScreenGestureReverse = setting
        .get(SettingBoxKey.fullScreenGestureReverse, defaultValue: false);
    Future.microtask(() async {
      try {
        FlutterVolumeController.updateShowSystemUI(true);
        _volumeValue.value = (await FlutterVolumeController.getVolume())!;
        FlutterVolumeController.addListener((double value) {
          if (mounted && !_volumeInterceptEventStream.value) {
            _volumeValue.value = value;
          }
        });
      } catch (_) {}
    });

    Future.microtask(() async {
      try {
        _brightnessValue.value = await ScreenBrightness().current;
        ScreenBrightness().onCurrentBrightnessChanged.listen((double value) {
          if (mounted) {
            _brightnessValue.value = value;
          }
        });
      } catch (_) {}
    });
  }

  Future<void> setVolume(double value) async {
    try {
      FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(value);
    } catch (_) {}
    _volumeValue.value = value;
    _volumeIndicator.value = true;
    _volumeInterceptEventStream.value = true;
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _volumeIndicator.value = false;
        _volumeInterceptEventStream.value = false;
      }
    });
  }

  Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightness().setScreenBrightness(value);
    } catch (_) {}
    _brightnessIndicator.value = true;
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _brightnessIndicator.value = false;
      }
    });
    widget.controller.brightness.value = value;
  }

  @override
  void dispose() {
    animationController.dispose();
    FlutterVolumeController.removeListener();
    super.dispose();
  }

  // 动态构建底部控制条
  List<Widget> buildBottomControl() {
    final PlPlayerController _ = widget.controller;
    Map<BottomControlType, Widget> videoProgressWidgets = {
      /// 上一集
      BottomControlType.pre: ComBtn(
        icon: const Icon(
          Icons.skip_previous,
          size: 15,
          color: Colors.white,
        ),
        fuc: () {},
        tooltip: '上一集',
      ),

      /// 播放暂停
      BottomControlType.playOrPause: PlayOrPauseButton(
        controller: _,
      ),

      /// 下一集
      BottomControlType.next: ComBtn(
        icon: const Icon(
          Icons.skip_next,
          size: 15,
          color: Colors.white,
        ),
        fuc: () {},
        tooltip: '下一集',
      ),

      /// 时间进度
      BottomControlType.time: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 播放时间
          Obx(() {
            return Text(
              Utils.timeFormat(_.positionSeconds.value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              semanticsLabel:
                  '已播放${Utils.durationReadFormat(Utils.timeFormat(_.positionSeconds.value))}',
            );
          }),
          // const SizedBox(width: 2),
          // const ExcludeSemantics(
          //   child: Text(
          //     '/',
          //     style: textStyle,
          //   ),
          // ),
          // const SizedBox(width: 2),
          Obx(
            () => Text(
              Utils.timeFormat(_.durationSeconds.value),
              style: const TextStyle(
                color: Color(0xFFD0D0D0),
                fontSize: 10,
                height: 1.4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              semanticsLabel:
                  '共${Utils.durationReadFormat(Utils.timeFormat(_.durationSeconds.value))}',
            ),
          ),
        ],
      ),

      /// 空白占位
      BottomControlType.space: const Spacer(),

      /// 选集
      BottomControlType.episode: Obx(() {
        bool isSeason =
            videoIntroController?.videoDetail.value.ugcSeason != null;
        bool isPage = videoIntroController?.videoDetail.value.pages != null &&
            videoIntroController!.videoDetail.value.pages!.length > 1;
        bool isBangumi = bangumiIntroController?.bangumiDetail.value != null;
        if (!isSeason && !isPage && !isBangumi) {
          return const SizedBox.shrink();
        }
        return SizedBox(
            width: 42,
            height: 30,
            child: Container(
                width: 42,
                height: 30,
                alignment: Alignment.center,
                child: ComBtn(
                  icon: const Icon(
                    Icons.list,
                    size: 22,
                    color: Colors.white,
                  ),
                  tooltip: '选集',
                  fuc: () {
                    int currentCid = widget.controller.cid;
                    String bvid = widget.controller.bvid;
                    final List episodes = [];
                    late Function changeFucCall;
                    if (isSeason) {
                      final List<SectionItem> sections = videoIntroController!
                          .videoDetail.value.ugcSeason!.sections!;
                      for (int i = 0; i < sections.length; i++) {
                        final List<EpisodeItem> episodesList =
                            sections[i].episodes!;
                        episodes.addAll(episodesList);
                      }
                      changeFucCall = videoIntroController!.changeSeasonOrbangu;
                    } else if (isPage) {
                      final List<Part> pages =
                          videoIntroController!.videoDetail.value.pages!;
                      episodes.addAll(pages);
                      changeFucCall = videoIntroController!.changeSeasonOrbangu;
                    } else if (isBangumi) {
                      episodes.addAll(bangumiIntroController!.bangumiDetail.value.episodes!);
                      changeFucCall = bangumiIntroController!.changeSeasonOrbangu;
                    }
                    ListSheet(
                      episodes: episodes,
                      bvid: bvid,
                      aid: IdUtils.bv2av(bvid),
                      currentCid: currentCid,
                      changeFucCall: changeFucCall,
                      context: context,
                    ).buildShowBottomSheet();
                  },
                )));
      }),

      /// 画面比例
      BottomControlType.fit: SizedBox(
        width: 42,
        height: 30,
        child: TextButton(
          onPressed: () => _.toggleVideoFit(),
          style: ButtonStyle(
            padding: MaterialStateProperty.all(EdgeInsets.zero),
          ),
          child: Obx(
            () => Text(
              _.videoFitDEsc.value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),

      /// 字幕
      BottomControlType.subtitle: Obx(
        () => _.vttSubtitles.isEmpty
            ? const SizedBox.shrink()
            : SizedBox(
                width: 42,
                height: 30,
                child: PopupMenuButton<Map<String, String>>(
                  onSelected: (Map<String, String> value) {
                    _.setSubtitle(value);
                  },
                  initialValue: _.vttSubtitles[_.vttSubtitlesIndex.value],
                  color: Colors.black.withOpacity(0.8),
                  itemBuilder: (BuildContext context) {
                    return _.vttSubtitles.map((Map<String, String> subtitle) {
                      return PopupMenuItem<Map<String, String>>(
                        value: subtitle,
                        child: Text(
                          "${subtitle['title']}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    width: 42,
                    height: 30,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.closed_caption_off_outlined,
                      size: 22,
                      color: Colors.white,
                      semanticLabel: '字幕',
                    ),
                  ),
                ),
              ),
      ),

      /// 播放速度
      BottomControlType.speed: SizedBox(
        width: 42,
        height: 30,
        child: PopupMenuButton<double>(
          onSelected: (double value) {
            _.setPlaybackSpeed(value);
          },
          initialValue: _.playbackSpeed,
          color: Colors.black.withOpacity(0.8),
          itemBuilder: (BuildContext context) {
            return _.speedsList.map((double speed) {
              return PopupMenuItem<double>(
                height: 35,
                padding: const EdgeInsets.only(left: 30),
                value: speed,
                child: Text(
                  "${speed}X",
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  semanticsLabel: "$speed倍速",
                ),
              );
            }).toList();
          },
          child: Container(
            width: 42,
            height: 30,
            alignment: Alignment.center,
            child: Obx(() => Text("${_.playbackSpeed}X",
                style: const TextStyle(color: Colors.white, fontSize: 13),
                semanticsLabel: "${_.playbackSpeed}倍速")),
          ),
        ),
      ),

      /// 全屏
      BottomControlType.fullscreen: SizedBox(
        width: 42,
        height: 30,
        child: Obx(() => ComBtn(
              tooltip: _.isFullScreen.value ? '退出全屏' : '全屏',
              icon: Icon(
                _.isFullScreen.value ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 24,
                color: Colors.white,
              ),
              fuc: () => _.triggerFullScreen!(status: !_.isFullScreen.value),
            )),
      ),
    };
    final List<Widget> list = [];
    var userSpecifyItem = widget.bottomList ??
        [
          BottomControlType.playOrPause,
          BottomControlType.time,
          // BottomControlType.pre,
          // BottomControlType.next,
          BottomControlType.space,
          BottomControlType.episode,
          BottomControlType.fit,
          BottomControlType.subtitle,
          BottomControlType.speed,
          BottomControlType.fullscreen,
        ];
    for (var i = 0; i < userSpecifyItem.length; i++) {
      list.add(videoProgressWidgets[userSpecifyItem[i]]!);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final PlPlayerController _ = widget.controller;
    final Color colorTheme = Theme.of(context).colorScheme.primary;
    const TextStyle subTitleStyle = TextStyle(
      height: 1.5,
      fontSize: 20.0,
      letterSpacing: 0.1,
      wordSpacing: 0.1,
      color: Color(0xffffffff),
      fontWeight: FontWeight.normal,
      backgroundColor: Color(0xaa000000),
    );
    const TextStyle textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
    );
    return Stack(
      fit: StackFit.passthrough,
      key: _playerKey,
      children: <Widget>[
        Obx(
          () => Video(
            key: ValueKey('${_.videoFit.value}${_.continuePlayInBackground.value}'),
            controller: videoController,
            controls: NoVideoControls,
            pauseUponEnteringBackgroundMode: !_.continuePlayInBackground.value,
            resumeUponEnteringForegroundMode: true,
            subtitleViewConfiguration: const SubtitleViewConfiguration(
              style: subTitleStyle,
              padding: EdgeInsets.all(24.0),
              textScaleFactor: 1.0,
            ),
            fit: _.videoFit.value,
          ),
        ),

        /// 长按倍速 toast
        Obx(
          () => Align(
            alignment: Alignment.topCenter,
            child: FractionalTranslation(
              translation: const Offset(0.0, 0.3), // 上下偏移量（负数向上偏移）
              child: AnimatedOpacity(
                curve: Curves.easeInOut,
                opacity: _.doubleSpeedStatus.value ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x88000000),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    height: 32.0,
                    width: 70.0,
                    child: Center(
                      child: Obx(() => Text(
                            '${_.enableAutoLongPressSpeed ? _.playbackSpeed * 2 : _.longPressSpeed}倍速中',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          )),
                    )),
              ),
            ),
          ),
        ),

        /// 时间进度 toast
        Obx(
          () => Align(
            alignment: Alignment.topCenter,
            child: FractionalTranslation(
              translation: const Offset(0.0, 1.0), // 上下偏移量（负数向上偏移）
              child: AnimatedOpacity(
                curve: Curves.easeInOut,
                opacity: _.isSliderMoving.value ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: IntrinsicWidth(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x88000000),
                      borderRadius: BorderRadius.circular(64.0),
                    ),
                    height: 34.0,
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Obx(() {
                          return Text(
                            Utils.timeFormat(
                                _.sliderTempPosition.value.inSeconds),
                            style: textStyle,
                          );
                        }),
                        const SizedBox(width: 2),
                        const Text('/', style: textStyle),
                        const SizedBox(width: 2),
                        Obx(
                          () => Text(
                            _.duration.value.inMinutes >= 60
                                ? printDurationWithHours(_.duration.value)
                                : printDuration(_.duration.value),
                            style: textStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        /// 音量🔊 控制条展示
        Obx(
          () => Align(
            child: AnimatedOpacity(
              curve: Curves.easeInOut,
              opacity: _volumeIndicator.value ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x88000000),
                  borderRadius: BorderRadius.circular(64.0),
                ),
                height: 34.0,
                width: 70.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      height: 34.0,
                      width: 28.0,
                      alignment: Alignment.centerRight,
                      child: Icon(
                        _volumeValue.value == 0.0
                            ? Icons.volume_off
                            : _volumeValue.value < 0.5
                                ? Icons.volume_down
                                : Icons.volume_up,
                        color: const Color(0xFFFFFFFF),
                        size: 20.0,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${(_volumeValue.value * 100.0).round()}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.0,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                  ],
                ),
              ),
            ),
          ),
        ),

        /// 亮度🌞 控制条展示
        Obx(
          () => Align(
            child: AnimatedOpacity(
              curve: Curves.easeInOut,
              opacity: _brightnessIndicator.value ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x88000000),
                  borderRadius: BorderRadius.circular(64.0),
                ),
                height: 34.0,
                width: 70.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      height: 30.0,
                      width: 28.0,
                      alignment: Alignment.centerRight,
                      child: Icon(
                        _brightnessValue.value < 1.0 / 3.0
                            ? Icons.brightness_low
                            : _brightnessValue.value < 2.0 / 3.0
                                ? Icons.brightness_medium
                                : Icons.brightness_high,
                        color: const Color(0xFFFFFFFF),
                        size: 18.0,
                      ),
                    ),
                    const SizedBox(width: 2.0),
                    Expanded(
                      child: Text(
                        '${(_brightnessValue.value * 100.0).round()}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.0,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Obx(() {
        //   if (_.buffered.value == Duration.zero) {
        //     return Positioned.fill(
        //       child: Container(
        //         color: Colors.black,
        //         child: Center(
        //           child: Image.asset(
        //             'assets/images/loading.gif',
        //             height: 25,
        //           ),
        //         ),
        //       ),
        //     );
        //   } else {
        //     return Container();
        //   }
        // }),

        /// 弹幕面板
        if (widget.danmuWidget != null)
          Positioned.fill(top: 4, child: widget.danmuWidget!),

        /// 手势
        Positioned.fill(
          left: 16,
          top: 25,
          right: 15,
          bottom: 15,
          child: Semantics(
            label: '双击开关控件',
            child: GestureDetector(
              onTap: () {
                _.controls = !_.showControls.value;
              },
              onDoubleTapDown: (TapDownDetails details) {
                // live模式下禁用 锁定时🔒禁用
                if (_.videoType.value == 'live' || _.controlsLock.value) {
                  return;
                }
                RenderBox renderBox =
                    _playerKey.currentContext!.findRenderObject() as RenderBox;
                final double totalWidth = renderBox.size.width;
                final double tapPosition = details.localPosition.dx;
                final double sectionWidth = totalWidth / 4;
                String type = 'left';
                if (tapPosition < sectionWidth) {
                  type = 'left';
                } else if (tapPosition < sectionWidth * 3) {
                  type = 'center';
                } else {
                  type = 'right';
                }
                doubleTapFuc(type);
              },
              onLongPressStart: (LongPressStartDetails detail) {
                feedBack();
                _.setDoubleSpeedStatus(true);
              },
              onLongPressEnd: (LongPressEndDetails details) {
                _.setDoubleSpeedStatus(false);
              },

              /// 水平位置 快进 live模式下禁用
              onHorizontalDragUpdate: (DragUpdateDetails details) {
                // live模式下禁用 锁定时🔒禁用
                if (_.videoType.value == 'live' || _.controlsLock.value) {
                  return;
                }
                // final double tapPosition = details.localPosition.dx;
                final int curSliderPosition =
                    _.sliderPosition.value.inMilliseconds;
                RenderBox renderBox =
                    _playerKey.currentContext!.findRenderObject() as RenderBox;
                final double scale = 90000 / renderBox.size.width;
                final Duration pos = Duration(
                    milliseconds:
                        curSliderPosition + (details.delta.dx * scale).round());
                final Duration result =
                    pos.clamp(Duration.zero, _.duration.value);
                _.onUpdatedSliderProgress(result);
                _.onChangedSliderStart();
                // _initTapPositoin = tapPosition;
              },
              onHorizontalDragEnd: (DragEndDetails details) {
                if (_.videoType.value == 'live' || _.controlsLock.value) {
                  return;
                }
                _.onChangedSliderEnd();
                _.seekTo(_.sliderPosition.value, type: 'slider');
              },
              // 垂直方向 音量/亮度调节
              onVerticalDragUpdate: (DragUpdateDetails details) async {
                RenderBox renderBox =
                    _playerKey.currentContext!.findRenderObject() as RenderBox;

                /// 锁定时禁用
                if (_.controlsLock.value) {
                  return;
                }
                final double totalWidth = renderBox.size.width;
                final double tapPosition = details.localPosition.dx;
                final double sectionWidth = totalWidth / 4;
                final double delta = details.delta.dy;
                if (lastFullScreenToggleTime != null &&
                    DateTime.now().difference(lastFullScreenToggleTime!) <
                        const Duration(milliseconds: 500)) {
                  return;
                }
                if (tapPosition < sectionWidth) {
                  // 左边区域 👈
                  final double level = renderBox.size.height * 3;
                  final double brightness =
                      _brightnessValue.value - delta / level;
                  final double result = brightness.clamp(0.0, 1.0);
                  setBrightness(result);
                } else if (tapPosition < sectionWidth * 3) {
                  // 全屏
                  final double dy = details.delta.dy;
                  const double threshold = 7.0; // 滑动阈值
                  void fullScreenTrigger(bool status) async {
                    lastFullScreenToggleTime = DateTime.now();
                    await widget.controller.triggerFullScreen(status: status);
                  }

                  if (dy > _distance.value && dy > threshold) {
                    // 下滑退出全屏/进入全屏
                    if (_.isFullScreen.value ^ fullScreenGestureReverse) {
                      fullScreenTrigger(fullScreenGestureReverse);
                    }
                    _distance.value = 0.0;
                  } else if (dy < _distance.value && dy < -threshold) {
                    // 上划进入全屏/退出全屏
                    if (!_.isFullScreen.value ^ fullScreenGestureReverse) {
                      fullScreenTrigger(!fullScreenGestureReverse);
                    }
                    _distance.value = 0.0;
                  }
                  _distance.value = dy;
                } else {
                  // 右边区域 👈
                  final double level = renderBox.size.height * 0.5;
                  if (lastVolume < 0) {
                    lastVolume = _volumeValue.value;
                  }
                  final double volume =
                      (lastVolume + _volumeValue.value - delta / level) / 2;
                  final double result = volume.clamp(0.0, 1.0);
                  lastVolume = result;
                  setVolume(result);
                }
              },
              onVerticalDragEnd: (DragEndDetails details) {},
            ),
          ),
        ),

        // 头部、底部控制条
        SafeArea(
          top: false,
          bottom: false,
          child: Obx(
            () => Column(
              children: [
                if (widget.headerControl != null || _.headerControl != null)
                  ClipRect(
                    child: AppBarAni(
                      controller: animationController,
                      visible: !_.controlsLock.value && _.showControls.value,
                      position: 'top',
                      child: widget.headerControl ?? _.headerControl!,
                    ),
                  ),
                const Spacer(),
                ClipRect(
                  child: AppBarAni(
                    controller: animationController,
                    visible: !_.controlsLock.value && _.showControls.value,
                    position: 'bottom',
                    child: widget.bottomControl ??
                        BottomControl(
                          controller: widget.controller,
                          buildBottomControl: buildBottomControl(),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),

        /// 进度条 live模式下禁用

        Obx(
          () {
            final int value = _.sliderPositionSeconds.value;
            final int max = _.durationSeconds.value;
            final int buffer = _.bufferedSeconds.value;
            if (_.showControls.value) {
              return Container();
            }
            if (defaultBtmProgressBehavior ==
                BtmProgresBehavior.alwaysHide.code) {
              return const SizedBox();
            }
            if (defaultBtmProgressBehavior ==
                    BtmProgresBehavior.onlyShowFullScreen.code &&
                !_.isFullScreen.value) {
              return const SizedBox();
            } else if (defaultBtmProgressBehavior ==
                    BtmProgresBehavior.onlyHideFullScreen.code &&
                _.isFullScreen.value) {
              return const SizedBox();
            }

            if (_.videoType.value == 'live') {
              return Container();
            }
            if (value > max || max <= 0) {
              return const SizedBox();
            }
            return Positioned(
                bottom: -1,
                left: 0,
                right: 0,
                child: Semantics(
                  // label: '${(value / max * 100).round()}%',
                  value: '${(value / max * 100).round()}%',
                  // enabled: false,
                  child: ProgressBar(
                    progress: Duration(seconds: value),
                    buffered: Duration(seconds: buffer),
                    total: Duration(seconds: max),
                    progressBarColor: colorTheme,
                    baseBarColor: Colors.white.withOpacity(0.2),
                    bufferedBarColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    timeLabelLocation: TimeLabelLocation.none,
                    thumbColor: colorTheme,
                    barHeight: 3.5,
                    thumbRadius: draggingFixedProgressBar.value ? 7 : 2.5,
                    // onDragStart: (duration) {
                    //   draggingFixedProgressBar.value = true;
                    //   feedBack();
                    //   _.onChangedSliderStart();
                    // },
                    // onDragUpdate: (duration) {
                    //   double newProgress = duration.timeStamp.inSeconds / max;
                    //   if ((newProgress - _lastAnnouncedValue).abs() > 0.02) {
                    //     _accessibilityDebounce?.cancel();
                    //     _accessibilityDebounce =
                    //         Timer(const Duration(milliseconds: 200), () {
                    //       SemanticsService.announce(
                    //           "${(newProgress * 100).round()}%",
                    //           TextDirection.ltr);
                    //       _lastAnnouncedValue = newProgress;
                    //     });
                    //   }
                    //   _.onUpdatedSliderProgress(duration.timeStamp);
                    // },
                    // onSeek: (duration) {
                    //   draggingFixedProgressBar.value = false;
                    //   _.onChangedSliderEnd();
                    //   _.onChangedSlider(duration.inSeconds.toDouble());
                    //   _.seekTo(Duration(seconds: duration.inSeconds),
                    //       type: 'slider');
                    //   SemanticsService.announce(
                    //       "${(duration.inSeconds / max * 100).round()}%",
                    //       TextDirection.ltr);
                    // },
                  ),
                  // SlideTransition(
                  //     position: Tween<Offset>(
                  //       begin: Offset.zero,
                  //       end: const Offset(0, -1),
                  //     ).animate(CurvedAnimation(
                  //       parent: animationController,
                  //       curve: Curves.easeInOut,
                  //     )),
                  //     child: ),
                ));
          },
        ),

        // 锁
        Obx(
          () => Visibility(
            visible: _.videoType.value != 'live',
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionalTranslation(
                translation: const Offset(1, 0.0),
                child: Visibility(
                  visible: _.showControls.value,
                  child: ComBtn(
                    tooltip: _.controlsLock.value ? '解锁' : '锁定',
                    icon: Icon(
                      _.controlsLock.value
                          ? FontAwesomeIcons.lock
                          : FontAwesomeIcons.lockOpen,
                      size: 15,
                      color: Colors.white,
                    ),
                    fuc: () => _.onLockControl(!_.controlsLock.value),
                  ),
                ),
              ),
            ),
          ),
        ),
        //
        Obx(() {
          if (_.dataStatus.loading || _.isBuffering.value) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.black26, Colors.transparent],
                  ),
                ),
                child: Image.asset(
                  'assets/images/loading.gif',
                  height: 25,
                  semanticLabel: "加载中",
                ),
              ),
            );
          } else {
            return const SizedBox();
          }
        }),

        /// 点击 快进/快退
        Obx(
          () => Visibility(
            visible:
                _mountSeekBackwardButton.value || _mountSeekForwardButton.value,
            child: Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: _mountSeekBackwardButton.value
                        ? TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: _hideSeekBackwardButton.value ? 0.0 : 1.0,
                            ),
                            duration: const Duration(milliseconds: 500),
                            builder: (BuildContext context, double value,
                                    Widget? child) =>
                                Opacity(
                              opacity: value,
                              child: child,
                            ),
                            onEnd: () {
                              if (_hideSeekBackwardButton.value) {
                                _hideSeekBackwardButton.value = false;
                                _mountSeekBackwardButton.value = false;
                              }
                            },
                            child: BackwardSeekIndicator(
                              onChanged: (Duration value) => {},
                              onSubmitted: (Duration value) {
                                _hideSeekBackwardButton.value = true;
                                _mountSeekBackwardButton.value = false;
                                final Player player =
                                    widget.controller.videoPlayerController!;
                                Duration result = player.state.position - value;
                                result = result.clamp(
                                  Duration.zero,
                                  player.state.duration,
                                );
                                player.seek(result);
                                widget.controller.play();
                              },
                            ),
                          )
                        : const SizedBox(),
                  ),
                  const Spacer(),
                  // Expanded(
                  //   child: SizedBox(
                  //     width: context.width / 4,
                  //   ),
                  // ),
                  Expanded(
                    child: _mountSeekForwardButton.value
                        ? TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: _hideSeekForwardButton.value ? 0.0 : 1.0,
                            ),
                            duration: const Duration(milliseconds: 500),
                            builder: (BuildContext context, double value,
                                    Widget? child) =>
                                Opacity(
                              opacity: value,
                              child: child,
                            ),
                            onEnd: () {
                              if (_hideSeekForwardButton.value) {
                                _hideSeekForwardButton.value = false;
                                _mountSeekForwardButton.value = false;
                              }
                            },
                            child: ForwardSeekIndicator(
                              onChanged: (Duration value) => {},
                              onSubmitted: (Duration value) {
                                _hideSeekForwardButton.value = true;
                                _mountSeekForwardButton.value = false;
                                final Player player =
                                    widget.controller.videoPlayerController!;
                                Duration result = player.state.position + value;
                                result = result.clamp(
                                  Duration.zero,
                                  player.state.duration,
                                );
                                player.seek(result);
                                widget.controller.play();
                              },
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
