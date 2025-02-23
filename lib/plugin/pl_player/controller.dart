// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:fl_pip/fl_pip.dart';
import 'package:flutter/material.dart';
// import 'package:android_window/main.dart' as android_window;
// import 'android_window.dart';
import 'package:flutter_floating/floating/assist/floating_slide_type.dart';
import 'package:flutter_floating/floating/floating.dart';
import 'package:flutter_floating/floating/listener/event_listener.dart';
import 'package:flutter_floating/floating/manager/floating_manager.dart';
import 'package:flutter_floating/floating_increment.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:PiliPalaX/http/video.dart';
import 'package:PiliPalaX/pages/mine/controller.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPalaX/services/service_locator.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';
// import 'package:screen_brightness/screen_brightness.dart';
import 'package:universal_platform/universal_platform.dart';
import '../../models/video/play/subtitle.dart';
import '../../pages/danmaku/controller.dart';
import '../../pages/video/controller.dart';
import '../../pages/video/introduction/bangumi/controller.dart';
import '../../pages/video/introduction/detail/controller.dart';
// import '../../pages/video/controller.dart';
// import 'package:wakelock_plus/wakelock_plus.dart';

Box videoStorage = GStorage.video;
Box setting = GStorage.setting;
Box onlineCache = GStorage.onlineCache;

class PlPlayerController {
  static Player? _videoPlayerController;
  VideoController? _videoController;

  // 添加一个私有静态变量来保存实例
  static PlPlayerController? _instance;

  // 流事件  监听播放状态变化
  StreamSubscription? _playerEventSubs;

  /// [playerStatus] has a [status] observable
  final PlPlayerStatus playerStatus = PlPlayerStatus();

  ///
  final PlPlayerDataStatus dataStatus = PlPlayerDataStatus();

  // bool controlsEnabled = false;

  /// 响应数据
  /// 带有Seconds的变量只在秒数更新时更新，以避免频繁触发重绘
  // 播放位置
  final Rx<Duration> _position = Rx(Duration.zero);
  final RxInt positionSeconds = 0.obs;
  final Rx<Duration> _sliderPosition = Rx(Duration.zero);
  final RxInt sliderPositionSeconds = 0.obs;
  // 展示使用
  final Rx<Duration> _sliderTempPosition = Rx(Duration.zero);
  final Rx<Duration> _duration = Rx(Duration.zero);
  final RxInt durationSeconds = 0.obs;
  final Rx<Duration> _buffered = Rx(Duration.zero);
  final Rx<String> _playerLog = Rx("");
  final RxInt bufferedSeconds = 0.obs;

  final Rx<int> _playerCount = Rx(0);

  final Rx<double> _playbackSpeed = 1.0.obs;
  final Rx<double> _longPressSpeed = 2.0.obs;
  final Rx<double> _currentVolume = 1.0.obs;
  final Rx<double> _currentBrightness = 0.0.obs;

  final Rx<bool> _mute = false.obs;
  final Rx<bool> _showControls = false.obs;
  final Rx<bool> _showVolumeStatus = false.obs;
  final Rx<bool> _showBrightnessStatus = false.obs;
  final RxDouble _doubleSpeedStatus = 0.0.obs;
  final Rx<bool> _controlsLock = false.obs;
  final Rx<bool> _isFullScreen = false.obs;
  // 默认投稿视频格式
  static Rx<String> _videoType = 'archive'.obs;

  final Rx<String> _direction = 'horizontal'.obs;

  final Rx<BoxFit> _videoFit = Rx(videoFitType.first['attr']);
  final Rx<String> _videoFitDesc = Rx(videoFitType.first['desc']);
  StreamSubscription<DataStatus>? _dataListenerForVideoFit;
  StreamSubscription<DataStatus>? _dataListenerForEnterFullScreen;
  StreamSubscription<PlayerStatus>? _playerListenerForEnterPip;

  /// 后台播放
  Rx<bool> _continuePlayInBackground = false.obs;

  Rx<bool> _onlyPlayAudio = false.obs;

  Rx<bool> _flipX = false.obs;

  ///
  // ignore: prefer_final_fields
  Rx<bool> _isSliderMoving = false.obs;
  PlaylistMode _looping = PlaylistMode.none;
  bool _autoPlay = false;
  final bool _listenersInitialized = false;

  // 记录历史记录
  String _bvid = '';
  int _cid = 0;
  int _heartDuration = 0;
  bool _enableHeart = true;

  late DataSource dataSource;
  final RxList<Map<String, String>> _vttSubtitles = <Map<String, String>>[].obs;
  final RxInt _vttSubtitlesIndex = 0.obs;

  final RxDouble subtitleFontSize = 60.0.obs;
  final RxDouble subtitleBottomPadding = 24.0.obs;

  late Rx<TextStyle> subtitleStyle;

  Timer? _timer;
  Timer? _timerForSeek;
  Timer? _timerForVolume;
  Timer? _timerForShowingVolume;
  Timer? _timerForGettingVolume;
  Timer? timerForTrackingMouse;

  // final Durations durations;

  static List<Map<String, dynamic>> videoFitType = [
    {'attr': BoxFit.contain, 'desc': '自动', 'toast': '缩放至播放器尺寸，保留黑边'},
    {'attr': BoxFit.cover, 'desc': '裁剪', 'toast': '缩放至填满播放器，裁剪超出部分'},
    {'attr': BoxFit.fill, 'desc': '拉伸', 'toast': '拉伸至播放器尺寸，将产生变形（竖屏改为自动）'},
    {'attr': BoxFit.none, 'desc': '原始', 'toast': '不缩放，以视频原始尺寸显示'},
    {'attr': BoxFit.fitHeight, 'desc': '等高', 'toast': '缩放至撑满播放器高度'},
    {'attr': BoxFit.fitWidth, 'desc': '等宽', 'toast': '缩放至撑满播放器宽度'},
    {'attr': BoxFit.scaleDown, 'desc': '限制', 'toast': '仅超出时缩小至播放器尺寸'},
  ];

  PreferredSizeWidget? headerControl;
  PreferredSizeWidget? bottomControl;
  Widget? danmuWidget;

  String get bvid => _bvid;
  int get cid => _cid;

  /// 数据加载监听
  Stream<DataStatus> get onDataStatusChanged => dataStatus.status.stream;

  /// 播放状态监听
  Stream<PlayerStatus> get onPlayerStatusChanged => playerStatus.status.stream;

  /// 视频时长
  Rx<Duration> get duration => _duration;
  Stream<Duration> get onDurationChanged => _duration.stream;

  /// 视频当前播放位置
  Rx<Duration> get position => _position;
  Stream<Duration> get onPositionChanged => _position.stream;

  /// 视频播放速度
  double get playbackSpeed => _playbackSpeed.value;

  // 长按倍速
  double get longPressSpeed => _longPressSpeed.value;

  /// 视频缓冲
  Rx<Duration> get buffered => _buffered;
  Stream<Duration> get onBufferedChanged => _buffered.stream;

  /// 视频日志
  Rx<String> get playerLog => _playerLog;

  // 视频静音
  Rx<bool> get mute => _mute;
  Stream<bool> get onMuteChanged => _mute.stream;

  // 视频字幕
  RxList<Map<String, String>> get vttSubtitles => _vttSubtitles;
  RxInt get vttSubtitlesIndex => _vttSubtitlesIndex;

