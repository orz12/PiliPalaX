// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:PiliPalaX/http/video.dart';
import 'package:PiliPalaX/pages/mine/controller.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPalaX/services/service_locator.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:universal_platform/universal_platform.dart';

import '../../models/video/play/subtitle.dart';
// import 'package:wakelock_plus/wakelock_plus.dart';

Box videoStorage = GStrorage.video;
Box setting = GStrorage.setting;
Box localCache = GStrorage.localCache;

class PlPlayerController {
  Player? _videoPlayerController;
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
  final Rx<bool> _doubleSpeedStatus = false.obs;
  final Rx<bool> _controlsLock = false.obs;
  final Rx<bool> _isFullScreen = false.obs;
  // 默认投稿视频格式
  static Rx<String> _videoType = 'archive'.obs;

  final Rx<String> _direction = 'horizontal'.obs;

  final Rx<BoxFit> _videoFit = Rx(videoFitType.first['attr']);
  final Rx<String> _videoFitDesc = Rx(videoFitType.first['desc']);
  late StreamSubscription<DataStatus> _dataListenerForVideoFit;
  late StreamSubscription<DataStatus> _dataListenerForEnterFullscreen;

  /// 后台播放
  final Rx<bool> _continuePlayInBackground = false.obs;

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
  final RxList<Map<String, String>> _vttSubtitles = <Map<String, String>>[].obs;
  final RxInt _vttSubtitlesIndex = 0.obs;

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
    {'attr': BoxFit.fill, 'desc': '拉伸', 'toast': '拉伸至播放器尺寸，将产生变形'},
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

  // 视频静音
  Rx<bool> get mute => _mute;
  Stream<bool> get onMuteChanged => _mute.stream;

  // 视频字幕
  RxList<Map<String, String>> get vttSubtitles => _vttSubtitles;
  RxInt get vttSubtitlesIndex => _vttSubtitlesIndex;

  /// [videoPlayerController] instance of Player
  Player? get videoPlayerController => _videoPlayerController;

  /// [videoController] instace of Player
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

  /// 是否长按倍速
  Rx<bool> get doubleSpeedStatus => _doubleSpeedStatus;

  Rx<bool> isBuffering = true.obs;

  /// 屏幕锁 为true时，关闭控制栏
  Rx<bool> get controlsLock => _controlsLock;

  /// 全屏状态
  Rx<bool> get isFullScreen => _isFullScreen;

  /// 全屏方向
  Rx<String> get direction => _direction;

  Rx<int> get playerCount => _playerCount;

  ///
  Rx<String> get videoType => _videoType;

  /// 弹幕开关
  Rx<bool> isOpenDanmu = false.obs;

  /// 弹幕权重
  ValueNotifier<int> danmakuWeight = ValueNotifier(0);
  // 关联弹幕控制器
  DanmakuController? danmakuController;
  // 弹幕相关配置
  late List blockTypes;
  late double showArea;
  late double opacityVal;
  late double fontSizeVal;
  late double strokeWidth;
  late double danmakuDurationVal;
  late List<double> speedsList;
  double? defaultDuration;
  late bool enableAutoLongPressSpeed = false;

  // 播放顺序相关
  PlayRepeat playRepeat = PlayRepeat.pause;

  void updateSliderPositionSecond() {
    int newSecond = _sliderPosition.value.inSeconds;
    if (sliderPositionSeconds.value != newSecond) {
      sliderPositionSeconds.value = newSecond;
    }
  }

  void updatePositionSecond() {
    int newSecond = _position.value.inSeconds;
    if (positionSeconds.value != newSecond) {
      positionSeconds.value = newSecond;
    }
  }

  void updateDurationSecond() {
    int newSecond = _duration.value.inSeconds;
    if (durationSeconds.value != newSecond) {
      durationSeconds.value = newSecond;
    }
  }

