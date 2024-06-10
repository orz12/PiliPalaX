import 'package:hive/hive.dart';
import 'package:PiliPalaX/http/user.dart';

import 'storage.dart';

class Data {
  static Future init() async {
    await historyStatus();
  }

  static Future historyStatus() async {
    Box localCache = GStrorage.localCache;
    Box userInfoCache = GStrorage.userInfo;
    if (userInfoCache.get('userInfoCache') == null) {
      return;
    }
    var res = await UserHttp.historyStatus();
    if (res['status']) {
      localCache.put(LocalCacheKey.historyPause, res['data']);
    }
  }
}