  /// [videoPlayerController] instance of Player
  Player? get videoPlayerController => _videoPlayerController;

  /// [videoController] instance of Player
  VideoController? get videoController => _videoController;

  Rx<bool> get isSliderMoving => _isSliderMoving;

  /// 进度条位置及监听
  Rx<Duration> get sliderPosition => _sliderPosition;
  Stream<Duration> get onSliderPositionChanged => _sliderPosition.stream;

  Rx<Duration> get sliderTempPosition => _sliderTempPosition;
  // Stream<Duration> get onSliderPositionChanged => _sliderPosition.stream;

  /// 是否展示控制条及监听
  Rx<bool> get showControls => _showControls;
  Stream<bool> get onShowControlsChanged => _showControls.stream;

  /// 音量控制条展示/隐藏
  Rx<bool> get showVolumeStatus => _showVolumeStatus;
  Stream<bool> get onShowVolumeStatusChanged => _showVolumeStatus.stream;

  /// 亮度控制条展示/隐藏
  Rx<bool> get showBrightnessStatus => _showBrightnessStatus;
  Stream<bool> get onShowBrightnessStatusChanged =>
      _showBrightnessStatus.stream;

  /// 音量控制条
  Rx<double> get volume => _currentVolume;
  Stream<double> get onVolumeChanged => _currentVolume.stream;

  /// 亮度控制条
  Rx<double> get brightness => _currentBrightness;
  Stream<double> get onBrightnessChanged => _currentBrightness.stream;

  /// 是否循环
  PlaylistMode get looping => _looping;

  /// 是否自动播放
  bool get autoplay => _autoPlay;

  /// 视频比例
  Rx<BoxFit> get videoFit => _videoFit;
  Rx<String> get videoFitDEsc => _videoFitDesc;

  /// 后台播放
  Rx<bool> get continuePlayInBackground => _continuePlayInBackground;

  /// 听视频
  Rx<bool> get onlyPlayAudio => _onlyPlayAudio;

  /// 镜像
  Rx<bool> get flipX => _flipX;

  /// 长按倍速值（0为非长按倍速）
  RxDouble get doubleSpeedStatus => _doubleSpeedStatus;

  Rx<bool> isBuffering = true.obs;

  /// 屏幕锁 为true时，关闭控制栏
  Rx<bool> get controlsLock => _controlsLock;

  /// 全屏状态
  Rx<bool> get isFullScreen => _isFullScreen;

  /// 全屏方向
  Rx<String> get direction => _direction;

  // Rx<int> get playerCount => _playerCount;

  ///
  Rx<String> get videoType => _videoType;

  /// 弹幕开关
  Rx<bool> isOpenDanmu = false.obs;
  // 关联弹幕控制器
  DanmakuController? danmakuController;
  // 弹幕相关配置
  late List blockTypes;
  late double showArea;
  late double opacityVal;
  late double fontSizeVal;
  late double strokeWidth;
  late int fontWeight;
  late int danmakuDurationVal;
  late bool massiveMode;
  late List<double> speedsList;
  // int? defaultDuration;
  late bool enableAutoLongPressSpeed;
  late bool enableLongPressSpeedIncrease;
  late bool enableLongShowControl;
  late bool horizontalScreen;

  // 播放顺序相关
  PlayRepeat playRepeat = PlayRepeat.pause;

  List<StreamSubscription> subscriptions = [];

  void updateSliderPositionSecond() {
    int newSecond =
        (_sliderPosition.value.inMicroseconds / Duration.microsecondsPerSecond)
            .ceil();
    if (sliderPositionSeconds.value != newSecond) {
      sliderPositionSeconds.value = newSecond;
    }
  }

  void updatePositionSecond() {
    int newSecond =
        (_position.value.inMicroseconds / Duration.microsecondsPerSecond)
            .ceil();
    if (positionSeconds.value != newSecond) {
      positionSeconds.value = newSecond;
    }
  }

  void updateDurationSecond() {
    int newSecond =
        (_duration.value.inMicroseconds / Duration.microsecondsPerSecond)
            .ceil();
    if (durationSeconds.value != newSecond) {
      durationSeconds.value = newSecond;
    }
  }

  void updateBufferedSecond() {
    int newSecond =
        (_buffered.value.inMicroseconds / Duration.microsecondsPerSecond)
            .ceil();
    if (bufferedSeconds.value != newSecond) {
      bufferedSeconds.value = newSecond;
    }
  }

  static bool instanceExists() {
    return _instance != null;
  }

  static Future<void> playIfExists(
      {bool repeat = false, bool hideControls = true}) async {
    await _instance?.play(repeat: repeat, hideControls: hideControls);
  }

  static PlayerStatus? getPlayerStatusIfExists() {
    return _instance?.playerStatus.status.value;
  }

  static Future<void> pauseIfExists(
      {bool notify = true, bool isInterrupt = false}) async {
    if (_instance?.playerStatus.status.value == PlayerStatus.playing) {
      await _instance?.pause(notify: notify, isInterrupt: isInterrupt);
    }
  }

  static Future<void> seekToIfExists(Duration position, {type = 'seek'}) async {
    await _instance?.seekTo(position, type: type);
  }

  static double? getVolumeIfExists() {
    return _instance?.volume.value;
  }

  static Future<void> setVolumeIfExists(double volumeNew,
      {bool videoPlayerVolume = false}) async {
    await _instance?.setVolume(volumeNew, videoPlayerVolume: videoPlayerVolume);
  }

  static void updateSettingsIfExist() {
    _instance?.updateSettings();
  }

  void updateSettings() {
    isOpenDanmu.value =
        setting.get(SettingBoxKey.enableShowDanmaku, defaultValue: true);
    blockTypes = setting.get(SettingBoxKey.danmakuBlockType, defaultValue: []);
    showArea = setting
        .get(SettingBoxKey.danmakuShowArea, defaultValue: 0.5)
        .toDouble();
    // 不透明度
    opacityVal =
        setting.get(SettingBoxKey.danmakuOpacity, defaultValue: 1.0).toDouble();
    // 字体大小
    fontSizeVal = setting
        .get(SettingBoxKey.danmakuFontScale, defaultValue: 1.0)
        .toDouble();
    // 弹幕时间
    danmakuDurationVal =
        setting.get(SettingBoxKey.danmakuDuration, defaultValue: 7.29).round();
    // 描边粗细
    strokeWidth =
        setting.get(SettingBoxKey.strokeWidth, defaultValue: 1.5).toDouble();
    // 弹幕字体粗细
    fontWeight = setting.get(SettingBoxKey.fontWeight, defaultValue: 5).round();
    // 弹幕海量模式
    massiveMode =
        setting.get(SettingBoxKey.danmakuMassiveMode, defaultValue: false);
    playRepeat = PlayRepeat.values.toList().firstWhere(
          (e) =>
              e.value ==
              videoStorage.get(VideoBoxKey.playRepeat,
                  defaultValue: PlayRepeat.pause.value),
        );
    _playbackSpeed.value = videoStorage
        .get(VideoBoxKey.playSpeedDefault, defaultValue: 1.0)
        .toDouble();
    enableAutoLongPressSpeed = setting
        .get(SettingBoxKey.enableAutoLongPressSpeed, defaultValue: false);
    enableLongPressSpeedIncrease = setting
        .get(SettingBoxKey.enableLongPressSpeedIncrease, defaultValue: false);
    if (!enableAutoLongPressSpeed) {
      _longPressSpeed.value = videoStorage
          .get(VideoBoxKey.longPressSpeedDefault, defaultValue: 3.0)
          .toDouble();
    }
    // 后台播放
    _continuePlayInBackground.value = setting
        .get(SettingBoxKey.continuePlayInBackground, defaultValue: false);
    enableLongShowControl =
        setting.get(SettingBoxKey.enableLongShowControl, defaultValue: false);
    horizontalScreen =
        setting.get(SettingBoxKey.horizontalScreen, defaultValue: false);
    subtitleFontSize.value = videoStorage
        .get(VideoBoxKey.subtitleFontSize, defaultValue: 60.0)
        .toDouble();
    subtitleStyle = TextStyle(
      height: 1.3,
      fontSize: subtitleFontSize.value,
      letterSpacing: 0.1,
      wordSpacing: 0.1,
      color: const Color(0xffffffff),
      fontWeight: FontWeight.normal,
      backgroundColor: const Color(0xaa000000),
    ).obs;
    subtitleBottomPadding.value = videoStorage
        .get(VideoBoxKey.subtitleBottomPadding, defaultValue: 24.0)
        .toDouble();

    List<double> defaultList = <double>[0.5, 0.75, 1.25, 1.5, 1.75, 3.0];
    speedsList = List<double>.from(videoStorage
        .get(VideoBoxKey.customSpeedsList, defaultValue: defaultList)
        .map((e) => e.toDouble()));
    for (final PlaySpeed i in PlaySpeed.values) {
      speedsList.add(i.value);
    }
    speedsList.sort();
  }

