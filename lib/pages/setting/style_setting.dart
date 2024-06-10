import 'dart:io';

import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/models/common/theme_type.dart';
import 'package:PiliPalaX/pages/setting/pages/color_select.dart';
import 'package:PiliPalaX/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPalaX/pages/setting/widgets/slide_dialog.dart';
import 'package:PiliPalaX/utils/global_data.dart';
import 'package:PiliPalaX/utils/storage.dart';

import '../../models/common/dynamic_badge_mode.dart';
import '../../models/common/up_panel_position.dart';
import '../../plugin/pl_player/utils/fullscreen.dart';
import '../../models/common/nav_bar_config.dart';
import 'controller.dart';
import 'widgets/switch_item.dart';

class StyleSetting extends StatefulWidget {
  const StyleSetting({super.key});

  @override
  State<StyleSetting> createState() => _StyleSettingState();
}

class _StyleSettingState extends State<StyleSetting> {
  final SettingController settingController = Get.put(SettingController());
  final ColorSelectController colorSelectController =
      Get.put(ColorSelectController());

  Box setting = GStrorage.setting;
  late int picQuality;
  late ThemeType _tempThemeValue;
  late double maxRowWidth;
  late UpPanelPosition upPanelPosition;

  @override
  void initState() {
    super.initState();
    picQuality = setting.get(SettingBoxKey.defaultPicQa, defaultValue: 10);
    _tempThemeValue = settingController.themeType.value;
    maxRowWidth =
        setting.get(SettingBoxKey.maxRowWidth, defaultValue: 240.0) as double;
    upPanelPosition = UpPanelPosition.values[setting.get(
        SettingBoxKey.upPanelPosition,
        defaultValue: UpPanelPosition.leftFixed.code)];
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
          '外观设置',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: ListView(
        children: [
          SetSwitchItem(
              title: '横屏适配',
              subTitle: '启用横屏布局与逻辑，适用于平板等设备',
              leading: const Icon(Icons.phonelink_outlined),
              setKey: SettingBoxKey.horizontalScreen,
              defaultVal: false,
              callFn: (value) {
                if (value) {
                  autoScreen();
                  SmartDialog.showToast('已开启横屏适配，推荐将全屏方式设为【不改变当前方向】');
                } else {
                  AutoOrientation.portraitUpMode();
                  SmartDialog.showToast('已关闭横屏适配');
                }
              }),
          const SetSwitchItem(
            title: '改用侧边栏',
            subTitle: '开启后底栏被替换，且底栏相关设置失效',
            leading: Icon(Icons.chrome_reader_mode_outlined),
            setKey: SettingBoxKey.useSideBar,
            defaultVal: false,
          ),
          const SetSwitchItem(
            title: 'MD3样式底栏',
            subTitle: 'Material You设计规范底栏，关闭可变窄',
            leading: Icon(Icons.design_services_outlined),
            setKey: SettingBoxKey.enableMYBar,
            defaultVal: true,
          ),
          const SetSwitchItem(
            title: '首页背景渐变',
            setKey: SettingBoxKey.enableGradientBg,
            leading: Icon(Icons.gradient_outlined),
            defaultVal: true,
            needReboot: true,
          ),
          ListTile(
            onTap: () async {
              double? result = await showDialog(
                  context: context,
                  builder: (context) {
                    return SlideDialog<double>(
                      title: '最大列宽度（默认240dp）',
                      value: maxRowWidth,
                      min: 150.0,
                      max: 500.0,
                      divisions: 35,
                      suffix: 'dp',
                    );
                  });
              if (result != null) {
                maxRowWidth = result;
                setting.put(SettingBoxKey.maxRowWidth, result);
                SmartDialog.showToast('重启生效');
                setState(() {});
              }
            },
            leading: const Icon(Icons.calendar_view_week_outlined),
            dense: false,
            title: Text('列表宽度（dp）限制', style: titleStyle),
            subtitle: Text(
              '当前:${maxRowWidth.toInt()}dp，屏幕宽度:${MediaQuery.of(context).size.width.toPrecision(2)}dp。'
              '宽度越小列数越多，横条、大卡会2倍折算',
              style: subTitleStyle,
            ),
          ),
          const SetSwitchItem(
            title: '播放页状态栏显示为背景色',
            subTitle: '关闭则显示为黑色',
            leading: Icon(Icons.border_outer_outlined),
            setKey: SettingBoxKey.videoPlayerShowStatusBarBackgroundColor,
            defaultVal: false,
            needReboot: true,
          ),
          const SetSwitchItem(
            title: '播放页移除安全边距',
            subTitle: '隐藏状态栏、撑满屏幕，但播放控件仍处于安全域内',
            leading: Icon(Icons.fit_screen_outlined),
            setKey: SettingBoxKey.videoPlayerRemoveSafeArea,
            defaultVal: false,
            needReboot: true,
          ),
          const SetSwitchItem(
            title: '动态页启用瀑布流',
            subTitle: '关闭会显示为单列',
            leading: Icon(Icons.view_array_outlined),
            setKey: SettingBoxKey.dynamicsWaterfallFlow,
            defaultVal: true,
            needReboot: true,
          ),
          ListTile(
            dense: false,
            title: Text('动态页Up主显示位置', style: titleStyle),
            leading: const Icon(Icons.person_outlined),
            subtitle:
                Text('当前：${upPanelPosition.labels}', style: subTitleStyle),
            onTap: () async {
              UpPanelPosition? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<UpPanelPosition>(
                    title: '动态页Up主显示位置',
                    value: upPanelPosition,
                    values: UpPanelPosition.values.map((e) {
                      return {'title': e.labels, 'value': e};
                    }).toList(),
                  );
                },
              );
              if (result != null) {
                upPanelPosition = result;
                setting.put(SettingBoxKey.upPanelPosition, result.code);
                SmartDialog.showToast('重启生效');
                setState(() {});
              }
            },
          ),
          ListTile(
            dense: false,
            onTap: () => settingController.setDynamicBadgeMode(context),
            title: Text('动态未读标记', style: titleStyle),
            leading: const Icon(Icons.motion_photos_on_outlined),
            subtitle: Obx(() => Text(
                '当前标记样式：${settingController.dynamicBadgeType.value.description}',
                style: subTitleStyle)),
          ),
          const SetSwitchItem(
            title: '首页顶栏收起',
            subTitle: '首页列表滑动时，收起顶栏',
            leading: Icon(Icons.vertical_align_top_outlined),
            setKey: SettingBoxKey.hideSearchBar,
            defaultVal: false,
            needReboot: true,
          ),
          const SetSwitchItem(
            title: '首页底栏收起',
            subTitle: '首页列表滑动时，收起底栏',
            leading: Icon(Icons.vertical_align_bottom_outlined),
            setKey: SettingBoxKey.hideTabBar,
            defaultVal: false,
            needReboot: true,
          ),
          ListTile(
            dense: false,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, StateSetter setState) {
                      final SettingController settingController =
                          Get.put(SettingController());
                      return AlertDialog(
                        title: const Text('图片质量'),
                        contentPadding: const EdgeInsets.only(
                            top: 20, left: 8, right: 8, bottom: 8),
                        content: SizedBox(
                          height: 40,
                          child: Slider(
                            value: picQuality.toDouble(),
                            min: 10,
                            max: 100,
                            divisions: 9,
                            label: '$picQuality%',
                            onChanged: (double val) {
                              picQuality = val.toInt();
                              setState(() {});
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Get.back(),
                              child: Text('取消',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline))),
                          TextButton(
                            onPressed: () {
                              setting.put(
                                  SettingBoxKey.defaultPicQa, picQuality);
                              Get.back();
                              settingController.picQuality.value = picQuality;
                              GlobalData().imgQuality = picQuality;
                              SmartDialog.showToast('设置成功');
                            },
                            child: const Text('确定'),
                          )
                        ],
                      );
                    },
                  );
                },
              );
            },
            title: Text('图片质量', style: titleStyle),
            subtitle: Text('选择合适的图片清晰度，上限100%', style: subTitleStyle),
            leading: const Icon(Icons.image_outlined),
            trailing: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Obx(
                () => Text(
                  '${settingController.picQuality.value}%',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
          ),
          ListTile(
            dense: false,
            onTap: () async {
              double? result = await showDialog(
                context: context,
                builder: (context) {
                  return SlideDialog<double>(
                    title: 'Toast不透明度',
                    value: settingController.toastOpacity.value,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                  );
                },
              );
              if (result != null) {
                settingController.toastOpacity.value = result;
                SmartDialog.showToast('设置成功');
                setting.put(SettingBoxKey.defaultToastOp, result);
              }
            },
            leading: const Icon(Icons.opacity_outlined),
            title: Text('气泡提示不透明度', style: titleStyle),
            subtitle: Text('自定义气泡提示(Toast)不透明度', style: subTitleStyle),
            trailing: Obx(() => Text(
                settingController.toastOpacity.value.toStringAsFixed(1),
                style: Theme.of(context).textTheme.titleSmall)),
          ),
          ListTile(
            dense: false,
            onTap: () async {
              ThemeType? result = await showDialog(
                context: context,
                builder: (context) {
                  return SelectDialog<ThemeType>(
                      title: '主题模式',
                      value: _tempThemeValue,
                      values: ThemeType.values.map((e) {
                        return {'title': e.description, 'value': e};
                      }).toList());
                },
              );
              if (result != null) {
                _tempThemeValue = result;
                settingController.themeType.value = result;
                setting.put(SettingBoxKey.themeMode, result.code);
                Get.forceAppUpdate();
              }
            },
            leading: const Icon(Icons.flashlight_on_outlined),
            title: Text('主题模式', style: titleStyle),
            subtitle: Obx(() => Text(
                '当前模式：${settingController.themeType.value.description}',
                style: subTitleStyle)),
          ),
          ListTile(
            dense: false,
            onTap: () => Get.toNamed('/colorSetting'),
            leading: const Icon(Icons.color_lens_outlined),
            title: Text('应用主题', style: titleStyle),
            subtitle: Obx(() => Text(
                '当前主题：${colorSelectController.type.value == 0 ? '动态取色' : '指定颜色'}',
                style: subTitleStyle)),
          ),
          ListTile(
            dense: false,
            onTap: () => settingController.seteDefaultHomePage(context),
            leading: const Icon(Icons.home_outlined),
            title: Text('默认启动页', style: titleStyle),
            subtitle: Obx(() => Text(
                '当前启动页：${defaultNavigationBars.firstWhere((e) => e['id'] == settingController.defaultHomePage.value)['label']}',
                style: subTitleStyle)),
          ),
          ListTile(
            dense: false,
            onTap: () => Get.toNamed('/fontSizeSetting'),
            title: Text('字体大小', style: titleStyle),
            leading: const Icon(Icons.format_size_outlined),
          ),
          ListTile(
            dense: false,
            onTap: () => Get.toNamed('/tabbarSetting'),
            title: Text('首页标签页', style: titleStyle),
            subtitle: Text('删除或调换首页标签页', style: subTitleStyle),
            leading: const Icon(Icons.toc_outlined),
          ),
          if (Platform.isAndroid)
            ListTile(
              dense: false,
              onTap: () => Get.toNamed('/displayModeSetting'),
              title: Text('屏幕帧率', style: titleStyle),
              leading: const Icon(Icons.autofps_select_outlined),
            )
        ],
      ),
    );
  }
}
