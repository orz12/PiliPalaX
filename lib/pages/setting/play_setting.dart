import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/services/service_locator.dart';
import 'package:PiliPalaX/utils/storage.dart';

import '../../models/video/play/subtitle.dart';
import 'widgets/switch_item.dart';

class PlaySetting extends StatefulWidget {
  const PlaySetting({super.key});

  @override
  State<PlaySetting> createState() => _PlaySettingState();
}

class _PlaySettingState extends State<PlaySetting> {
  Box setting = GStrorage.setting;
  late String defaultSubtitlePreference;
  late int defaultFullScreenMode;
  late int defaultBtmProgressBehavior;

  @override
  void initState() {
    super.initState();
    defaultFullScreenMode = setting.get(SettingBoxKey.fullScreenMode,
        defaultValue: FullScreenMode.values.first.code);
    defaultBtmProgressBehavior = setting.get(SettingBoxKey.btmProgressBehavior,
        defaultValue: BtmProgresBehavior.values.first.code);
    defaultSubtitlePreference = setting.get(SettingBoxKey.subtitlePreference,
        defaultValue: SubtitlePreference.values.first.code);
  }

  @override
  void dispose() {
    super.dispose();

    // 重新验证媒体通知后台播放设置
    videoPlayerServiceHandler.revalidateSetting();
  }