  // 添加一个私有构造函数
  PlPlayerController._() {
    _videoType = videoType;
    updateSettings();
    // _playerEventSubs = onPlayerStatusChanged.listen((PlayerStatus status) {
    //   if (status == PlayerStatus.playing) {
    //     WakelockPlus.enable();
    //   } else {
    //     WakelockPlus.disable();
    //   }
    // });
    enableAutoPip();
  }

  void enableAutoPip() async {
    if (!GStorage.setting.get(SettingBoxKey.autoPiP, defaultValue: false)) {
      return;
    }
    if (!await FlPiP().isAvailable) return;
    _playerListenerForEnterPip =
        onPlayerStatusChanged.listen((PlayerStatus status) async {
      if (status != PlayerStatus.playing) {
        // bool isActive = (await FlPiP().isActive)?.status == PiPStatus.enabled;
        // if (isActive) return;
        FlPiP().setEnableWhenBackground(false);
        print('disable pip EnableWhenBackground');
        return;
      }
      print('enable pip');
      FlPiP().enable(
        ios: FlPiPiOSConfig(
            enabledWhenBackground: true,
            videoPath: dataSource.videoSource!,
            audioPath: dataSource.audioSource!,
            packageName: 'PiliPalaX'),
        android: FlPiPAndroidConfig(
          enabledWhenBackground: true,
          aspectRatio: Rational(
            direction.value == 'vertical' ? 9 : 16,
            direction.value == 'horizontal' ? 9 : 16,
          ),
        ),
      );
      print('enabled pip');
    });
  }

  // 获取实例 传参
  static PlPlayerController getInstance({
    String videoType = 'archive',
  }) {
    // 如果实例尚未创建，则创建一个新实例
    _instance ??= PlPlayerController._();
    // print('getInstance');
    // print(StackTrace.current);
    // _instance!._playerCount.value += 1;
    // print("_playerCount");
    // print(_instance!._playerCount.value);
    _videoType.value = videoType;
    return _instance!;
  }

  // 初始化资源
  Future<void> setDataSource(
    DataSource dataSource, {
    bool autoplay = true,
    // 默认不循环
    PlaylistMode looping = PlaylistMode.none,
    // 初始化播放位置
    Duration seekTo = Duration.zero,
    // 初始化播放速度
    double speed = 1.0,
    // 硬件加速
    bool enableHA = true,
    String? hwdec,
    double? width,
    double? height,
    Duration? duration,
    // 方向
    String? direction,
    // 记录历史记录
    String bvid = '',
    int cid = 0,
    // 历史记录开关
    bool enableHeart = true,
  }) async {
    try {
      // if (playerStatus.status.value == PlayerStatus.disabled) return;

      this.dataSource = dataSource;
      _autoPlay = autoplay;
      _looping = looping;
      // 初始化视频倍速
      // _playbackSpeed.value = speed;
      // 初始化数据加载状态
      dataStatus.status.value = DataStatus.loading;
      // 初始化全屏方向
      _direction.value = direction ?? 'horizontal';
      _bvid = bvid;
      _cid = cid;
      _enableHeart = enableHeart;

      if (_videoPlayerController != null &&
          _videoPlayerController!.state.playing) {
        await pause(notify: false);
      }

      // if (_playerCount.value == 0) {
      //   return;
      // }
      // 配置Player 音轨、字幕等等
      _videoPlayerController = await _createVideoController(
          dataSource, _looping, enableHA, hwdec, width, height, seekTo);
      // 获取视频时长 00:00
      _duration.value = duration ?? _videoPlayerController!.state.duration;
      updateDurationSecond();
      // 数据加载完成
      dataStatus.status.value = DataStatus.loaded;

      // listen the video player events
      if (!_listenersInitialized) {
        startListeners();
      }
      await _initializePlayer();
      if (videoType.value != 'live' && _cid != 0) {
        refreshVideoMetaInfo().then((_) {
          chooseSubtitle();
        });
      }
    } catch (err, stackTrace) {
      dataStatus.status.value = DataStatus.error;
      debugPrint(stackTrace.toString());
      print('plPlayer err:  $err');
    }
  }

  // 配置播放器
  Future<Player> _createVideoController(
    DataSource dataSource,
    PlaylistMode looping,
    bool enableHA,
    String? hwdec,
    double? width,
    double? height,
    Duration? seekTo,
  ) async {
    // 每次配置时先移除监听
    removeListeners();
    isBuffering.value = false;
    buffered.value = Duration.zero;
    _heartDuration = 0;
    _position.value = Duration.zero;
    // 初始化时清空弹幕，防止上次重叠
    danmakuController?.clear();
    int bufferSize =
        setting.get(SettingBoxKey.expandBuffer, defaultValue: false)
            ? (videoType.value == 'live' ? 64 * 1024 * 1024 : 32 * 1024 * 1024)
            : (videoType.value == 'live' ? 16 * 1024 * 1024 : 4 * 1024 * 1024);
    Player player = _videoPlayerController ??
        Player(
          configuration: PlayerConfiguration(
              // 默认缓冲 4M 大小
              bufferSize: bufferSize,
              logLevel: MPVLogLevel.v),
        );
    var pp = player.platform as NativePlayer;
    // 解除倍速限制
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    //  音量不一致
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      String ao = setting.get(SettingBoxKey.useOpenSLES, defaultValue: false)
          ? "opensles,audiotrack"
          : "audiotrack,opensles";
      await pp.setProperty("ao", ao);
    }
    // video-sync=display-resample
    await pp.setProperty("video-sync",
        setting.get(SettingBoxKey.videoSync, defaultValue: 'display-resample'));
    // await pp.setProperty('vf', 'rotate=90');
    await pp.setProperty('force-seekable', 'yes');
    // await pp.setProperty("video-rotate", "no");
    // await pp.setProperty("video-zoom","0");
    // await pp.setProperty("vf", "tblend=c0_mode=difference,eq=contrast=2");
    // await pp.setProperty("vf", "scale")
    // // vo=gpu-next & gpu-context=android & gpu-api=opengl
    // await pp.setProperty("vo", "gpu-next");
    // await pp.setProperty("gpu-context", "android");
    // await pp.setProperty("gpu-api", "opengl");
    await player.setAudioTrack(
      AudioTrack.auto(),
    );
    // 音轨
    if (dataSource.audioSource?.isNotEmpty ?? false) {
      await pp.setProperty(
        'audio-files',
        UniversalPlatform.isWindows
            ? dataSource.audioSource!.replaceAll(';', '\\;')
            : dataSource.audioSource!.replaceAll(':', '\\:'),
      );
    } else {
      await pp.setProperty(
        'audio-files',
        '',
      );
    }