  void updateBufferedSecond() {
    int newSecond = _buffered.value.inSeconds;
    if (bufferedSeconds.value != newSecond) {
      bufferedSeconds.value = newSecond;
    }
  }

  // 添加一个私有构造函数
  PlPlayerController._() {
    _videoType = videoType;
    isOpenDanmu.value =
        setting.get(SettingBoxKey.enableShowDanmaku, defaultValue: false);
    danmakuWeight.value =
        localCache.get(LocalCacheKey.danmakuWeight, defaultValue: 0);
    blockTypes =
        localCache.get(LocalCacheKey.danmakuBlockType, defaultValue: []);
    showArea = localCache.get(LocalCacheKey.danmakuShowArea, defaultValue: 0.5);
    // 不透明度
    opacityVal =
        localCache.get(LocalCacheKey.danmakuOpacity, defaultValue: 1.0);
    // 字体大小
    fontSizeVal =
        localCache.get(LocalCacheKey.danmakuFontScale, defaultValue: 1.0);
    // 弹幕时间
    danmakuDurationVal =
        localCache.get(LocalCacheKey.danmakuDuration, defaultValue: 4.0);
    // 描边粗细
    strokeWidth = localCache.get(LocalCacheKey.strokeWidth, defaultValue: 1.5);
    playRepeat = PlayRepeat.values.toList().firstWhere(
          (e) =>
              e.value ==
              videoStorage.get(VideoBoxKey.playRepeat,
                  defaultValue: PlayRepeat.pause.value),
        );
    _playbackSpeed.value =
        videoStorage.get(VideoBoxKey.playSpeedDefault, defaultValue: 1.0);
    enableAutoLongPressSpeed = setting
        .get(SettingBoxKey.enableAutoLongPressSpeed, defaultValue: false);
    // 后台播放
    _continuePlayInBackground.value =
        setting.get(SettingBoxKey.continuePlayInBackground, defaultValue: true);
    if (!enableAutoLongPressSpeed) {
      _longPressSpeed.value = videoStorage
          .get(VideoBoxKey.longPressSpeedDefault, defaultValue: 3.0);
    }
    speedsList = List<double>.from(videoStorage
        .get(VideoBoxKey.customSpeedsList, defaultValue: <double>[]));
    for (final PlaySpeed i in PlaySpeed.values) {
      speedsList.add(i.value);
    }
    speedsList.sort();

    // _playerEventSubs = onPlayerStatusChanged.listen((PlayerStatus status) {
    //   if (status == PlayerStatus.playing) {
    //     WakelockPlus.enable();
    //   } else {
    //     WakelockPlus.disable();
    //   }
    // });
  }

