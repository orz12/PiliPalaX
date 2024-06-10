import 'package:PiliPalaX/utils/cookie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/http/interceptor_anonymity.dart';
import 'package:PiliPalaX/http/member.dart';
import 'package:PiliPalaX/utils/storage.dart';

import '../../http/user.dart';
import '../../models/user/info.dart';
import '../../utils/login.dart';
import '../home/controller.dart';
import '../media/controller.dart';
import '../mine/controller.dart';

class PrivacySetting extends StatefulWidget {
  const PrivacySetting({super.key});

  @override
  State<PrivacySetting> createState() => _PrivacySettingState();
}

class _PrivacySettingState extends State<PrivacySetting> {
  bool userLogin = false;
  Box userInfoCache = GStrorage.userInfo;
  UserInfoData? userInfo;
  late bool hiddenSettingUnlocked;

  @override
  void initState() {
    super.initState();
    userInfo = userInfoCache.get('userInfoCache');
    userLogin = userInfo != null;
    hiddenSettingUnlocked = GStrorage.setting
        .get(SettingBoxKey.hiddenSettingUnlocked, defaultValue: false);
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
          '隐私设置',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: Column(
        children: [
          ListTile(
            onTap: () {
              if (!userLogin) {
                SmartDialog.showToast('登录后查看');
                return;
              }
              Get.toNamed('/blackListPage');
            },
            dense: false,
            title: Text('黑名单管理', style: titleStyle),
            subtitle: Text('已拉黑用户', style: subTitleStyle),
            leading: const Icon(Icons.block),
          ),
          ListTile(
            onTap: () async {
              if (!userLogin) {
                SmartDialog.showToast('请先登录');
                return;
              }
              var res = await MemberHttp.cookieToKey();
              if (res['status']) {
                SmartDialog.showToast(res['msg']);
              } else {
                SmartDialog.showToast('刷新失败：${res['msg']}');
              }
            },
            dense: false,
            title: Text('刷新access_key', style: titleStyle),
            leading: const Icon(Icons.perm_device_info_outlined),
            subtitle: Text(
                '用于app端推荐接口的用户凭证。刷新有小概率导致其他设备下线。若app端未推荐个性化内容，可尝试刷新或清除本app数据后重新登录',
                style: subTitleStyle),
          ),
          if (hiddenSettingUnlocked)
            ListTile(
              title: Text(
                '导入/导出cookie',
                style: titleStyle,
              ),
              subtitle: Text(
                'cookie代表您的登录状态，仅供高级用户使用',
                style: subTitleStyle,
              ),
              leading: const Icon(Icons.cookie_outlined),
              dense: false,
              onTap: () {
                import_export_cookies(titleStyle, subTitleStyle);
              },
            ),
          ListTile(
              onTap: () {
                MineController.onChangeAnonymity(context);
                setState(() {});
              },
              leading: const Icon(Icons.privacy_tip_outlined),
              dense: false,
              title: Text(MineController.anonymity ? '退出无痕模式' : '进入无痕模式',
                  style: titleStyle),
              subtitle: Text(
                MineController.anonymity
                    ? '已进入无痕模式，搜索、观看视频/直播不携带Cookie与CSRF，其余操作不受影响'
                    : '未开启无痕模式，将使用账户信息提供完整服务',
                style: subTitleStyle,
              )),
          ListTile(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('查看详情'),
                    content:
                        Text(AnonymityInterceptor.anonymityList.join('\n')),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Get.back();
                        },
                        child: const Text('确认'),
                      )
                    ],
                  );
                },
              );
            },
            leading: const Icon(Icons.flag_outlined),
            dense: false,
            title: Text('了解无痕模式', style: titleStyle),
            subtitle: Text('查看无痕模式作用的API列表', style: subTitleStyle),
          ),
        ],
      ),
    );
  }

  void import_export_cookies(TextStyle titleStyle, TextStyle subTitleStyle) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('导入/导出cookie', style: TextStyle(color: Colors.red)),
          children: [
            ListTile(
                title: Text(
                  '导出cookie至剪贴板',
                  style: titleStyle.copyWith(color: Colors.red),
                ),
                leading: const Icon(
                  Icons.warning_amber,
                  color: Colors.red,
                ),
                subtitle: Text(
                  '泄露账号cookie等同于绕过账号密码与验证码直接登录，可导致隐私泄露、风控、毁号、盗号等各类问题。\n'
                  '你应妥善保管该cookie且仅供自己使用。你承诺，不会利用本服务进行任何违法或不当的活动。你承诺，对所进行的一切活动'
                  '（包括但不限于网上点击同意或提交各类规则协议或购买服务、分享资讯或图片等）负全部责任。\n'
                  '你承诺、理解、同意并确认，在你的账户遭到未获授权的使用，或者发生其他任何安全问题时，'
                  '作者不对上述情形产生的任何直接或间接的遗失或损害承担责任。',
                  style: subTitleStyle.copyWith(color: Colors.redAccent),
                ),
                dense: false,
                onTap: () async {
                  Navigator.of(context).pop();
                  if (!userLogin) {
                    SmartDialog.showToast('请先登录');
                    return;
                  }
                  final String cookie = await CookieTool.exportCookie();
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('导出cookie（危险）',
                            style: TextStyle(color: Colors.red)),
                        content: Text(cookie),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await Clipboard.setData(
                                  ClipboardData(text: cookie));
                            },
                            child: const Text('复制（危险）',
                                style: TextStyle(color: Colors.red)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                            },
                            child: const Text('取消'),
                          ),
                        ],
                      );
                    },
                  );
                }),
            ListTile(
                title: Text(
                  '从剪贴板导入cookie',
                  style: titleStyle,
                ),
                leading: const Icon(
                  Icons.warning_amber,
                  color: Colors.red,
                ),
                subtitle: Text(
                  '导入将覆盖当前登录状态，你应自行对利用服务从事的所有行为及结果承担责任，请慎用',
                  style: subTitleStyle,
                ),
                dense: false,
                onTap: () async {
                  ClipboardData? data = await Clipboard.getData('text/plain');
                  if (data == null || data.text == null || data.text == '') {
                    SmartDialog.showToast('未检测到剪贴板内容');
                    return;
                  }
                  if (!context.mounted) return;
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('导入剪贴板中的cookie'),
                        content: Text(data.text!),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              Get.back();
                            },
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Get.back();
                              final String cookie = data.text!;
                              try {
                                await CookieTool.importCookie(cookie);
                                await SmartDialog.showToast('已导入');
                                await CookieTool.onSet();
                                final result = await UserHttp.userInfo();
                                if (result['status'] &&
                                    result['data'].isLogin) {
                                  SmartDialog.showToast('登录成功，当前采用「'
                                      '${GStrorage.setting.get(SettingBoxKey.defaultRcmdType, defaultValue: 'web')}'
                                      '端」推荐');
                                  Box userInfoCache = GStrorage.userInfo;
                                  await userInfoCache.put(
                                      'userInfoCache', result['data']);
                                  final HomeController homeCtr =
                                      Get.find<HomeController>();
                                  homeCtr.updateLoginStatus(true);
                                  homeCtr.userFace.value = result['data'].face;
                                  final MediaController mediaCtr =
                                      Get.find<MediaController>();
                                  mediaCtr.mid = result['data'].mid;
                                  await LoginUtils.refreshLoginStatus(true);
                                  Get.back();
                                } else {
                                  // 获取用户信息失败
                                  SmartDialog.showNotify(
                                      msg:
                                          '登录失败，请检查cookie是否正确，${result['message']}',
                                      notifyType: NotifyType.warning);
                                }
                              } catch (e) {
                                SmartDialog.showToast('导入失败：$e');
                              }
                            },
                            child: const Text('确认'),
                          ),
                        ],
                      );
                    },
                  );
                }),
          ],
        );
      },
    );
  }
}