    // 字幕
    if (dataSource.subFiles != '' && dataSource.subFiles != null) {
      await pp.setProperty(
        'sub-files',
        UniversalPlatform.isWindows
            ? dataSource.subFiles!.replaceAll(';', '\\;')
            : dataSource.subFiles!.replaceAll(':', '\\:'),
      );
      await pp.setProperty("subs-with-matching-audio", "no");
      await pp.setProperty("sub-forced-only", "yes");
      await pp.setProperty("blend-subtitles", "video");
    }

    _videoController = _videoController ??
        VideoController(
          player,
          configuration: VideoControllerConfiguration(
            enableHardwareAcceleration: enableHA,
            androidAttachSurfaceAfterVideoParameters: false,
            hwdec: enableHA ? hwdec : null,
          ),
        );

    player.setPlaylistMode(looping);
    if (dataSource.type == DataSourceType.asset) {
      final assetUrl = dataSource.videoSource!.startsWith("asset://")
          ? dataSource.videoSource!
          : "asset://${dataSource.videoSource!}";
      await player.open(
        Media(assetUrl, httpHeaders: dataSource.httpHeaders, start: seekTo),
        play: false,
      );
    } else {
      await player.open(
        Media(dataSource.videoSource!,
            httpHeaders: dataSource.httpHeaders, start: seekTo),
        play: false,
      );
    }
    // 音轨
    // player.setAudioTrack(
    //   AudioTrack.uri(dataSource.audioSource!),
    // );

