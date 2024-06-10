import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/models/video/play/quality.dart';
import 'package:PiliPalaX/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPalaX/utils/storage.dart';

import 'widgets/switch_item.dart';

class VideoSetting extends StatefulWidget {
  const VideoSetting({super.key});

  @override
  State<VideoSetting> createState() => _VideoSettingState();
}

class _VideoSettingState extends State<VideoSetting> {
  Box setting = GStrorage.setting;
  late dynamic defaultVideoQa;
  late dynamic defaultAudioQa;
  late dynamic defaultDecode;
  late dynamic secondDecode;
  late dynamic hardwareDecoding;
  late dynamic videoSync;

  @override
  void initState() {
    super.initState();
    defaultVideoQa = setting.get(SettingBoxKey.defaultVideoQa,
        defaultValue: VideoQuality.values.last.code);
    defaultAudioQa = setting.get(SettingBoxKey.defaultAudioQa,
        defaultValue: AudioQuality.values.last.code);
    defaultDecode = setting.get(SettingBoxKey.defaultDecode,
        defaultValue: VideoDecodeFormats.values.last.code);
    secondDecode = setting.get(SettingBoxKey.secondDecode,
        defaultValue: VideoDecodeFormats.values[1].code);
    hardwareDecoding = setting.get(SettingBoxKey.hardwareDecoding,
        defaultValue: Platform.isAndroid ? 'auto-safe' : 'auto');
    videoSync =
        setting.get(SettingBoxKey.videoSync, defaultValue: 'display-resample');
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
          '音视频设置',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        children: [
          const SetSwitchItem(
            title: '开启硬解',
            subTitle: '以较低功耗播放视频，若异常卡死请关闭',
            leading: Icon(Icons.flash_on_outlined),
            setKey: SettingBoxKey.enableHA,
            defaultVal: true,
          ),
          const SetSwitchItem(
            title: '亮度记忆',
            subTitle: '返回时自动调整视频亮度',
            leading: Icon(Icons.brightness_6_outlined),
            setKey: SettingBoxKey.enableAutoBrightness,
            defaultVal: false,
          ),
          const SetSwitchItem(
            title: '免登录1080P',
            subTitle: '免登录查看1080P视频',
            leading: Icon(Icons.hd_outlined),
            setKey: SettingBoxKey.p1080,
            defaultVal: true,
          ),
          const SetSwitchItem(
            title: 'CDN优化',
            subTitle: '使用优质CDN线路',
            leading: Icon(Icons.network_check_outlined),
            setKey: SettingBoxKey.enableCDN,
            defaultVal: true,
          ),
          ListTile(
            dense: false,
            title: Text('默认画质', style: titleStyle),
            leading: const Icon(Icons.video_settings_outlined),
            subtitle: Text(
              '当前画质：${VideoQualityCode.fromCode(defaultVideoQa)!.description!}',
              style: subTitleStyle,
            ),
            onTap: () async {
              int? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<int>(
                      title: '默认画质',
                      value: defaultVideoQa,
                      values: VideoQuality.values.reversed.map((e) {
                        return {'title': e.description, 'value': e.code};
                      }).toList());
                },
              );
              if (result != null) {
                defaultVideoQa = result;
                setting.put(SettingBoxKey.defaultVideoQa, result);
                setState(() {});
              }
            },
          ),
          ListTile(
            dense: false,
            title: Text('默认音质', style: titleStyle),
            leading: const Icon(Icons.audiotrack_outlined),
            subtitle: Text(
              '当前音质：${AudioQualityCode.fromCode(defaultAudioQa)!.description!}',
              style: subTitleStyle,
            ),
            onTap: () async {
              int? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<int>(
                      title: '默认音质',
                      value: defaultAudioQa,
                      values: AudioQuality.values.reversed.map((e) {
                        return {'title': e.description, 'value': e.code};
                      }).toList());
                },
              );
              if (result != null) {
                defaultAudioQa = result;
                setting.put(SettingBoxKey.defaultAudioQa, result);
                setState(() {});
              }
            },
          ),
          ListTile(
            dense: false,
            title: Text('首选解码格式', style: titleStyle),
            leading: const Icon(Icons.movie_creation_outlined),
            subtitle: Text(
              '首选解码格式：${VideoDecodeFormatsCode.fromCode(defaultDecode)!.description!}，请根据设备支持情况与需求调整',
              style: subTitleStyle,
            ),
            onTap: () async {
              String? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<String>(
                      title: '默认解码格式',
                      value: defaultDecode,
                      values: VideoDecodeFormats.values.map((e) {
                        return {'title': e.description, 'value': e.code};
                      }).toList());
                },
              );
              if (result != null) {
                defaultDecode = result;
                setting.put(SettingBoxKey.defaultDecode, result);
                setState(() {});
              }
            },
          ),
          ListTile(
            dense: false,
            title: Text('次选解码格式', style: titleStyle),
            subtitle: Text(
              '非杜比视频次选：${VideoDecodeFormatsCode.fromCode(secondDecode)!.description!}，仍无则选择首个提供的解码格式',
              style: subTitleStyle,
            ),
            leading: const Icon(Icons.swap_horizontal_circle_outlined),
            onTap: () async {
              String? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<String>(
                      title: '次选解码格式',
                      value: secondDecode,
                      values: VideoDecodeFormats.values.map((e) {
                        return {'title': e.description, 'value': e.code};
                      }).toList());
                },
              );
              if (result != null) {
                secondDecode = result;
                setting.put(SettingBoxKey.secondDecode, result);
                setState(() {});
              }
            },
          ),
          if (Platform.isAndroid)
            const SetSwitchItem(
              title: '优先使用 OpenSL ES 输出音频',
              leading: Icon(Icons.speaker_outlined),
              subTitle: '关闭则优先使用AudioTrack输出音频（此项即mpv的--ao）',
              setKey: SettingBoxKey.useOpenSLES,
              defaultVal: true,
            ),
          const SetSwitchItem(
            title: '扩大缓冲区',
            leading: Icon(Icons.storage_outlined),
            subTitle: '默认缓冲区为视频5MB/直播32MB，开启后为32MB/64MB，加载时间变长',
            setKey: SettingBoxKey.expandBuffer,
            defaultVal: false,
          ),
          //video-sync
          ListTile(
            dense: false,
            title: Text('视频同步', style: titleStyle),
            leading: const Icon(Icons.view_timeline_outlined),
            subtitle: Text(
              '当前：$videoSync（此项即mpv的--video-sync）',
              style: subTitleStyle,
            ),
            onTap: () async {
              String? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<String>(
                      title: '视频同步',
                      value: videoSync,
                      values: [
                        'audio',
                        'display-resample',
                        'display-resample-vdrop',
                        'display-resample-desync',
                        'display-tempo',
                        'display-vdrop',
                        'display-adrop',
                        'display-desync',
                        'desync'
                      ].map((e) {
                        return {'title': e, 'value': e};
                      }).toList());
                },
              );
              if (result != null) {
                setting.put(SettingBoxKey.videoSync, result);
                videoSync = result;
                setState(() {});
              }
            },
          ),
          ListTile(
            dense: false,
            title: Text('硬解模式', style: titleStyle),
            leading: const Icon(Icons.memory_outlined),
            subtitle: Text(
              '当前：$hardwareDecoding（此项即mpv的--hwdec）',
              style: subTitleStyle,
            ),
            onTap: () async {
              String? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<String>(
                      title: '硬解模式',
                      value: hardwareDecoding,
                      values: ['auto', 'auto-copy', 'auto-safe', 'no', 'yes']
                          .map((e) {
                        return {'title': e, 'value': e};
                      }).toList());
                },
              );
              if (result != null) {
                setting.put(SettingBoxKey.hardwareDecoding, result);
                hardwareDecoding = result;
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}