  @override
  Widget build(BuildContext context) {
    TextStyle titleStyle = Theme.of(context).textTheme.titleMedium!;
    TextStyle subTitleStyle = Theme.of(context)
        .textTheme
        .labelMedium!
        .copyWith(color: Theme.of(context).colorScheme.outline);
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          '播放器设置',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        children: [
          const SetSwitchItem(
            title: '弹幕开关',
            subTitle: '是否展示弹幕',
            leading: Icon(Icons.comment_outlined),
            setKey: SettingBoxKey.enableShowDanmaku,
            defaultVal: false,
          ),
          ListTile(
            dense: false,
            onTap: () => Get.toNamed('/playSpeedSet'),
            leading: const Icon(Icons.speed_outlined),
            title: Text('倍速设置', style: titleStyle),
            subtitle: Text('设置视频播放速度', style: subTitleStyle),
          ),
          const SetSwitchItem(
            title: '自动播放',
            subTitle: '进入详情页自动播放',
            leading: Icon(Icons.motion_photos_auto_outlined),
            setKey: SettingBoxKey.autoPlayEnable,
            defaultVal: true,
          ),
          const SetSwitchItem(
            title: '双击快退/快进',
            subTitle: '左侧双击快退，右侧双击快进',
            leading: Icon(Icons.touch_app_outlined),
            setKey: SettingBoxKey.enableQuickDouble,
            defaultVal: true,
          ),
          ListTile(
            dense: false,
            title: Text('自动启用字幕', style: titleStyle),
            leading: const Icon(Icons.closed_caption_outlined),
            subtitle: Text(
                '当前选择偏好：'
                '${SubtitlePreferenceCode.fromCode(defaultSubtitlePreference)!.description}',
                style: subTitleStyle),
            onTap: () async {
              String? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<String>(
                      title: '字幕选择偏好',
                      value: setting.get(SettingBoxKey.subtitlePreference,
                          defaultValue: SubtitlePreference.values.first.code),
                      values: SubtitlePreference.values.map((e) {
                        return {'title': e.description, 'value': e.code};
                      }).toList());
                },
              );
              if (result != null) {
                setting.put(SettingBoxKey.subtitlePreference, result);
                defaultSubtitlePreference = result;
                setState(() {});
              }
            },
          ),
          const SetSwitchItem(
            title: '竖屏扩大展示',
            subTitle: '小屏竖屏视频宽高比由16:9扩大至1:1（不支持收起）；横屏适配时，扩大至9:16',
            leading: Icon(Icons.expand_outlined),
            setKey: SettingBoxKey.enableVerticalExpand,
            defaultVal: false,
          ),
          const SetSwitchItem(
            title: '自动全屏',
            subTitle: '视频开始播放时进入全屏',
            leading: Icon(Icons.fullscreen_outlined),
            setKey: SettingBoxKey.enableAutoEnter,
            defaultVal: false,
          ),
          const SetSwitchItem(
            title: '自动退出全屏',
            subTitle: '视频结束播放时退出全屏',
            leading: Icon(Icons.fullscreen_exit_outlined),
            setKey: SettingBoxKey.enableAutoExit,
            defaultVal: true,
          ),
          const SetSwitchItem(
            title: '全向旋转',
            subTitle: '小屏可受重力转为临时全屏，若系统锁定旋转仍触发请关闭，关闭会影响横屏适配',
            leading: Icon(Icons.screen_rotation_alt_outlined),
            setKey: SettingBoxKey.allowRotateScreen,
            defaultVal: true,
          ),
          const SetSwitchItem(
            title: '后台播放',
            subTitle: '进入后台时继续播放',
            leading: Icon(Icons.motion_photos_pause_outlined),
            setKey: SettingBoxKey.continuePlayInBackground,
            defaultVal: false,
          ),
          if (Platform.isAndroid)
            SetSwitchItem(
                title: '后台画中画',
                subTitle: '进入后台时以小窗形式（PiP）播放',
                leading: const Icon(Icons.picture_in_picture_outlined),
                setKey: SettingBoxKey.autoPiP,
                defaultVal: false,
                callFn: (val) {
                  if (val &&
                      !setting.get(SettingBoxKey.enableBackgroundPlay,
                          defaultValue: true)) {
                    SmartDialog.showToast('建议开启后台音频服务');
                  }
                }),
          if (Platform.isAndroid)
            const SetSwitchItem(
              title: '画中画不加载弹幕',
              subTitle: '当弹幕开关开启时，小窗屏蔽弹幕以获得较好的体验',
              leading: Icon(Icons.comments_disabled_outlined),
              setKey: SettingBoxKey.pipNoDanmaku,
              defaultVal: true,
            ),
          const SetSwitchItem(
            title: '全屏手势反向',
            subTitle: '默认播放器中部向上滑动进入全屏，向下退出\n开启后向下全屏，向上退出',
            leading: Icon(Icons.swap_vert_outlined),
            setKey: SettingBoxKey.fullScreenGestureReverse,
            defaultVal: false,
          ),
          const SetSwitchItem(
            title: '观看人数',
            subTitle: '展示同时在看人数',
            leading: Icon(Icons.people_outlined),
            setKey: SettingBoxKey.enableOnlineTotal,
            defaultVal: false,
          ),
          ListTile(
            dense: false,
            title: Text('默认全屏方向', style: titleStyle),
            leading: const Icon(Icons.open_with_outlined),
            subtitle: Text(
              '当前全屏方向：${FullScreenModeCode.fromCode(defaultFullScreenMode)!.description}',
              style: subTitleStyle,
            ),
            onTap: () async {
              int? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<int>(
                      title: '默认全屏方向',
                      value: defaultFullScreenMode,
                      values: FullScreenMode.values.map((e) {
                        return {'title': e.description, 'value': e.code};
                      }).toList());
                },
              );
              if (result != null) {
                defaultFullScreenMode = result;
                setting.put(SettingBoxKey.fullScreenMode, result);
                setState(() {});
              }
            },
          ),
          ListTile(
            dense: false,
            title: Text('底部进度条展示', style: titleStyle),
            leading: const Icon(Icons.border_bottom_outlined),
            subtitle: Text(
              '当前展示方式：${BtmProgresBehaviorCode.fromCode(defaultBtmProgressBehavior)!.description}',
              style: subTitleStyle,
            ),
            onTap: () async {
              int? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<int>(
                      title: '底部进度条展示',
                      value: defaultBtmProgressBehavior,
                      values: BtmProgresBehavior.values.map((e) {
                        return {'title': e.description, 'value': e.code};
                      }).toList());
                },
              );
              if (result != null) {
                defaultBtmProgressBehavior = result;
                setting.put(SettingBoxKey.btmProgressBehavior, result);
                setState(() {});
              }
            },
          ),
          const SetSwitchItem(
            title: '后台音频服务',
            subTitle: '避免画中画没有播放暂停功能',
            leading: Icon(Icons.volume_up_outlined),
            setKey: SettingBoxKey.enableBackgroundPlay,
            defaultVal: true,
          ),
        ],
      ),
    );
  }
}
