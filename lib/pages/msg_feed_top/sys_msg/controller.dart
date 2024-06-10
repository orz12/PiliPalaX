import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/http/msg.dart';

import '../../../models/msg/msgfeed_sys_msg.dart';

class SysMsgController extends GetxController {
  RxList<SystemNotifyList> msgFeedSysMsgList = <SystemNotifyList>[].obs;
  bool isLoading = false;
  int cursor = -1;
  int cursorTime = -1;
  bool isEnd = false;

  Future queryMsgFeedSysMsg() async {
    if (isLoading) return;
    isLoading = true;
    var resUserNotify = await MsgHttp.msgFeedSysUserNotify();
    var resUnifiedNotify = await MsgHttp.msgFeedSysUnifiedNotify();
    isLoading = false;
    List<SystemNotifyList> systemNotifyList = [];
    if (resUserNotify['status']) {
      MsgFeedSysMsg data = MsgFeedSysMsg.fromJson(resUserNotify['data']);
      if (data.systemNotifyList != null) {
        systemNotifyList.addAll(data.systemNotifyList!);
      }
    }
    if (resUnifiedNotify['status']) {
      MsgFeedSysMsg data = MsgFeedSysMsg.fromJson(resUnifiedNotify['data']);
      if (data.systemNotifyList != null) {
        systemNotifyList.addAll(data.systemNotifyList!);
      }
    }
    if (systemNotifyList.isNotEmpty) {
      systemNotifyList.sort((a, b) => b.cursor!.compareTo(a.cursor!));
      msgFeedSysMsgList.assignAll(systemNotifyList);
      msgSysUpdateCursor(msgFeedSysMsgList.first.cursor!);
    } else {
      SmartDialog.showToast(
          "UserNotify: ${resUserNotify['msg']} UnifiedNotify: ${resUnifiedNotify['msg']}");
    }
  }

  Future msgSysUpdateCursor(int cursor) async {
    var res = await MsgHttp.msgSysUpdateCursor(cursor);
    if (res['status']) {
      SmartDialog.showToast('已读成功');
      return true;
    } else {
      SmartDialog.showToast(res['msg']);
      return false;
    }
  }
  Future onLoad() async {
    if (isEnd) return;
    queryMsgFeedSysMsg();
  }

  Future onRefresh() async {
    cursor = -1;
    cursorTime = -1;
    queryMsgFeedSysMsg();
  }
}