    return player;
  }

  Future<bool> refreshPlayer() async {
    Duration currentPos = _position.value;
    if (_videoPlayerController == null) {
      SmartDialog.showToast('视频播放器为空，请重新进入本页面');
      return false;
    }
    if (dataSource.videoSource?.isEmpty ?? true) {
      SmartDialog.showToast('视频源为空，请重新进入本页面');
      return false;
    }
    if (dataSource.audioSource?.isEmpty ?? true) {
      SmartDialog.showToast('音频源为空');
    } else {
      await (_videoPlayerController!.platform as NativePlayer).setProperty(
        'audio-files',
        UniversalPlatform.isWindows
            ? dataSource.audioSource!.replaceAll(';', '\\;')
            : dataSource.audioSource!.replaceAll(':', '\\:'),
      );
    }
    await _videoPlayerController!.open(
      Media(
        dataSource.videoSource!,
        httpHeaders: dataSource.httpHeaders,
        start: currentPos,
      ),
      play: true,
    );
    return true;
    // seekTo(currentPos);
  }

  // 开始播放
  Future _initializePlayer() async {
    if (_instance == null) return;
    // 设置倍速
    if (videoType.value == 'live') {
      await setPlaybackSpeed(1.0);
    } else {
      if (_playbackSpeed.value != 1.0) {
        await setPlaybackSpeed(_playbackSpeed.value);
      } else {
        await setPlaybackSpeed(1.0);
      }
    }
    getVideoFit();
    // if (_looping) {
    //   await setLooping(_looping);
    // }

    // 跳转播放
    // if (seekTo != Duration.zero) {
    //   await this.seekTo(seekTo);
    // }

    // 自动播放
    if (_autoPlay) {
      await playIfExists();
      // await play(duration: duration);
    }
  }

  Future<void> autoEnterFullScreen() async {
    bool autoEnterFullscreen = GStorage.setting
        .get(SettingBoxKey.enableAutoEnter, defaultValue: false);
    if (autoEnterFullscreen) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (dataStatus.status.value != DataStatus.loaded) {
          _dataListenerForEnterFullScreen = dataStatus.status.listen((status) {
            if (status == DataStatus.loaded) {
              _dataListenerForEnterFullScreen?.cancel();
              triggerFullScreen(status: true);
            }
          });
        } else {
          triggerFullScreen(status: true);
        }
      });
    }
  }

  final List<Function(Duration position)> _positionListeners = [];
  final List<Function(PlayerStatus status)> _statusListeners = [];

  /// 播放事件监听
  void startListeners() {
    subscriptions.addAll(
      [
        videoPlayerController!.stream.playing.listen((event) {
          if (event) {
            playerStatus.status.value = PlayerStatus.playing;
          } else {
            playerStatus.status.value = PlayerStatus.paused;
          }
          videoPlayerServiceHandler.onStatusChange(
              playerStatus.status.value, isBuffering.value);

          /// 触发回调事件
          for (var element in _statusListeners) {
            // if (element != null) {
            element(event ? PlayerStatus.playing : PlayerStatus.paused);
            // }
          }
          if (videoPlayerController!.state.position.inSeconds != 0) {
            makeHeartBeat(positionSeconds.value, type: 'status');
          }
        }),
        videoPlayerController!.stream.completed.listen((event) {
          if (event) {
            print("stream completed");
            playerStatus.status.value = PlayerStatus.completed;

            /// 触发回调事件
            for (var element in _statusListeners) {
              element(PlayerStatus.completed);
            }
          } else {
            // playerStatus.status.value = PlayerStatus.playing;
          }
          makeHeartBeat(positionSeconds.value, type: 'completed');
        }),
        videoPlayerController!.stream.position.listen((event) {
          _position.value = event;
          updatePositionSecond();
          if (!isSliderMoving.value) {
            _sliderPosition.value = event;
            updateSliderPositionSecond();
          }

          /// 触发回调事件
          for (var element in _positionListeners) {
            element(event);
          }
          makeHeartBeat(event.inSeconds);
        }),
        videoPlayerController!.stream.duration.listen((Duration event) {
          duration.value = event;
        }),
        videoPlayerController!.stream.buffer.listen((Duration event) {
          _buffered.value = event;
          updateBufferedSecond();
        }),
        videoPlayerController!.stream.buffering.listen((bool event) {
          isBuffering.value = event;
          videoPlayerServiceHandler.onStatusChange(
              playerStatus.status.value, event);
        }),
        videoPlayerController!.stream.log.listen((event) {
          // print('videoPlayerController!.stream.log.listen');
          // print('[pp] $event');
          // if (event.level == "v") {
          if (isBuffering.value) {
            _playerLog.value = "[${event.prefix}]${event.text}";
          }
          // }
          // SmartDialog.showToast('视频加载日志： $event');
        }),
        videoPlayerController!.stream.error.listen((String event) {
          // 直播的错误提示没有参考价值，均不予显示
          if (videoType.value == 'live') return;
          if (event.startsWith("Failed to open .") ||
              event.startsWith("Cannot open file ''")) {
            SmartDialog.showToast('视频源为空');
          }
          if (event.startsWith("Failed to open https://") ||
              event.startsWith("Can not open external file https://") ||
              //tcp: ffurl_read returned 0xdfb9b0bb
              //tcp: ffurl_read returned 0xffffff99
              event.startsWith('tcp: ffurl_read returned ')) {
            EasyThrottle.throttle('videoPlayerController!.stream.error.listen',
                const Duration(milliseconds: 10000), () {
              Future.delayed(const Duration(milliseconds: 3000), () async {
                print("isBuffering.value: ${isBuffering.value}");
                print("_buffered.value: ${_buffered.value}");
                if (isBuffering.value && _buffered.value == Duration.zero) {
                  SmartDialog.showToast('视频链接打开失败，重试中',
                      displayTime: const Duration(milliseconds: 500));
                  if (!await refreshPlayer()) {
                    print("failed");
                  }
                }
              });
            });
            return;
          }
          print('videoPlayerController!.stream.error.listen');
          print(event);
          if (event.startsWith('Could not open codec')) {
            SmartDialog.showToast('无法加载解码器, $event，可能会切换至软解');
            return;
          }
          SmartDialog.showToast('视频加载错误, $event');
        }),
        // videoPlayerController!.stream.volume.listen((event) {
        //   if (!mute.value && _volumeBeforeMute != event) {
        //     _volumeBeforeMute = event / 100;
        //   }
        // }),
        // 媒体通知监听
        // onPlayerStatusChanged.listen((PlayerStatus event) {
        //   videoPlayerServiceHandler.onStatusChange(event, isBuffering.value);
        // }),
        onPositionChanged.listen((Duration event) {
          EasyThrottle.throttle(
              'mediaServicePosition',
              const Duration(seconds: 1),
              () => videoPlayerServiceHandler.onPositionChange(event));
        }),
      ],
    );
  }

  /// 移除事件监听
  void removeListeners() {
    for (final s in subscriptions) {
      s.cancel();
    }
  }

  /// 跳转至指定位置
  Future<void> seekTo(Duration position, {type = 'seek'}) async {
    // if (position >= duration.value) {
    //   position = duration.value - const Duration(milliseconds: 100);
    // }
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    _position.value = position;
    updatePositionSecond();
    _heartDuration = position.inSeconds;
    if (duration.value.inSeconds != 0) {
      if (type != 'slider') {
        /// 拖动进度条调节时，不等待第一帧，防止抖动
        await _videoPlayerController?.stream.buffer.first;
      }
      danmakuController?.clear();
      await _videoPlayerController?.seek(position);
      // if (playerStatus.stopped) {
      //   play();
      // }
    } else {
      print('seek duration else');
      _timerForSeek?.cancel();
      _timerForSeek =
          Timer.periodic(const Duration(milliseconds: 200), (Timer t) async {
        //_timerForSeek = null;
        if (duration.value.inSeconds != 0) {
          await _videoPlayerController?.stream.buffer.first;
          danmakuController?.clear();
          await _videoPlayerController?.seek(position);
          // if (playerStatus.status.value == PlayerStatus.paused) {
          //   play();
          // }
          t.cancel();
          _timerForSeek = null;
        }
      });
    }
  }

  /// 设置倍速
  Future<void> setPlaybackSpeed(double speed) async {
    /// TODO  _duration.value丢失
    await _videoPlayerController?.setRate(speed);
    // 移除倍速时改变弹幕速度的能力
    // try {
    //   DanmakuOption currentOption = danmakuController!.option;
    //   defaultDuration ??= currentOption.duration;
    //   DanmakuOption updatedOption = currentOption.copyWith(
    //       duration: ((defaultDuration! / speed) * playbackSpeed).round());
    //   danmakuController!.updateOption(updatedOption);
    // } catch (_) {}
    // fix 长按倍速后放开不恢复
    if (doubleSpeedStatus.value == 0) {
      _playbackSpeed.value = speed;
    }
  }

  // 还原默认速度
  Future<void> setDefaultSpeed() async {
    double speed =
        videoStorage.get(VideoBoxKey.playSpeedDefault, defaultValue: 1.0);
    await _videoPlayerController?.setRate(speed);
    _playbackSpeed.value = speed;
  }

  /// 设置倍速
  // Future<void> togglePlaybackSpeed() async {
  //   List<double> allowedSpeeds =
  //       PlaySpeed.values.map<double>((e) => e.value).toList();
  //   int index = allowedSpeeds.indexOf(_playbackSpeed.value);
  //   if (index < allowedSpeeds.length - 1) {
  //     setPlaybackSpeed(allowedSpeeds[index + 1]);
  //   } else {
  //     setPlaybackSpeed(allowedSpeeds[0]);
  //   }
  // }

  /// 播放视频
  /// TODO  _duration.value丢失
  Future<void> play({bool repeat = false, bool hideControls = true}) async {
    // String top = Get.currentRoute;
    // print("top:$top");
    // if (!top.startsWith('/video')) {
    //   return;
    // }
    // if (_playerCount.value == 0) return;
    // if (playerStatus.status.value == PlayerStatus.disabled) return;
    // 播放时自动隐藏控制条
    controls = !hideControls;
    // repeat为true，将从头播放
    if (repeat) {
      // await seekTo(Duration.zero);
      await seekTo(Duration.zero, type: "slider");
    }

    await _videoPlayerController?.play();

    playerStatus.status.value = PlayerStatus.playing;
    // screenManager.setOverlays(false);

    audioSessionHandler.setActive(true);

    // Future.delayed(const Duration(milliseconds: 100), () {
    //   getCurrentVolume();
    // });
  }

  /// 暂停播放
  Future<void> pause({bool notify = true, bool isInterrupt = false}) async {
    await _videoPlayerController?.pause();
    playerStatus.status.value = PlayerStatus.paused;

    // 主动暂停时让出音频焦点
    if (!isInterrupt) {
      audioSessionHandler.setActive(false);
    }
  }

  // 感觉用这个管理状态也不是很好用
  void disable() async {
    if (floatingManager.containsFloating(globalId)) return;
    String top = Get.currentRoute;
    print("top:$top");
    if (!top.startsWith('/video') && !top.startsWith('/live')) {
      // playerStatus.status.value = PlayerStatus.disabled;
      _heartDuration = 0;
      _videoPlayerController?.stop();
      videoPlayerServiceHandler.clear();
      return;
    }
  }

  /// 更改播放状态
  Future<void> togglePlay() async {
    feedBack();
    if (playerStatus.playing) {
      pause();
    } else {
      play();
    }
  }

  /// 隐藏控制条
  void _hideTaskControls() {
    if (_timer != null) {
      _timer!.cancel();
    }
    Duration waitingTime = Duration(seconds: enableLongShowControl ? 30 : 3);
    _timer = Timer(waitingTime, () {
      if (!isSliderMoving.value) {
        controls = false;
      }
      _timer = null;
    });
  }

  /// 调整播放时间
  onChangedSlider(double v) {
    _sliderPosition.value = Duration(seconds: v.floor());
    updateSliderPositionSecond();
  }

  void onChangedSliderStart() {
    _isSliderMoving.value = true;
  }

  void onUpdatedSliderProgress(Duration value) {
    _sliderTempPosition.value = value;
    _sliderPosition.value = value;
    updateSliderPositionSecond();
  }

  void onChangedSliderEnd() {
    feedBack();
    _isSliderMoving.value = false;
    _hideTaskControls();
  }

  /// 音量
  Future<void> getCurrentVolume() async {
    // mac try...catch
    try {
      _currentVolume.value = (await FlutterVolumeController.getVolume())!;
    } catch (_) {}
  }

  Future<void> setVolume(double volumeNew,
      {bool videoPlayerVolume = false}) async {
    if (volumeNew < 0.0) {
      volumeNew = 0.0;
    } else if (volumeNew > 1.0) {
      volumeNew = 1.0;
    }
    if (volume.value == volumeNew) {
      return;
    }
    volume.value = volumeNew;

    try {
      FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(volumeNew);
    } catch (err) {
      print(err);
    }
  }

  void volumeUpdated() {
    showVolumeStatus.value = true;
    _timerForShowingVolume?.cancel();
    _timerForShowingVolume = Timer(const Duration(seconds: 1), () {
      showVolumeStatus.value = false;
    });
  }

  /// 亮度
  // Future<void> getCurrentBrightness() async {
  //   try {
  //     _currentBrightness.value = await ScreenBrightness().current;
  //   } catch (e) {
  //     throw 'Failed to get current brightness';
  //     //return 0;
  //   }
  // }

  // Future<void> setBrightness(double brightness) async {
  //   try {
  //     this.brightness.value = brightness;
  //     await ScreenBrightness.instance.setSystemScreenBrightness(brightness);
  //   } catch (e) {
  //     throw 'Failed to set brightness';
  //   }
  // }

  // Future<void> resetBrightness() async {
  //   try {
  //     await ScreenBrightness().resetScreenBrightness();
  //   } catch (e) {
  //     throw 'Failed to reset brightness';
  //   }
  // }

  /// Toggle Change the videofit accordingly
  void toggleVideoFit() {
    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: const Text('视频尺寸'),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 2,
              children: [
                for (var i in videoFitType) ...[
                  if (_videoFit.value == i['attr']) ...[
                    FilledButton(
                      onPressed: () async {
                        _videoFit.value = i['attr'];
                        _videoFitDesc.value = i['desc'];
                        setVideoFit();
                        Get.back();
                      },
                      child: Text(i['desc']),
                    ),
                  ] else ...[
                    FilledButton.tonal(
                      onPressed: () async {
                        _videoFit.value = i['attr'];
                        _videoFitDesc.value = i['desc'];
                        setVideoFit();
                        Get.back();
                      },
                      child: Text(i['desc']),
                    ),
                  ]
                ]
              ],
            );
          }),
        );
      },
    );
  }

  /// 缓存fit
  Future<void> setVideoFit() async {
    List attrs = videoFitType.map((e) => e['attr']).toList();
    int index = attrs.indexOf(_videoFit.value);
    SmartDialog.showToast(videoFitType[index]['toast'],
        displayTime: const Duration(seconds: 1));
    videoStorage.put(VideoBoxKey.cacheVideoFit, index);
  }

  /// 读取fit
  Future<void> getVideoFit() async {
    int fitValue = videoStorage.get(VideoBoxKey.cacheVideoFit, defaultValue: 0);
    var attr = videoFitType[fitValue]['attr'];
    // 由于none与scaleDown涉及视频原始尺寸，需要等待视频加载后再设置，否则尺寸会变为0，出现错误;
    if (attr == BoxFit.none || attr == BoxFit.scaleDown) {
      if (buffered.value == Duration.zero) {
        attr = BoxFit.contain;
        _dataListenerForVideoFit = dataStatus.status.listen((status) {
          if (status == DataStatus.loaded) {
            _dataListenerForVideoFit?.cancel();
            int fitValue =
                videoStorage.get(VideoBoxKey.cacheVideoFit, defaultValue: 0);
            var attr = videoFitType[fitValue]['attr'];
            if (attr == BoxFit.none || attr == BoxFit.scaleDown) {
              _videoFit.value = attr;
            }
          }
        });
      }
      // fill不应该在竖屏视频生效
    } else if (attr == BoxFit.fill && direction.value == 'vertical') {
      attr = BoxFit.contain;
    }
    _videoFit.value = attr;
    _videoFitDesc.value = videoFitType[fitValue]['desc'];
  }

  /// 设置后台播放
  Future<void> setBackgroundPlay(bool val) async {
    setting.put(SettingBoxKey.enableBackgroundPlay, val);
    videoPlayerServiceHandler.revalidateSetting();
  }

  /// 读取亮度
  // Future<void> getVideoBrightness() async {
  //   double brightnessValue =
  //       videoStorage.get(VideoBoxKey.videoBrightness, defaultValue: 0.5);
  //   setBrightness(brightnessValue);
  // }

  set controls(bool visible) {
    if (_showControls.value == visible) return;
    _showControls.value = visible;
    _timer?.cancel();
    if (visible) {
      _hideTaskControls();
    }
  }

  /// 设置长按倍速状态 live模式下禁用
  void setDoubleSpeedStatus(bool val) async {
    if (videoType.value == 'live') {
      return;
    }
    if (controlsLock.value) {
      return;
    }
    if (val) {
      _doubleSpeedStatus.value =
          enableAutoLongPressSpeed ? playbackSpeed * 2 : longPressSpeed;
      await setPlaybackSpeed(_doubleSpeedStatus.value);
      if (enableLongPressSpeedIncrease) {
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
          if (_doubleSpeedStatus.value > 0) {
            _doubleSpeedStatus.value = min(8, _doubleSpeedStatus.value * 1.15);
            await setPlaybackSpeed(_doubleSpeedStatus.value);
          } else {
            timer.cancel();
          }
        });
      }
    } else {
      print("playbackSpeed: $playbackSpeed");
      _doubleSpeedStatus.value = 0;
      await setPlaybackSpeed(playbackSpeed);
    }
  }

  /// 关闭控制栏
  void onLockControl(bool val) {
    feedBack();
    _controlsLock.value = val;
    showControls.value = !val;
  }

  void toggleFullScreen(bool val) {
    _isFullScreen.value = val;
  }

  // 应用内小窗
  bool triggerFloatingWindow(VideoIntroController? videoIntroController,
      BangumiIntroController? bangumiIntroController, String heroTag) {
    if (videoController == null) {
      return false;
    }

    Widget iconButton(IconData icon, VoidCallback onPressed) {
      return Expanded(
        child: IconButton(
          constraints: const BoxConstraints(),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
              return Theme.of(Get.context!)
                  .colorScheme
                  .surface
                  .withOpacity(0.9);
            }),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon, color: Theme.of(Get.context!).colorScheme.onSurface),
        ),
      );
    }

    print("enterPip");
    print(videoIntroController);
    print(bangumiIntroController);
    bool isLive =
        videoIntroController == null && bangumiIntroController == null;
    double? videoHeight = videoPlayerController?.state.height?.toDouble();
    double? videoWidth = videoPlayerController?.state.width?.toDouble();
    // bool isVertical = direction.value == 'vertical';
    // 长宽比
    double aspectRatio =
        direction.value == 'horizontal' ? 9.0 / 16.0 : 16.0 / 9.0;

    if (videoWidth != null && videoHeight != null) {
      if ((videoWidth > videoHeight) ^ (direction.value != 'horizontal')) {
        aspectRatio = videoHeight / videoWidth;
      }
    }
    print('videoHeight: $videoHeight');
    print('videoWidth: $videoWidth');
    print('direction.value: ${direction.value}');
    print('aspectRatio: $aspectRatio');
    double floatingWidth = aspectRatio > 1 ? 150.0 : 240.0;
    double extentHeight = 40.0;
    double floatingHeight = floatingWidth * aspectRatio + extentHeight;

    Widget baseWindow = SizedBox(
      width: floatingWidth,
      height: floatingHeight,
      child: Column(
        children: [
          SizedBox(
            width: floatingWidth,
            height: floatingHeight - extentHeight,
            child: InkWell(
              onTap: () {
                if (videoIntroController != null) {
                  videoIntroController.openVideoDetail();
                } else if (bangumiIntroController != null) {
                  bangumiIntroController.openVideoDetail();
                } else {
                  pauseIfExists();
                }
                floatingManager.closeFloating(globalId);
              },
              child: Video(
                controller: videoController!,
                controls: NoVideoControls,
                pauseUponEnteringBackgroundMode:
                    !_continuePlayInBackground.value,
                resumeUponEnteringForegroundMode: true,
                // 字幕尺寸调节
                subtitleViewConfiguration: SubtitleViewConfiguration(
                    style: subtitleStyle.value,
                    padding:
                        EdgeInsets.only(bottom: subtitleBottomPadding.value)),
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(
            width: floatingWidth,
            height: extentHeight,
            child: Row(children: [
              // if (videoIntroController != null &&
              //         videoIntroController.hasNextEpisode() ||
              //     bangumiIntroController != null &&
              //         bangumiIntroController.hasNextEpisode())
              // iconButton(Icons.skip_next, () {
              //   if (videoIntroController != null) {
              //     videoIntroController.nextPlay();
              //   } else if (bangumiIntroController != null) {
              //     bangumiIntroController.nextPlay();
              //   }
              // }),
              if (!isLive)
                iconButton(
                  MdiIcons.rewind10,
                  () => seekTo(position.value - const Duration(seconds: 10),
                      type: 'slide'),
                ),
              if (!isLive)
                Obx(
                  () => iconButton(
                    playerStatus.playing ? Icons.pause : Icons.play_arrow,
                    () => togglePlay(),
                  ),
                ),
              if (!isLive)
                iconButton(
                  MdiIcons.fastForward10,
                  () => seekTo(position.value + const Duration(seconds: 10),
                      type: 'slide'),
                ),
              iconButton(Icons.close, () {
                floatingManager.closeFloating(globalId);
                pauseIfExists();
              }),
            ]),
          ),
        ],
      ),
    );
    // pauseIfExists();
    // int maxLength = max(videoPlayerController!.state.width!,
    //     videoPlayerController!.state.height!);
    // if (maxLength <= 0) {
    //   SmartDialog.showToast('视频尺寸异常，无法开启小窗');
    //   return;
    // }
    // // dp 转像素
    // double lengthLimit = 0.8 *
    //     min(Get.width, Get.height) *
    //     MediaQuery.of(Get.context!).devicePixelRatio;
    // android_window.open(
    //   size: Size(
    //     videoPlayerController!.state.width! / maxLength * lengthLimit,
    //     videoPlayerController!.state.height! / maxLength * lengthLimit,
    //   ),
    //   position: const Offset(100, 300),
    // );
    // await Future.delayed(const Duration(milliseconds: 300));
    // dataSource.startAt = position.value;
    // final response = await android_window.post(
    //   'play',
    //   // dataSource,
    //   json.encode(dataSource.toJson()),
    // );
    // SmartDialog.showToast(response.toString());

    // if (floatingWindow != null) {
    //   floatingWindow!.close();
    // }
    // floatingManager.closeFloating(globalId);
    floatingWindow = floatingManager.createFloating(
      globalId,
      Floating(
        ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: baseWindow,
        ),
        isPosCache: true,
        slideType: FloatingSlideType.onRightAndTop,
        right: 0,
        top: 100,
        moveOpacity: 0.5,
        slideBottomHeight: 20,
      ),
    );
    floatingWindow!.open(Get.context!);
    var listener = FloatingEventListener()
      ..closeListener = () {
        VideoDetailController? videoDetailCtr;
        try {
          videoDetailCtr = Get.find<VideoDetailController>(tag: heroTag);
        } catch (_) {}
        print("videoDetailCtr: $videoDetailCtr");
        if (videoDetailCtr != null) {
          videoDetailCtr.defaultST = position.value;
        }
      };
    floatingWindow!.addFloatingListener(listener);
    return true;
  }

  // 全屏
  Future<void> triggerFullScreen(
      {bool status = true, bool equivalent = false}) async {
    stopScreenTimer();
    FullScreenMode mode = FullScreenModeCode.fromCode(
        setting.get(SettingBoxKey.fullScreenMode, defaultValue: 0))!;
    bool removeSafeArea = setting.get(SettingBoxKey.videoPlayerRemoveSafeArea,
        defaultValue: false);
    if (!isFullScreen.value && status) {
      // StatusBarControl.setHidden(true, animation: StatusBarAnimation.FADE);
      hideStatusBar();

      /// 按照视频宽高比决定全屏方向
      toggleFullScreen(true);
      await Future.delayed(const Duration(milliseconds: 10));

      /// 进入全屏
      if (mode == FullScreenMode.none) {
        return;
      }
      if (mode == FullScreenMode.gravity) {
        fullAutoModeForceSensor();
        return;
      }
      if (mode == FullScreenMode.vertical ||
          (mode == FullScreenMode.auto && direction.value == 'vertical') ||
          (mode == FullScreenMode.ratio &&
              (Get.height / Get.width < 1.25 ||
                  direction.value == 'vertical'))) {
        await verticalScreenForTwoSeconds();
      } else {
        await landScape();
      }
    } else if (isFullScreen.value && !status) {
      // StatusBarControl.setHidden(false, animation: StatusBarAnimation.FADE);
      if (!removeSafeArea) showStatusBar();
      toggleFullScreen(false);
      await Future.delayed(const Duration(milliseconds: 10));
      if (mode == FullScreenMode.none) {
        return;
      }
      if (!horizontalScreen) {
        await verticalScreenForTwoSeconds();
      } else {
        await autoScreen();
      }
    }
  }

  void addPositionListener(Function(Duration position) listener) =>
      _positionListeners.add(listener);
  void removePositionListener(Function(Duration position) listener) =>
      _positionListeners.remove(listener);
  void addStatusLister(Function(PlayerStatus status) listener) =>
      _statusListeners.add(listener);
  void removeStatusLister(Function(PlayerStatus status) listener) =>
      _statusListeners.remove(listener);

  /// 截屏
  Future screenshot() async {
    final Uint8List? screenshot =
        await _videoPlayerController!.screenshot(format: 'image/png');
    return screenshot;
  }

  Future<void> videoPlayerClosed() async {
    _timer?.cancel();
    _timerForVolume?.cancel();
    _timerForGettingVolume?.cancel();
    timerForTrackingMouse?.cancel();
    _timerForSeek?.cancel();
  }

  // 记录播放记录
  Future makeHeartBeat(int progress, {type = 'playing'}) async {
    if (!_enableHeart || MineController.anonymity) {
      return false;
    }
    if (videoType.value == 'live') {
      return;
    }
    // print("playerStatus.status.value: ${playerStatus.status.value}");
    // print("type: $type");
    bool isComplete = playerStatus.status.value == PlayerStatus.completed ||
        type == 'completed';
    // 播放状态变化时，更新
    if (type == 'status' || type == 'completed') {
      await VideoHttp.heartBeat(
        bvid: _bvid,
        cid: _cid,
        progress: isComplete ? -1 : progress,
      );
      return;
    }
    // 正常播放时，间隔3秒更新一次
    if (progress - _heartDuration >= 3) {
      _heartDuration = progress;
      await VideoHttp.heartBeat(
        bvid: _bvid,
        cid: _cid,
        progress: progress,
      );
    }
  }

  setPlayRepeat(PlayRepeat type) {
    playRepeat = type;
    videoStorage.put(VideoBoxKey.playRepeat, type.value);
  }

  void putDanmakuSettings() {
    setting.put(SettingBoxKey.danmakuWeight, PlDanmakuController.danmakuWeight);
    setting.put(SettingBoxKey.danmakuBlockType, blockTypes);
    setting.put(SettingBoxKey.danmakuShowArea, showArea);
    setting.put(SettingBoxKey.danmakuOpacity, opacityVal);
    setting.put(SettingBoxKey.danmakuFontScale, fontSizeVal);
    setting.put(SettingBoxKey.danmakuDuration, danmakuDurationVal);
    setting.put(SettingBoxKey.strokeWidth, strokeWidth);
    setting.put(SettingBoxKey.fontWeight, fontWeight);
    setting.put(SettingBoxKey.danmakuMassiveMode, massiveMode);
    setting.put(SettingBoxKey.convertToScrollDanmaku,
        PlDanmakuController.convertToScrollDanmaku);
  }

  Future<void> dispose() async {
    // 每次减1，最后销毁
    // if (type == 'single' && playerCount.value > 1) {
    //   _playerCount.value -= 1;
    //   _heartDuration = 0;
    //   pause();
    //   return;
    // }
    // _playerCount.value = 0;
    pause();
    try {
      _timer?.cancel();
      _timerForVolume?.cancel();
      _timerForGettingVolume?.cancel();
      timerForTrackingMouse?.cancel();
      _timerForSeek?.cancel();
      // _position.close();
      _playerEventSubs?.cancel();
      // _sliderPosition.close();
      // _sliderTempPosition.close();
      // _isSliderMoving.close();
      // _duration.close();
      // _buffered.close();
      // _showControls.close();
      // _controlsLock.close();

      // playerStatus.status.close();
      // dataStatus.status.close();
      _dataListenerForVideoFit?.cancel();
      _dataListenerForEnterFullScreen?.cancel();
      _playerListenerForEnterPip?.cancel();

      if (_videoPlayerController != null) {
        var pp = _videoPlayerController!.platform as NativePlayer;
        await pp.setProperty('audio-files', '');
        removeListeners();
        await _videoPlayerController?.dispose();
        _videoPlayerController = null;
      }
      _instance = null;
      videoPlayerServiceHandler.clear();
    } catch (err) {
      print(err);
    }
  }

  Future refreshVideoMetaInfo() async {
    _vttSubtitles.clear();
    Map res = await VideoHttp.videoMetaInfo(bvid: _bvid, cid: _cid);
    if (!res["status"]) {
      SmartDialog.showToast('查询视频元信息（字幕、防挡、章节等）错误，${res["msg"]}');
    }
    if (res["data"].length == 0) {
      return;
    }
    _vttSubtitles.value = await VideoHttp.vttSubtitles(res["data"]);
    // if (_vttSubtitles.isEmpty) {
    //   SmartDialog.showToast('字幕均加载失败');
    // }
    return;
  }

  void chooseSubtitle() {
    if (_vttSubtitles.isEmpty) return;

    int findSubtitleWithoutAi() {
      return _vttSubtitles.indexWhere((element) {
        return !element['language']!.startsWith('ai');
      });
    }

    void setSubtitleFallback(int defaultIndex) {
      int index = findSubtitleWithoutAi();
      setSubtitle(index != -1 ? index : defaultIndex);
    }

    String preference = setting.get(SettingBoxKey.subtitlePreference,
        defaultValue: SubtitlePreference.values.first.code);

    if (_vttSubtitlesIndex < 1 || _vttSubtitlesIndex >= _vttSubtitles.length) {
      switch (preference) {
        case 'on':
          setSubtitleFallback(1);
          break;
        case 'withoutAi':
          setSubtitleFallback(0);
          break;
        default:
          setSubtitle(0);
      }
      return;
    }

    if (_vttSubtitles[_vttSubtitlesIndex.value]['language']!.startsWith('ai')) {
      setSubtitleFallback(
          preference == 'withoutAi' ? 0 : _vttSubtitlesIndex.value);
    } else {
      setSubtitle(_vttSubtitlesIndex.value);
    }
  }

  // 设定字幕轨道
  setSubtitle(int index) {
    if (index == 0) {
      _videoPlayerController?.setSubtitleTrack(SubtitleTrack.no());
      _vttSubtitlesIndex.value = 0;
      return;
    }
    Map<String, String> s = _vttSubtitles[index];
    debugPrint(s['text']);
    _videoPlayerController?.setSubtitleTrack(SubtitleTrack.data(
      s['text']!,
      title: s['title']!,
      language: s['language']!,
    ));
    _vttSubtitlesIndex.value = index;
  }

  void setContinuePlayInBackground(bool? status) {
    _continuePlayInBackground.value =
        status ?? !_continuePlayInBackground.value;
    setting.put(SettingBoxKey.continuePlayInBackground,
        _continuePlayInBackground.value);
  }

  void setOnlyPlayAudio(bool? status) {
    _onlyPlayAudio.value = status ?? !_onlyPlayAudio.value;
    videoPlayerController?.setVideoTrack(
        _onlyPlayAudio.value ? VideoTrack.no() : VideoTrack.auto());
  }

  void setSubtitleFontSize() {
    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: const Text('字幕字号设置'),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: subtitleFontSize.value,
                  onChanged: (double value) {
                    setState(() {
                      subtitleFontSize.value = value;
                      subtitleStyle.value = subtitleStyle.value
                          .copyWith(fontSize: subtitleFontSize.value);
                    });
                  },
                  onChangeEnd: (double value) {
                    videoStorage.put(VideoBoxKey.subtitleFontSize, value);
                  },
                  min: 40.0,
                  max: 120.0,
                  divisions: 80,
                  label: subtitleFontSize.value.round().toString(),
                ),
                Text(
                  '当前字号：${subtitleFontSize.value.round()}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            );
          }),
        );
      },
    );
  }

  void setSubtitleBottomPadding() {
    showDialog(
      context: Get.context!,
      builder: (context) {
        return AlertDialog(
          title: const Text('字幕底部间距设置'),
          content: StatefulBuilder(builder: (context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: subtitleBottomPadding.value,
                  onChanged: (double value) {
                    setState(() {
                      subtitleBottomPadding.value = value;
                    });
                  },
                  onChangeEnd: (double value) {
                    videoStorage.put(VideoBoxKey.subtitleBottomPadding, value);
                  },
                  min: 10.0,
                  max: 180.0,
                  divisions: 170,
                  label: subtitleBottomPadding.value.round().toString(),
                ),
                Text(
                  '当前底部间距：${subtitleBottomPadding.value.round()}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}