  // 获取实例 传参
  static PlPlayerController getInstance({
    String videoType = 'archive',
  }) {
    // 如果实例尚未创建，则创建一个新实例
    _instance ??= PlPlayerController._();
    _instance!._playerCount.value += 1;
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

      if (_playerCount.value == 0) {
        return;
      }
      // 配置Player 音轨、字幕等等
      _videoPlayerController = await _createVideoController(
          dataSource, _looping, enableHA, width, height);
      // 获取视频时长 00:00
      _duration.value = duration ?? _videoPlayerController!.state.duration;
      updateDurationSecond();
      // 数据加载完成
      dataStatus.status.value = DataStatus.loaded;

      // listen the video player events
      if (!_listenersInitialized) {
        startListeners();
      }
      await _initializePlayer(seekTo: seekTo, duration: _duration.value);
      if (videoType.value != 'live' && _cid != 0) {
        refreshSubtitles().then((value) {
          if (_vttSubtitles.isNotEmpty) {
            String preference = setting.get(SettingBoxKey.subtitlePreference,
                defaultValue: SubtitlePreference.values.first.code);
            if (preference == 'on') {
              setSubtitle(vttSubtitles[1]);
            } else if (preference == 'withoutAi') {
              for (int i = 1; i < _vttSubtitles.length; i++) {
                if (_vttSubtitles[i]['language']!.startsWith('ai')) {
                  continue;
                }
                setSubtitle(vttSubtitles[i]);
                break;
              }
            }
          }
        });
      }
    } catch (err) {
      dataStatus.status.value = DataStatus.error;
      print('plPlayer err:  $err');
    }
  }

  // 配置播放器
  Future<Player> _createVideoController(
    DataSource dataSource,
    PlaylistMode looping,
    bool enableHA,
    double? width,
    double? height,
  ) async {
    // 每次配置时先移除监听
    removeListeners();
    isBuffering.value = false;
    buffered.value = Duration.zero;
    _heartDuration = 0;
    _position.value = Duration.zero;
    // 初始化时清空弹幕，防止上次重叠
    if (danmakuController != null) {
      danmakuController!.clear();
    }
    int bufferSize =
        setting.get(SettingBoxKey.expandBuffer, defaultValue: false)
            ? (videoType.value == 'live' ? 64 * 1024 * 1024 : 32 * 1024 * 1024)
            : (videoType.value == 'live' ? 32 * 1024 * 1024 : 5 * 1024 * 1024);
    Player player = _videoPlayerController ??
        Player(
          configuration: PlayerConfiguration(
            // 默认缓冲 5M 大小
            bufferSize: bufferSize,
          ),
        );

    var pp = player.platform as NativePlayer;
    // 解除倍速限制
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    //  音量不一致
    if (Platform.isAndroid) {
      await pp.setProperty("volume-max", "100");
      String ao = setting.get(SettingBoxKey.useOpenSLES, defaultValue: true)
          ? "opensles,audiotrack"
          : "audiotrack,opensles";
      await pp.setProperty("ao", ao);
    }
    // // vo=gpu-next & gpu-context=android & gpu-api=opengl
    // await pp.setProperty("vo", "gpu-next");
    // await pp.setProperty("gpu-context", "android");
    // await pp.setProperty("gpu-api", "opengl");
    await player.setAudioTrack(
      AudioTrack.auto(),
    );

    // 音轨
    if (dataSource.audioSource != '' && dataSource.audioSource != null) {
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
          ),
        );

    player.setPlaylistMode(looping);

    if (dataSource.type == DataSourceType.asset) {
      final assetUrl = dataSource.videoSource!.startsWith("asset://")
          ? dataSource.videoSource!
          : "asset://${dataSource.videoSource!}";
      player.open(
        Media(assetUrl, httpHeaders: dataSource.httpHeaders),
        play: false,
      );
    }
    player.open(
      Media(dataSource.videoSource!, httpHeaders: dataSource.httpHeaders),
      play: false,
    );
    // 音轨
    // player.setAudioTrack(
    //   AudioTrack.uri(dataSource.audioSource!),
    // );

    return player;
  }

  // 开始播放
  Future _initializePlayer({
    Duration seekTo = Duration.zero,
    Duration? duration,
  }) async {
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
    if (seekTo != Duration.zero) {
      await this.seekTo(seekTo);
    }

    // 自动播放
    if (_autoPlay) {
      await play(duration: duration);
    }
  }

  Future<void> autoEnterFullscreen() async {
    bool autoEnterFullscreen = GStrorage.setting
        .get(SettingBoxKey.enableAutoEnter, defaultValue: false);
    if (autoEnterFullscreen) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (dataStatus.status.value != DataStatus.loaded) {
          _dataListenerForEnterFullscreen = dataStatus.status.listen((status) {
            if (status == DataStatus.loaded) {
              _dataListenerForEnterFullscreen.cancel();
              triggerFullScreen(status: true);
            }
          });
        } else {
          triggerFullScreen(status: true);
        }
      });
    }
  }

  List<StreamSubscription> subscriptions = [];
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
            if (element != null) {
              element(event ? PlayerStatus.playing : PlayerStatus.paused);
            }
          }
          if (videoPlayerController!.state.position.inSeconds != 0) {
            makeHeartBeat(positionSeconds.value, type: 'status');
          }
        }),
        videoPlayerController!.stream.completed.listen((event) {
          if (event) {
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
        videoPlayerController!.stream.duration.listen((event) {
          duration.value = event;
        }),
        videoPlayerController!.stream.buffer.listen((event) {
          _buffered.value = event;
          updateBufferedSecond();
        }),
        videoPlayerController!.stream.buffering.listen((event) {
          isBuffering.value = event;
          videoPlayerServiceHandler.onStatusChange(
              playerStatus.status.value, event);
        }),
        // videoPlayerController!.stream.volume.listen((event) {
        //   if (!mute.value && _volumeBeforeMute != event) {
        //     _volumeBeforeMute = event / 100;
        //   }
        // }),
        // 媒体通知监听
        onPlayerStatusChanged.listen((event) {
          videoPlayerServiceHandler.onStatusChange(event, isBuffering.value);
        }),
        onPositionChanged.listen((event) {
          EasyThrottle.throttle(
              'mediaServicePositon',
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
    try {
      DanmakuOption currentOption = danmakuController!.option;
      defaultDuration ??= currentOption.duration;
      DanmakuOption updatedOption = currentOption.copyWith(
          duration: (defaultDuration! / speed) * playbackSpeed);
      danmakuController!.updateOption(updatedOption);
    } catch (_) {}
    // fix 长按倍速后放开不恢复
    if (!doubleSpeedStatus.value) {
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
  Future<void> play(
      {bool repeat = false, bool hideControls = true, dynamic duration}) async {
    // 播放时自动隐藏控制条
    controls = !hideControls;
    // repeat为true，将从头播放
    if (repeat) {
      await seekTo(Duration.zero);
    }
    await _videoPlayerController?.play();

    await getCurrentVolume();
    await getCurrentBrightness();

    playerStatus.status.value = PlayerStatus.playing;
    // screenManager.setOverlays(false);

    /// 临时fix _duration.value丢失
    if (duration != null) {
      _duration.value = duration;
      updateDurationSecond();
    }
    audioSessionHandler.setActive(true);
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
    _timer = Timer(const Duration(milliseconds: 3000), () {
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
  Future<void> getCurrentBrightness() async {
    try {
      _currentBrightness.value = await ScreenBrightness().current;
    } catch (e) {
      throw 'Failed to get current brightness';
      //return 0;
    }
  }

  Future<void> setBrightness(double brightnes) async {
    try {
      brightness.value = brightnes;
      ScreenBrightness().setScreenBrightness(brightnes);
      // setVideoBrightness();
    } catch (e) {
      throw 'Failed to set brightness';
    }
  }

  Future<void> resetBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (e) {
      throw 'Failed to reset brightness';
    }
  }

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
    // 由于none与scaleDown涉及视频原始尺寸，需要等待视频加载后再设置，否则尺寸会变为0，出现错误
    if (attr == BoxFit.none || attr == BoxFit.scaleDown) {
      if (buffered.value == Duration.zero) {
        attr = BoxFit.contain;
        _dataListenerForVideoFit = dataStatus.status.listen((status) {
          if (status == DataStatus.loaded) {
            _dataListenerForVideoFit.cancel();
            int fitValue =
                videoStorage.get(VideoBoxKey.cacheVideoFit, defaultValue: 0);
            var attr = videoFitType[fitValue]['attr'];
            if (attr == BoxFit.none || attr == BoxFit.scaleDown) {
              _videoFit.value = attr;
            }
          }
        });
      }
    }
    _videoFit.value = attr;
    _videoFitDesc.value = videoFitType[fitValue]['desc'];
  }

  /// 设置后台播放
  Future<void> setBackgroundPlay(bool val) async {
    _continuePlayInBackground.value = val;
    setting.put(SettingBoxKey.continuePlayInBackground, val);
    videoPlayerServiceHandler.revalidateSetting();
  }

  /// 读取亮度
  // Future<void> getVideoBrightness() async {
  //   double brightnessValue =
  //       videoStorage.get(VideoBoxKey.videoBrightness, defaultValue: 0.5);
  //   setBrightness(brightnessValue);
  // }

  set controls(bool visible) {
    _showControls.value = visible;
    _timer?.cancel();
    if (visible) {
      _hideTaskControls();
    }
  }

  void hiddenControls(bool val) {
    showControls.value = val;
  }

  /// 设置长按倍速状态 live模式下禁用
  void setDoubleSpeedStatus(bool val) {
    if (videoType.value == 'live') {
      return;
    }
    if (controlsLock.value) {
      return;
    }
    _doubleSpeedStatus.value = val;
    if (val) {
      setPlaybackSpeed(
          enableAutoLongPressSpeed ? playbackSpeed * 2 : longPressSpeed);
    } else {
      print(playbackSpeed);
      setPlaybackSpeed(playbackSpeed);
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

  // 全屏
  Future<void> triggerFullScreen({bool status = true}) async {
    FullScreenMode mode = FullScreenModeCode.fromCode(
        setting.get(SettingBoxKey.fullScreenMode, defaultValue: 0))!;
    if (!isFullScreen.value && status) {
      // StatusBarControl.setHidden(true, animation: StatusBarAnimation.FADE);
      hideStatusBar();

      /// 按照视频宽高比决定全屏方向
      toggleFullScreen(true);

      /// 进入全屏
      if (mode == FullScreenMode.none) {
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
      showStatusBar();
      toggleFullScreen(false);
      if (mode == FullScreenMode.none) {
        return;
      }
      if (!setting.get(SettingBoxKey.horizontalScreen, defaultValue: false)) {
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
    // 正常播放时，间隔5秒更新一次
    if (progress - _heartDuration >= 5) {
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
    localCache.put(LocalCacheKey.danmakuWeight, danmakuWeight.value);
    localCache.put(LocalCacheKey.danmakuBlockType, blockTypes);
    localCache.put(LocalCacheKey.danmakuShowArea, showArea);
    localCache.put(LocalCacheKey.danmakuOpacity, opacityVal);
    localCache.put(LocalCacheKey.danmakuFontScale, fontSizeVal);
    localCache.put(LocalCacheKey.danmakuDuration, danmakuDurationVal);
    localCache.put(LocalCacheKey.strokeWidth, strokeWidth);
  }

  Future<void> dispose({String type = 'single'}) async {
    // 每次减1，最后销毁
    if (type == 'single' && playerCount.value > 1) {
      _playerCount.value -= 1;
      _heartDuration = 0;
      pause();
      return;
    }
    _playerCount.value = 0;
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

      if (_videoPlayerController != null) {
        var pp = _videoPlayerController!.platform as NativePlayer;
        await pp.setProperty('audio-files', '');
        removeListeners();
        await _videoPlayerController?.dispose();
        _videoPlayerController = null;
      }
      _instance = null;
      // 关闭所有视频页面恢复亮度
      resetBrightness();
      videoPlayerServiceHandler.clear();
    } catch (err) {
      print(err);
    }
  }

  Future refreshSubtitles() async {
    _vttSubtitles.clear();
    Map res = await VideoHttp.subtitlesJson(bvid: _bvid, cid: _cid);
    if (!res["status"]) {
      SmartDialog.showToast('查询字幕错误，${res["msg"]}');
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

  // 设定字幕轨道
  setSubtitle(Map<String, String> s) {
    if (s['text'] == '') {
      _videoPlayerController?.setSubtitleTrack(SubtitleTrack.no());
      _vttSubtitlesIndex.value = 0;
      return;
    }
    _videoPlayerController?.setSubtitleTrack(SubtitleTrack.data(
      s['text']!,
      title: s['title']!,
      language: s['language']!,
    ));
    _vttSubtitlesIndex.value = _vttSubtitles.indexOf(s);
  }
}
