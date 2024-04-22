import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:ns_danmaku/ns_danmaku.dart';
import 'package:PiliPalaX/http/user.dart';
import 'package:PiliPalaX/models/video/play/quality.dart';
import 'package:PiliPalaX/models/video/play/url.dart';
import 'package:PiliPalaX/pages/video/detail/index.dart';
import 'package:PiliPalaX/pages/video/detail/introduction/widgets/menu_row.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/http/danmaku.dart';
import 'package:PiliPalaX/services/shutdown_timer_service.dart';
import '../../../../models/video_detail_res.dart';
import '../../../../services/service_locator.dart';
import '../introduction/index.dart';
import 'package:marquee/marquee.dart';
import '../../../danmaku/controller.dart';

class HeaderControl extends StatefulWidget implements PreferredSizeWidget {
  const HeaderControl({
    this.controller,
    this.videoDetailCtr,
    this.floating,
    super.key,
  });
  final PlPlayerController? controller;
  final VideoDetailController? videoDetailCtr;
  final Floating? floating;

  @override
  State<HeaderControl> createState() => _HeaderControlState();

  @override
  Size get preferredSize => throw UnimplementedError();
}

class _HeaderControlState extends State<HeaderControl> {
  late PlayUrlModel videoInfo;
  List<PlaySpeed> playSpeed = PlaySpeed.values;
  static const TextStyle subTitleStyle = TextStyle(fontSize: 12);
  static const TextStyle titleStyle = TextStyle(fontSize: 14);
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);
  final Box<dynamic> localCache = GStrorage.localCache;
  final Box<dynamic> videoStorage = GStrorage.video;
  double buttonSpace = 8;
  bool isFullScreen = false;
  late String heroTag;
  late VideoIntroController videoIntroController;
  late VideoDetailData videoDetail;
  late StreamSubscription<bool> fullScreenStatusListener;
  late bool horizontalScreen;
  RxString now = ''.obs;
  late Timer clock;

  @override
  void initState() {
    super.initState();
    videoInfo = widget.videoDetailCtr!.data;
    listenFullScreenStatus();
    if (Get.arguments != null) {
      heroTag = Get.arguments['heroTag'];
    }
    videoIntroController = Get.put(VideoIntroController(), tag: heroTag);
    horizontalScreen =
        setting.get(SettingBoxKey.horizontalScreen, defaultValue: false);
    startClock();
  }

  void listenFullScreenStatus() {
    fullScreenStatusListener = widget
        .videoDetailCtr!.plPlayerController.isFullScreen
        .listen((bool status) {
      isFullScreen = status;

      /// TODO setState() called after dispose()
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    widget.floating?.dispose();
    fullScreenStatusListener.cancel();
    clock.cancel();
    super.dispose();
  }

  /// 设置面板
  void showSettingSheet() {
    showModalBottomSheet(
      elevation: 0,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          width: double.infinity,
          height: 460,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          margin: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 35,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withOpacity(0.5),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(3))),
                  ),
                ),
              ),
              Expanded(
                  child: Material(
                child: ListView(
                  children: [
                    // ListTile(
                    //   onTap: () {},
                    //   dense: true,
                    //   enabled: false,
                    //   leading:
                    //       const Icon(Icons.network_cell_outlined, size: 20),
                    //   title: Text('省流模式', style: titleStyle),
                    //   subtitle: Text('低画质 ｜ 减少视频缓存', style: subTitleStyle),
                    //   trailing: Transform.scale(
                    //     scale: 0.75,
                    //     child: Switch(
                    //       thumbIcon: MaterialStateProperty.resolveWith<Icon?>(
                    //           (Set<MaterialState> states) {
                    //         if (states.isNotEmpty &&
                    //             states.first == MaterialState.selected) {
                    //           return const Icon(Icons.done);
                    //         }
                    //         return null; // All other states will use the default thumbIcon.
                    //       }),
                    //       value: false,
                    //       onChanged: (value) => {},
                    //     ),
                    //   ),
                    // ),
                    ListTile(
                      onTap: () async {
                        final res = await UserHttp.toViewLater(
                            bvid: widget.videoDetailCtr!.bvid);
                        SmartDialog.showToast(res['msg']);
                        Get.back();
                      },
                      dense: true,
                      leading: const Icon(Icons.watch_later_outlined, size: 20),
                      title: const Text('添加至「稍后再看」', style: titleStyle),
                    ),
                    ListTile(
                      onTap: () => {Get.back(), scheduleExit()},
                      dense: true,
                      leading:
                          const Icon(Icons.hourglass_top_outlined, size: 20),
                      title: const Text('定时关闭（测试）', style: titleStyle),
                    ),
                    ListTile(
                      onTap: () => {Get.back(), showSetVideoQa()},
                      dense: true,
                      leading: const Icon(Icons.play_circle_outline, size: 20),
                      title: const Text('选择画质', style: titleStyle),
                      subtitle: Text(
                          '当前画质 ${widget.videoDetailCtr!.currentVideoQa.description}',
                          style: subTitleStyle),
                    ),
                    if (widget.videoDetailCtr!.currentAudioQa != null)
                      ListTile(
                        onTap: () => {Get.back(), showSetAudioQa()},
                        dense: true,
                        leading: const Icon(Icons.album_outlined, size: 20),
                        title: const Text('选择音质', style: titleStyle),
                        subtitle: Text(
                            '当前音质 ${widget.videoDetailCtr!.currentAudioQa!.description}',
                            style: subTitleStyle),
                      ),
                    ListTile(
                      onTap: () => {Get.back(), showSetDecodeFormats()},
                      dense: true,
                      leading: const Icon(Icons.av_timer_outlined, size: 20),
                      title: const Text('解码格式', style: titleStyle),
                      subtitle: Text(
                          '当前解码格式 ${widget.videoDetailCtr!.currentDecodeFormats.description}',
                          style: subTitleStyle),
                    ),
                    ListTile(
                      onTap: () => {Get.back(), showSetRepeat()},
                      dense: true,
                      leading: const Icon(Icons.repeat, size: 20),
                      title: const Text('播放顺序', style: titleStyle),
                      subtitle: Text(widget.controller!.playRepeat.description,
                          style: subTitleStyle),
                    ),
                    ListTile(
                      onTap: () => {Get.back(), showSetDanmaku()},
                      dense: true,
                      leading: const Icon(Icons.subtitles_outlined, size: 20),
                      title: const Text('弹幕设置', style: titleStyle),
                    ),
                  ],
                ),
              ))
            ],
          ),
        );
      },
      clipBehavior: Clip.hardEdge,
      isScrollControlled: true,
    );
  }

  /// 发送弹幕
  void showShootDanmakuSheet() {
    final TextEditingController textController = TextEditingController();
    bool isSending = false; // 追踪是否正在发送
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        // TODO: 支持更多类型和颜色的弹幕
        return AlertDialog(
          title: const Text('发送弹幕（测试）'),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return TextField(
              controller: textController,
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return TextButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final String msg = textController.text;
                        if (msg.isEmpty) {
                          SmartDialog.showToast('弹幕内容不能为空');
                          return;
                        } else if (msg.length > 100) {
                          SmartDialog.showToast('弹幕内容不能超过100个字符');
                          return;
                        }
                        setState(() {
                          isSending = true; // 开始发送，更新状态
                        });
                        //修改按钮文字
                        // SmartDialog.showToast('弹幕发送中,\n$msg');
                        final dynamic res = await DanmakaHttp.shootDanmaku(
                          oid: widget.videoDetailCtr!.cid.value,
                          msg: textController.text,
                          bvid: widget.videoDetailCtr!.bvid,
                          progress:
                              widget.controller!.position.value.inMilliseconds,
                          type: 1,
                        );
                        setState(() {
                          isSending = false; // 发送结束，更新状态
                        });
                        if (res['status']) {
                          SmartDialog.showToast('发送成功');
                          // 发送成功，自动预览该弹幕，避免重新请求
                          // TODO: 暂停状态下预览弹幕仍会移动与计时，可考虑添加到dmSegList或其他方式实现
                          widget.controller!.danmakuController!.addItems([
                            DanmakuItem(
                              msg,
                              color: Colors.white,
                              time: widget
                                  .controller!.position.value.inMilliseconds,
                              type: DanmakuItemType.scroll,
                              isSend: true,
                            )
                          ]);
                          Get.back();
                        } else {
                          SmartDialog.showToast('发送失败，错误信息为${res['msg']}');
                        }
                      },
                child: Text(isSending ? '发送中...' : '发送'),
              );
            })
          ],
        );
      },
    );
  }

  /// 定时关闭
  void scheduleExit() async {
    const List<int> scheduleTimeChoices = [
      -1,
      15,
      30,
      60,
    ];
    showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Container(
            width: double.infinity,
            height: 500,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.only(left: 14, right: 14),
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 30),
                      const Center(child: Text('定时关闭', style: titleStyle)),
                      const SizedBox(height: 10),
                      for (final int choice in scheduleTimeChoices) ...<Widget>[
                        ListTile(
                          onTap: () {
                            shutdownTimerService.scheduledExitInMinutes =
                                choice;
                            shutdownTimerService.startShutdownTimer();
                            Get.back();
                          },
                          contentPadding: const EdgeInsets.only(),
                          dense: true,
                          title: Text(choice == -1 ? "禁用" : "$choice分钟后"),
                          trailing: shutdownTimerService
                                      .scheduledExitInMinutes ==
                                  choice
                              ? Icon(
                                  Icons.done,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : const SizedBox(),
                        )
                      ],
                      const SizedBox(height: 6),
                      const Center(
                          child: SizedBox(
                        width: 100,
                        child: Divider(height: 1),
                      )),
                      const SizedBox(height: 10),
                      ListTile(
                        onTap: () {
                          shutdownTimerService.waitForPlayingCompleted =
                              !shutdownTimerService.waitForPlayingCompleted;
                          setState(() {});
                        },
                        dense: true,
                        contentPadding: const EdgeInsets.only(),
                        title: const Text("额外等待视频播放完毕", style: titleStyle),
                        trailing: Switch(
                          // thumb color (round icon)
                          activeColor: Theme.of(context).colorScheme.primary,
                          activeTrackColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          inactiveThumbColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          inactiveTrackColor:
                              Theme.of(context).colorScheme.background,
                          splashRadius: 10.0,
                          // boolean variable value
                          value: shutdownTimerService.waitForPlayingCompleted,
                          // changes the state of the switch
                          onChanged: (value) => setState(() =>
                              shutdownTimerService.waitForPlayingCompleted =
                                  value),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          const Text('倒计时结束:', style: titleStyle),
                          const Spacer(),
                          ActionRowLineItem(
                            onTap: () {
                              shutdownTimerService.exitApp = false;
                              setState(() {});
                              // Get.back();
                            },
                            text: " 暂停视频 ",
                            selectStatus: !shutdownTimerService.exitApp,
                          ),
                          const Spacer(),
                          // const SizedBox(width: 10),
                          ActionRowLineItem(
                            onTap: () {
                              shutdownTimerService.exitApp = true;
                              setState(() {});
                              // Get.back();
                            },
                            text: " 退出APP ",
                            selectStatus: shutdownTimerService.exitApp,
                          )
                        ],
                      ),
                    ]),
              ),
            ),
          );
        });
      },
    );
  }

  /// 选择画质
  void showSetVideoQa() {
    final List<FormatItem> videoFormat = videoInfo.supportFormats!;
    final VideoQuality currentVideoQa = widget.videoDetailCtr!.currentVideoQa;

    /// 总质量分类
    final int totalQaSam = videoFormat.length;

    /// 可用的质量分类
    int userfulQaSam = 0;
    final List<VideoItem> video = videoInfo.dash!.video!;
    final Set<int> idSet = {};
    for (final VideoItem item in video) {
      final int id = item.id!;
      if (!idSet.contains(id)) {
        idSet.add(id);
        userfulQaSam++;
      }
    }

    showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,
          height: 310,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          margin: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 45,
                child: GestureDetector(
                  onTap: () {
                    SmartDialog.showToast('标灰画质可能需要bilibili会员');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('选择画质', style: titleStyle),
                      SizedBox(width: buttonSpace),
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      )
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  child: Scrollbar(
                    child: ListView(
                      children: [
                        for (int i = 0; i < totalQaSam; i++) ...[
                          ListTile(
                            onTap: () {
                              if (currentVideoQa.code ==
                                  videoFormat[i].quality) {
                                return;
                              }
                              final int quality = videoFormat[i].quality!;
                              widget.videoDetailCtr!.currentVideoQa =
                                  VideoQualityCode.fromCode(quality)!;
                              String oldQualityDesc = VideoQualityCode.fromCode(
                                      setting.get(SettingBoxKey.defaultVideoQa,
                                          defaultValue:
                                              VideoQuality.values.last.code))!
                                  .description;
                              setting.put(
                                  SettingBoxKey.defaultVideoQa, quality);
                              SmartDialog.showToast(
                                  "默认画质由：$oldQualityDesc 变为：${VideoQualityCode.fromCode(quality)!.description}");
                              widget.videoDetailCtr!.updatePlayer();
                              Get.back();
                            },
                            dense: true,
                            // 可能包含会员解锁画质
                            enabled: i >= totalQaSam - userfulQaSam,
                            contentPadding:
                                const EdgeInsets.only(left: 20, right: 20),
                            title: Text(videoFormat[i].newDesc!),
                            trailing: currentVideoQa.code ==
                                    videoFormat[i].quality
                                ? Icon(
                                    Icons.done,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : Text(
                                    videoFormat[i].format!,
                                    style: subTitleStyle,
                                  ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 选择音质
  void showSetAudioQa() {
    final AudioQuality currentAudioQa = widget.videoDetailCtr!.currentAudioQa!;
    final List<AudioItem> audio = videoInfo.dash!.audio!;
    showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,
          height: 250,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          margin: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              const SizedBox(
                  height: 45,
                  child: Center(child: Text('选择音质', style: titleStyle))),
              Expanded(
                child: Material(
                  child: ListView(
                    children: <Widget>[
                      for (final AudioItem i in audio) ...<Widget>[
                        ListTile(
                          onTap: () {
                            if (currentAudioQa.code == i.id) {
                              return;
                            }
                            final int quality = i.id!;
                            widget.videoDetailCtr!.currentAudioQa =
                                AudioQualityCode.fromCode(quality)!;
                            String oldQualityDesc = AudioQualityCode.fromCode(
                                    setting.get(SettingBoxKey.defaultAudioQa,
                                        defaultValue:
                                            AudioQuality.values.last.code))!
                                .description;
                            setting.put(SettingBoxKey.defaultAudioQa, quality);
                            SmartDialog.showToast(
                                "默认音质由：$oldQualityDesc 变为：${AudioQualityCode.fromCode(quality)!.description}");
                            widget.videoDetailCtr!.updatePlayer();
                            Get.back();
                          },
                          dense: true,
                          contentPadding:
                              const EdgeInsets.only(left: 20, right: 20),
                          title: Text(i.quality!),
                          subtitle: Text(
                            i.codecs!,
                            style: subTitleStyle,
                          ),
                          trailing: currentAudioQa.code == i.id
                              ? Icon(
                                  Icons.done,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : const SizedBox(),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 选择解码格式
  void showSetDecodeFormats() {
    // 当前选中的解码格式
    final VideoDecodeFormats currentDecodeFormats =
        widget.videoDetailCtr!.currentDecodeFormats;
    final VideoItem firstVideo = widget.videoDetailCtr!.firstVideo;
    // 当前视频可用的解码格式
    final List<FormatItem> videoFormat = videoInfo.supportFormats!;
    final List list = videoFormat
        .firstWhere((FormatItem e) => e.quality == firstVideo.quality!.code)
        .codecs!;

    showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,
          height: 250,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          margin: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(
                  height: 45,
                  child: Center(child: Text('选择解码格式', style: titleStyle))),
              Expanded(
                child: Material(
                  child: ListView(
                    children: [
                      for (var i in list) ...[
                        ListTile(
                          onTap: () {
                            if (i.startsWith(currentDecodeFormats.code)) return;
                            widget.videoDetailCtr!.currentDecodeFormats =
                                VideoDecodeFormatsCode.fromString(i)!;
                            widget.videoDetailCtr!.updatePlayer();
                            Get.back();
                          },
                          dense: true,
                          contentPadding:
                              const EdgeInsets.only(left: 20, right: 20),
                          title: Text(VideoDecodeFormatsCode.fromString(i)!
                              .description!),
                          subtitle: Text(
                            i!,
                            style: subTitleStyle,
                          ),
                          trailing: i.startsWith(currentDecodeFormats.code)
                              ? Icon(
                                  Icons.done,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : const SizedBox(),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 弹幕功能
  void showSetDanmaku() async {
    // 屏蔽类型
    final List<Map<String, dynamic>> blockTypesList = [
      {'value': 5, 'label': '顶部'},
      {'value': 2, 'label': '滚动'},
      {'value': 4, 'label': '底部'},
      {'value': 6, 'label': '彩色'},
    ];
    final List blockTypes = widget.controller!.blockTypes;
    // 显示区域
    final List<Map<String, dynamic>> showAreas = [
      {'value': 0.25, 'label': '1/4屏'},
      {'value': 0.5, 'label': '半屏'},
      {'value': 0.75, 'label': '3/4屏'},
      {'value': 1.0, 'label': '满屏'},
    ];
    // 智能云屏蔽
    int danmakuWeight = widget.controller!.danmakuWeight.value;
    // 显示区域
    double showArea = widget.controller!.showArea;
    // 不透明度
    double opacityVal = widget.controller!.opacityVal;
    // 字体大小
    double fontSizeVal = widget.controller!.fontSizeVal;
    // 弹幕速度
    double danmakuDurationVal = widget.controller!.danmakuDurationVal;
    // 弹幕描边
    double strokeWidth = widget.controller!.strokeWidth;

    final DanmakuController danmakuController =
        widget.controller!.danmakuController!;
    await showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Container(
            width: double.infinity,
            height: 580,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.only(left: 14, right: 14),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 45,
                    child: Center(child: Text('弹幕设置', style: titleStyle)),
                  ),
                  const SizedBox(height: 10),
                  Text('智能云屏蔽 $danmakuWeight 级'),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackShape: MSliderTrackShape(),
                        thumbColor: Theme.of(context).colorScheme.primary,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        trackHeight: 10,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        min: 0,
                        max: 10,
                        value: danmakuWeight.toDouble(),
                        divisions: 10,
                        label: '$danmakuWeight',
                        onChanged: (double val) {
                          danmakuWeight = val.toInt();
                          widget.controller!.danmakuWeight.value =
                              danmakuWeight;
                          widget.controller!.putDanmakuSettings();
                          setState(() {});
                          // try {
                          //   final DanmakuOption currentOption =
                          //       danmakuController.option;
                          //   final DanmakuOption updatedOption =
                          //   currentOption.copyWith(strokeWidth: val);
                          //   danmakuController.updateOption(updatedOption);
                          // } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  const Text('按类型屏蔽'),
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 18),
                    child: Row(
                      children: <Widget>[
                        for (final Map<String, dynamic> i
                            in blockTypesList) ...<Widget>[
                          ActionRowLineItem(
                            onTap: () async {
                              final bool isChoose =
                                  blockTypes.contains(i['value']);
                              if (isChoose) {
                                blockTypes.remove(i['value']);
                              } else {
                                blockTypes.add(i['value']);
                              }
                              widget.controller!.blockTypes = blockTypes;
                              widget.controller?.putDanmakuSettings();
                              setState(() {});
                              try {
                                final DanmakuOption currentOption =
                                    danmakuController.option;
                                final DanmakuOption updatedOption =
                                    currentOption.copyWith(
                                  hideTop: blockTypes.contains(5),
                                  hideBottom: blockTypes.contains(4),
                                  hideScroll: blockTypes.contains(2),
                                  // 添加或修改其他需要修改的选项属性
                                );
                                danmakuController.updateOption(updatedOption);
                              } catch (_) {}
                            },
                            text: i['label'],
                            selectStatus: blockTypes.contains(i['value']),
                          ),
                          const SizedBox(width: 10),
                        ]
                      ],
                    ),
                  ),
                  const Text('显示区域'),
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 18),
                    child: Row(
                      children: [
                        for (final Map<String, dynamic> i in showAreas) ...[
                          ActionRowLineItem(
                            onTap: () {
                              showArea = i['value'];
                              widget.controller!.showArea = showArea;
                              widget.controller?.putDanmakuSettings();
                              setState(() {});
                              try {
                                final DanmakuOption currentOption =
                                    danmakuController.option;
                                final DanmakuOption updatedOption =
                                    currentOption.copyWith(area: i['value']);
                                danmakuController.updateOption(updatedOption);
                              } catch (_) {}
                            },
                            text: i['label'],
                            selectStatus: showArea == i['value'],
                          ),
                          const SizedBox(width: 10),
                        ]
                      ],
                    ),
                  ),
                  Text('不透明度 ${opacityVal * 100}%'),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackShape: MSliderTrackShape(),
                        thumbColor: Theme.of(context).colorScheme.primary,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        trackHeight: 10,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        min: 0,
                        max: 1,
                        value: opacityVal,
                        divisions: 10,
                        label: '${opacityVal * 100}%',
                        onChanged: (double val) {
                          opacityVal = val;
                          widget.controller!.opacityVal = opacityVal;
                          widget.controller?.putDanmakuSettings();
                          setState(() {});
                          try {
                            final DanmakuOption currentOption =
                                danmakuController.option;
                            final DanmakuOption updatedOption =
                                currentOption.copyWith(opacity: val);
                            danmakuController.updateOption(updatedOption);
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  Text('描边粗细 $strokeWidth'),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackShape: MSliderTrackShape(),
                        thumbColor: Theme.of(context).colorScheme.primary,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        trackHeight: 10,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        min: 0,
                        max: 3,
                        value: strokeWidth,
                        divisions: 6,
                        label: '$strokeWidth',
                        onChanged: (double val) {
                          strokeWidth = val;
                          widget.controller!.strokeWidth = val;
                          widget.controller?.putDanmakuSettings();
                          setState(() {});
                          try {
                            final DanmakuOption currentOption =
                                danmakuController.option;
                            final DanmakuOption updatedOption =
                                currentOption.copyWith(strokeWidth: val);
                            danmakuController.updateOption(updatedOption);
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  Text('字体大小 ${(fontSizeVal * 100).toStringAsFixed(1)}%'),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackShape: MSliderTrackShape(),
                        thumbColor: Theme.of(context).colorScheme.primary,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        trackHeight: 10,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        min: 0.5,
                        max: 2.5,
                        value: fontSizeVal,
                        divisions: 20,
                        label: '${(fontSizeVal * 100).toStringAsFixed(1)}%',
                        onChanged: (double val) {
                          fontSizeVal = val;
                          widget.controller!.fontSizeVal = fontSizeVal;
                          widget.controller?.putDanmakuSettings();
                          setState(() {});
                          try {
                            final DanmakuOption currentOption =
                                danmakuController.option;
                            final DanmakuOption updatedOption =
                                currentOption.copyWith(
                              fontSize: (15 * fontSizeVal).toDouble(),
                            );
                            danmakuController.updateOption(updatedOption);
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                  Text('弹幕时长 $danmakuDurationVal 秒'),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackShape: MSliderTrackShape(),
                        thumbColor: Theme.of(context).colorScheme.primary,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        trackHeight: 10,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0),
                      ),
                      child: Slider(
                        min: 1,
                        max: 6,
                        value: sqrt(danmakuDurationVal),
                        divisions: 50,
                        label: danmakuDurationVal.toString(),
                        onChanged: (double val) {
                          danmakuDurationVal = (val * val).toPrecision(2);
                          widget.controller!.danmakuDurationVal =
                              danmakuDurationVal;
                          widget.controller?.putDanmakuSettings();
                          setState(() {});
                          try {
                            final DanmakuOption updatedOption =
                                danmakuController.option.copyWith(
                                    duration: danmakuDurationVal /
                                        widget.controller!.playbackSpeed);
                            danmakuController.updateOption(updatedOption);
                          } catch (_) {}
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  /// 播放顺序
  void showSetRepeat() async {
    showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,
          height: 250,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
          margin: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(
                  height: 45,
                  child: Center(child: Text('选择播放顺序', style: titleStyle))),
              Expanded(
                child: Material(
                  child: ListView(
                    children: <Widget>[
                      for (final PlayRepeat i in PlayRepeat.values) ...[
                        ListTile(
                          onTap: () {
                            widget.controller!.setPlayRepeat(i);
                            Get.back();
                          },
                          dense: true,
                          contentPadding:
                              const EdgeInsets.only(left: 20, right: 20),
                          title: Text(i.description),
                          trailing: widget.controller!.playRepeat == i
                              ? Icon(
                                  Icons.done,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : const SizedBox(),
                        )
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  startClock() {
    clock = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        return;
      }
      now.value = DateTime.now().toString().split(' ')[1].substring(0, 5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final _ = widget.controller!;
    // final bool isLandscape =
    //     MediaQuery.of(context).orientation == Orientation.landscape;

    return LayoutBuilder(builder: (context, boxConstraints) {
      return AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        primary: false,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 10,
        title: Row(
          children: [
            SizedBox(
                width: 42,
                height: 34,
                child: IconButton(
                  tooltip: '上一页',
                  icon: const Icon(
                    FontAwesomeIcons.arrowLeft,
                    size: 15,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (widget.controller!.isFullScreen.value) {
                      widget.controller!.triggerFullScreen(status: false);
                    } else if (MediaQuery.of(context).orientation ==
                            Orientation.landscape &&
                        !horizontalScreen) {
                      verticalScreenForTwoSeconds();
                    } else {
                      Get.back();
                    }
                  },
                )),
            if ((videoIntroController.videoDetail.value.title != null) &&
                (isFullScreen ||
                    (!isFullScreen &&
                        MediaQuery.of(context).orientation ==
                            Orientation.landscape &&
                        !horizontalScreen))) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: boxConstraints.maxWidth / 2 - 60,
                        maxHeight: 25),
                    child: Marquee(
                      text: videoIntroController.videoDetail.value.title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      scrollAxis: Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      blankSpace: 200,
                      velocity: 40,
                      startAfter: const Duration(seconds: 1),
                      showFadingOnlyWhenScrolling: true,
                      fadingEdgeStartFraction: 0,
                      fadingEdgeEndFraction: 0.1,
                      numberOfRounds: 1,
                      startPadding: 0,
                      accelerationDuration: const Duration(seconds: 1),
                      accelerationCurve: Curves.linear,
                      decelerationDuration: const Duration(milliseconds: 500),
                      decelerationCurve: Curves.easeOut,
                    ),
                  ),
                  if (videoIntroController.isShowOnlineTotal)
                    Text(
                      '${videoIntroController.total.value}人正在看',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    )
                ],
              ),
            ] else ...[
              SizedBox(
                  width: 42,
                  height: 34,
                  child: IconButton(
                    tooltip: '返回主页',
                    icon: const Icon(
                      FontAwesomeIcons.house,
                      size: 15,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      // 销毁播放器实例
                      // await widget.controller!.dispose(type: 'all');
                      if (mounted) {
                        Navigator.popUntil(
                            context, (Route<dynamic> route) => route.isFirst);
                      }
                    },
                  )),
            ],
            const Spacer(),
            if ((isFullScreen &&
                    MediaQuery.of(context).orientation ==
                        Orientation.landscape) ||
                (!isFullScreen &&
                    MediaQuery.of(context).orientation ==
                        Orientation.landscape &&
                    !horizontalScreen)) ...[
              // const Spacer(),
              // show current datetime
              Obx(
                () => Text(
                  now.value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(
                width: 15,
              ),
            ],
            // ComBtn(
            //   icon: const Icon(
            //     FontAwesomeIcons.cropSimple,
            //     size: 15,
            //     color: Colors.white,
            //   ),
            //   fuc: () => _.screenshot(),
            // ),
            SizedBox(
              width: 42,
              height: 34,
              child: IconButton(
                tooltip: '发弹幕',
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () => showShootDanmakuSheet(),
                icon: const Icon(
                  Icons.add_comment_outlined,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(
              width: 42,
              height: 34,
              child: Obx(
                () => IconButton(
                  tooltip: "${_.isOpenDanmu.value ? '关闭' : '开启'}弹幕",
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () {
                    _.isOpenDanmu.value = !_.isOpenDanmu.value;
                    setting.put(
                        SettingBoxKey.enableShowDanmaku, _.isOpenDanmu.value);
                    SmartDialog.showToast(
                        "已${_.isOpenDanmu.value ? '开启' : '关闭'}弹幕",
                        displayTime: const Duration(seconds: 1));
                  },
                  icon: Icon(
                    _.isOpenDanmu.value
                        ? Icons.comment_outlined
                        : Icons.comments_disabled_outlined,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (Platform.isAndroid)
              SizedBox(
                width: 42,
                height: 34,
                child: IconButton(
                  tooltip: '画中画',
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () async {
                    bool canUsePiP = widget.floating != null &&
                        await widget.floating!.isPipAvailable;
                    widget.controller!.hiddenControls(false);
                    if (canUsePiP) {
                      bool enableBackgroundPlay = setting.get(
                          SettingBoxKey.enableBackgroundPlay,
                          defaultValue: true);
                      if (!enableBackgroundPlay) {
                        // SmartDialog.showToast('建议开启【后台播放】功能\n避免画中画没有暂停按钮');
                        // await Future.delayed(const Duration(seconds: 2), () {
                        // });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Column(children: <Widget>[
                              const Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 10),
                                  Text('画中画',
                                      style:
                                          TextStyle(fontSize: 15, height: 1.5))
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                  '建议开启【后台音频服务】\n'
                                  '避免画中画没有暂停按钮',
                                  style:
                                      TextStyle(fontSize: 12.5, height: 1.5)),
                              Row(children: [
                                TextButton(
                                    style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStateProperty.resolveWith(
                                              (states) {
                                        return Theme.of(context)
                                            .snackBarTheme
                                            .actionTextColor;
                                      }),
                                    ),
                                    onPressed: () async {
                                      _.setBackgroundPlay(true);
                                      SmartDialog.showToast("请重新载入本页面刷新");
                                      // Get.back();
                                    },
                                    child: const Text('启用后台音频服务')),
                                const SizedBox(width: 10),
                                TextButton(
                                    style: ButtonStyle(
                                      foregroundColor:
                                          MaterialStateProperty.resolveWith(
                                              (states) {
                                        return Theme.of(context)
                                            .snackBarTheme
                                            .actionTextColor;
                                      }),
                                    ),
                                    onPressed: () {},
                                    child: const Text('不启用'))
                              ])
                            ]),
                            duration: const Duration(seconds: 2),
                            showCloseIcon: true,
                          ),
                        );
                        await Future.delayed(const Duration(seconds: 3), () {});
                      }
                      final Rational aspectRatio = Rational(
                        widget.videoDetailCtr!.data.dash!.video!.first.width!,
                        widget.videoDetailCtr!.data.dash!.video!.first.height!,
                      );
                      await widget.floating!.enable(aspectRatio: aspectRatio);
                    } else {}
                  },
                  icon: const Icon(
                    Icons.picture_in_picture_outlined,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
            SizedBox(
              width: 42,
              height: 34,
              child: IconButton(
                tooltip: "更多设置",
                style: ButtonStyle(
                  padding: MaterialStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () => showSettingSheet(),
                icon: const Icon(
                  Icons.more_vert_outlined,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class MSliderTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    SliderThemeData? sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const double trackHeight = 3;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2 + 4;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
