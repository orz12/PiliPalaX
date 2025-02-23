import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:hive/hive.dart';
import '../common/constants.dart';
import '../models/common/reply_type.dart';
import '../models/home/rcmd/result.dart';
import '../models/model_hot_video_item.dart';
import '../models/model_rec_video_item.dart';
import '../models/user/fav_folder.dart';
import '../models/video/ai.dart';
import '../models/video/play/url.dart';
import '../models/video_detail_res.dart';
import '../utils/id_utils.dart';
import '../utils/recommend_filter.dart';
import '../utils/storage.dart';
import '../utils/utils.dart';
import '../utils/wbi_sign.dart';
import '../pages/mine/controller.dart';
import 'api.dart';
import 'init.dart';
import 'login.dart';

/// res.data['code'] == 0 请求正常返回结果
/// res.data['data'] 为结果
/// 返回{'status': bool, 'data': List}
/// view层根据 status 判断渲染逻辑
class VideoHttp {
  static Box localCache = GStorage.localCache;
  static Box onlineCache = GStorage.onlineCache;
  static Box setting = GStorage.setting;
  static bool enableRcmdDynamic =
      setting.get(SettingBoxKey.enableRcmdDynamic, defaultValue: true);
  static Box userInfoCache = GStorage.userInfo;

  // 首页推荐视频
  static Future rcmdVideoList({required int ps, required int freshIdx}) async {
    var res = await Request().get(
      Api.recommendListWeb,
      data: {
        'version': 1,
        'feed_version': 'V8',
        'homepage_ver': 1,
        'ps': ps,
        'fresh_idx': freshIdx,
        'brush': freshIdx,
        'fresh_type': 4
      },
    );
    if (res.data['code'] == 0) {
      List<RecVideoItemModel> list = [];
      List<int> blackMidsList = onlineCache
          .get(OnlineCacheKey.blackMidsList, defaultValue: [-1])
          .map<int>((e) => e as int)
          .toList();
      for (var i in res.data['data']['item']) {
        //过滤掉live与ad，以及拉黑用户
        if (i['goto'] == 'av' &&
            (i['owner'] != null &&
                !blackMidsList.contains(i['owner']['mid']))) {
          RecVideoItemModel videoItem = RecVideoItemModel.fromJson(i);
          if (!RecommendFilter.filter(videoItem)) {
            list.add(videoItem);
          }
        }
      }
      return {'status': true, 'data': list};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // 添加额外的loginState变量模拟未登录状态
  static Future rcmdVideoListApp(
      {bool loginStatus = true, required int freshIdx}) async {
    var data = {
      'access_key': loginStatus
          ? (localCache
                  .get(LocalCacheKey.accessKey, defaultValue: {})['value'] ??
              '')
          : '',
      'appkey': Constants.appKey,
      'build': '2001100',
      'c_locale': 'zh_CN',
      'channel': 'yingyongbao',
      'column': '4',
      'device': 'pad',
      'device_name': 'vivo',
      'device_type': '0',
      'disable_rcmd': '0',
      'flush': '5',
      'fnval': '976',
      'fnver': '0',
      'force_host': '2', //使用https
      'fourk': '1',
      'guidance': '0',
      'https_url_req': '0',
      'idx': freshIdx.toString(),
      'mobi_app': 'android_hd',
      'network': 'wifi',
      'platform': 'android',
      'player_net': '1',
      'pull': freshIdx == 0 ? 'true' : 'false',
      'qn': '32',
      'recsys_mode': '0',
      's_locale': 'zh_CN',
      'splash_id': '',
      'statistics': Constants.statistics,
      'ts': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'voice_balance': '0'
    };
    String sign = Utils.appSign(
      data,
      Constants.appKey,
      Constants.appSec,
    );
    data['sign'] = sign;

    var res = await Request().get(
      Api.recommendListApp,
      data: data,
      options: Options(headers: {
        'Host': 'app.bilibili.com',
        'buvid': LoginHttp.buvid,
        'fp_local':
            '1111111111111111111111111111111111111111111111111111111111111111',
        'fp_remote':
            '1111111111111111111111111111111111111111111111111111111111111111',
        'session_id': '11111111',
        'env': 'prod',
        'app-key': 'android_hd',
        'User-Agent': Constants.userAgent,
        'x-bili-trace-id': Constants.traceId,
        'x-bili-aurora-eid': '',
        'x-bili-aurora-zone': '',
        'bili-http-engine': 'cronet',
      }),
    );
    log(res.data['data'].toString());
    if (res.data['code'] == 0) {
      List<RecVideoItemAppModel> list = [];
      List<int> blackMidsList = onlineCache
          .get(OnlineCacheKey.blackMidsList, defaultValue: [-1])
          .map<int>((e) => e as int)
          .toList();
      for (var i in res.data['data']['items']) {
        // 屏蔽推广和拉黑用户
        if (i['card_goto'] != 'ad_av' &&
            i['card_goto'] != 'ad_web_s' &&
            i['ad_info'] == null &&
            (!enableRcmdDynamic ? i['card_goto'] != 'picture' : true) &&
            (i['args'] != null &&
                !blackMidsList.contains(i['args']['up_id']))) {
          RecVideoItemAppModel videoItem = RecVideoItemAppModel.fromJson(i);
          if (!RecommendFilter.filter(videoItem)) {
            list.add(videoItem);
          }
        }
      }
      return {'status': true, 'data': list};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // 最热视频
  static Future hotVideoList({required int pn, required int ps}) async {
    try {
      var res = await Request().get(
        Api.hotList,
        data: {'pn': pn, 'ps': ps},
      );
      if (res.data['code'] == 0) {
        List<HotVideoItemModel> list = [];
        List<int> blackMidsList = onlineCache
            .get(OnlineCacheKey.blackMidsList, defaultValue: [-1])
            .map<int>((e) => e as int)
            .toList();
        for (var i in res.data['data']['list']) {
          if (!blackMidsList.contains(i['owner']['mid'])) {
            list.add(HotVideoItemModel.fromJson(i));
          }
        }
        return {'status': true, 'data': list};
      } else {
        return {'status': false, 'data': [], 'msg': res.data['message']};
      }
    } catch (err) {
      return {'status': false, 'data': [], 'msg': err};
    }
  }

  // 视频流
  static Future videoUrl(
      {int? avid, String? bvid, required int cid, int? qn}) async {
    Map<String, dynamic> data = {
      'cid': cid,
      'qn': qn ?? 80,
      // 获取所有格式的视频
      'fnval': 4048,
    };
    if (avid != null) {
      data['avid'] = avid;
    }
    if (bvid != null) {
      data['bvid'] = bvid;
    }

    // 免登录查看1080p
    if ((userInfoCache.get('userInfoCache') == null ||
            MineController.anonymity) &&
        setting.get(SettingBoxKey.p1080, defaultValue: true)) {
      data['try_look'] = 1;
    }

    Map params = await WbiSign().makSign({
      ...data,
      'fourk': 1,
      'voice_balance': 1,
      'gaia_source': 'pre-load',
      'web_location': 1550101,
    });

    try {
      var res = await Request().get(Api.videoUrl, data: params);
      if (res.data['code'] == 0) {
        return {
          'status': true,
          'data': PlayUrlModel.fromJson(res.data['data'])
        };
      } else {
        return {
          'status': false,
          'data': [],
          'code': res.data['code'],
          'msg': res.data['message'],
        };
      }
    } catch (err) {
      return {'status': false, 'data': [], 'msg': err};
    }
  }

  // 视频信息 标题、简介
  static Future videoIntro({required String bvid}) async {
    var res = await Request().get(Api.videoIntro, data: {'bvid': bvid});
    VideoDetailResponse result = VideoDetailResponse.fromJson(res.data);
    if (result.code == 0) {
      return {'status': true, 'data': result.data!};
    } else {
      // Map errMap = {
      //   -400: '请求错误',
      //   -403: '权限不足',
      //   -404: '视频资源失效',
      //   62002: '稿件不可见',
      //   62004: '稿件审核中',
      // };
      return {
        'status': false,
        'data': result.data,
        'code': result.code,
        'msg': result.message,
        // 'msg': errMap[result.code] ?? '请求异常',
      };
    }
  }

  // 相关视频
  static Future relatedVideoList({required String bvid}) async {
    print(
        'RecommendFilter.disableRelatedVideos: ${RecommendFilter.disableRelatedVideos}');
    if (RecommendFilter.disableRelatedVideos) {
      return {'status': true, 'data': []};
    }
    var res = await Request().get(Api.relatedList, data: {'bvid': bvid});
    if (res.data['code'] == 0) {
      List<HotVideoItemModel> list = [];
      for (var i in res.data['data']) {
        HotVideoItemModel videoItem = HotVideoItemModel.fromJson(i);
        if (!RecommendFilter.filter(videoItem, relatedVideos: true)) {
          list.add(videoItem);
        }
      }
      return {'status': true, 'data': list};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // 获取点赞状态
  static Future hasLikeVideo({required String bvid}) async {
    var res = await Request().get(Api.hasLikeVideo, data: {'bvid': bvid});
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': []};
    }
  }

  // 获取投币状态
  static Future hasCoinVideo({required String bvid}) async {
    var res = await Request().get(Api.hasCoinVideo, data: {'bvid': bvid});
    print('res: $res');
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': []};
    }
  }

  // 投币
  static Future coinVideo({required String bvid, required int multiply}) async {
    var res = await Request().post(
      Api.coinVideo,
      queryParameters: {
        'aid': IdUtils.bv2av(bvid),
        // 'bvid': bvid,
        'multiply': multiply,
        'select_like': 0,
        'access_key': GStorage.localCache
            .get(LocalCacheKey.accessKey, defaultValue: {})['value'],
        // 'csrf': await Request.getCsrf(),
      },
    );
    print(res);
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // 获取收藏状态
  static Future hasFavVideo({required int aid}) async {
    var res = await Request().get(Api.hasFavVideo, data: {'aid': aid});
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': []};
    }
  }

  // 一键三连
  static Future oneThree({required String bvid}) async {
    var res = await Request().post(
      Api.oneThree,
      queryParameters: {
        'aid': IdUtils.bv2av(bvid),
        'access_key': GStorage.localCache
            .get(LocalCacheKey.accessKey, defaultValue: {})['value'],
      },
    );
    print(res);
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // （取消）点赞
  static Future likeVideo({required String bvid, required bool type}) async {
    var res = await Request().post(Api.likeVideo, queryParameters: {
      'aid': IdUtils.bv2av(bvid),
      'like': type ? 0 : 1,
      'access_key': GStorage.localCache
          .get(LocalCacheKey.accessKey, defaultValue: {})['value'],
    }
        // queryParameters: {
        //   'bvid': bvid,
        //   'like': type ? 1 : 2,
        //   'csrf': await Request.getCsrf(),
        // },
        );
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // （取消）点踩
  static Future dislikeVideo({required String bvid, required bool type}) async {
    String? accessKey = GStorage.localCache
        .get(LocalCacheKey.accessKey, defaultValue: {})['value'];
    if (accessKey == null || accessKey == "") {
      return {'status': false, 'msg': "请退出账号后重新登录"};
    }
    var res = await Request().post(
      Api.dislikeVideo,
      queryParameters: {
        'aid': IdUtils.bv2av(bvid),
        'dislike': type ? 0 : 1,
        'access_key': accessKey,
      },
    );
    print(res);
    if (res.data is! String && res.data['code'] == 0) {
      return {'status': true};
    } else {
      return {
        'status': false,
        'msg': res.data is String ? res.data : res.data['message']
      };
    }
  }

  // 推送不感兴趣反馈
  static Future feedDislike(
      {required String goto,
      required int id,
      int? reasonId,
      int? feedbackId}) async {
    String? accessKey = GStorage.localCache
        .get(LocalCacheKey.accessKey, defaultValue: {})['value'];
    if (accessKey == null || accessKey == "") {
      return {'status': false, 'msg': "请退出账号后重新登录"};
    }
    assert((reasonId != null) ^ (feedbackId != null));
    var res = await Request().get(Api.feedDislike, data: {
      'goto': goto,
      'id': id,
      // 'mid': mid,
      if (reasonId != null) 'reason_id': reasonId,
      if (feedbackId != null) 'feedback_id': feedbackId,
      'build': 1,
      'mobi_app': 'android',
      'access_key': accessKey,
      'appkey': Constants.appKey,
    });
    print(res);
    if (res.data['code'] == 0) {
      return {'status': true};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 推送不感兴趣取消
  static Future feedDislikeCancel(
      {required String goto,
      required int id,
      int? reasonId,
      int? feedbackId}) async {
    String? accessKey = GStorage.localCache
        .get(LocalCacheKey.accessKey, defaultValue: {})['value'];
    if (accessKey == null || accessKey == "") {
      return {'status': false, 'msg': "请退出账号后重新登录"};
    }
    // assert ((reasonId != null) ^ (feedbackId != null));
    var res = await Request().get(Api.feedDislikeCancel, data: {
      'goto': goto,
      'id': id,
      // 'mid': mid,
      if (reasonId != null) 'reason_id': reasonId,
      if (feedbackId != null) 'feedback_id': feedbackId,
      'build': 1,
      'mobi_app': 'android',
      'access_key': accessKey,
      'appkey': Constants.appKey,
    });
    print(res);
    if (res.data['code'] == 0) {
      return {'status': true};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // （取消）收藏
  static Future favVideo(
      {required int aid, String? addIds, String? delIds}) async {
    var res = await Request().post(Api.favVideo, queryParameters: {
      'rid': aid,
      'type': 2,
      'add_media_ids': addIds ?? '',
      'del_media_ids': delIds ?? '',
      'csrf': await Request.getCsrf(),
    });
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  // 查看视频被收藏在哪个文件夹
  static Future videoInFolder({required int mid, required int rid}) async {
    var res = await Request()
        .get(Api.videoInFolder, data: {'up_mid': mid, 'rid': rid});
    if (res.data['code'] == 0) {
      FavFolderData data = FavFolderData.fromJson(res.data['data']);
      return {'status': true, 'data': data};
    } else {
      return {'status': false, 'data': []};
    }
  }

  // 发表评论 replyAdd

  // type	num	评论区类型代码	必要	类型代码见表
  // oid	num	目标评论区id	必要
  // root	num	根评论rpid	非必要	二级评论以上使用
  // parent	num	父评论rpid	非必要	二级评论同根评论id 大于二级评论为要回复的评论id
  // message	str	发送评论内容	必要	最大1000字符
  // plat	num	发送平台标识	非必要	1：web端 2：安卓客户端  3：ios客户端  4：wp客户端
  static Future replyAdd({
    required ReplyType type,
    required int oid,
    required String message,
    int? root,
    int? parent,
  }) async {
    if (message == '') {
      return {'status': false, 'data': [], 'msg': '请输入评论内容'};
    }
    var res = await Request().post(Api.replyAdd, queryParameters: {
      'type': type.index,
      'oid': oid,
      'root': root == null || root == 0 ? '' : root,
      'parent': parent == null || parent == 0 ? '' : parent,
      'message': message,
      'csrf': await Request.getCsrf(),
    });
    log(res.toString());
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  static Future replyDel({
    required int type, //replyType
    required int oid,
    required int rpid,
  }) async {
    var res = await Request().post(Api.replyDel, queryParameters: {
      'type': type, //type.index
      'oid': oid,
      'rpid': rpid,
      'csrf': await Request.getCsrf(),
    });
    log(res.toString());
    if (res.data['code'] == 0) {
      return {'status': true};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 查询是否关注up
  static Future hasFollow({required int mid}) async {
    var res = await Request().get(Api.hasFollow, data: {'fid': mid});
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': []};
    }
  }

  // 操作用户关系
  static Future relationMod(
      {required int mid, required int act, required int reSrc}) async {
    var res = await Request().post(Api.relationMod, queryParameters: {
      'fid': mid,
      'act': act,
      're_src': reSrc,
      'csrf': await Request.getCsrf(),
    });
    print(res);
    if (res.data['code'] == 0) {
      return {'status': true};
    } else {
      return {'status': false, 'msg': res.data['message']};
    }
  }

  // 视频播放进度
  static Future heartBeat({bvid, cid, progress, realtime}) async {
    await Request().post(Api.heartBeat, queryParameters: {
      // 'aid': aid,
      'bvid': bvid,
      'cid': cid,
      // 'epid': '',
      // 'sid': '',
      // 'mid': '',
      'played_time': progress,
      // 'realtime': realtime,
      // 'type': '',
      // 'sub_type': '',
      'csrf': await Request.getCsrf(),
    });
  }

  // 添加追番
  static Future bangumiAdd({int? seasonId}) async {
    var res = await Request().post(Api.bangumiAdd, queryParameters: {
      'season_id': seasonId,
      'csrf': await Request.getCsrf(),
    });
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'msg':
            res.data['result'] == null ? 'failed' : res.data['result']['toast']
      };
    } else {
      return {
        'status': false,
        'msg':
            res.data['result'] == null ? 'failed' : res.data['result']['toast']
      };
    }
  }

  // 取消追番
  static Future bangumiDel({int? seasonId}) async {
    var res = await Request().post(Api.bangumiDel, queryParameters: {
      'season_id': seasonId,
      'csrf': await Request.getCsrf(),
    });
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'msg':
            res.data['result'] == null ? 'failed' : res.data['result']['toast']
      };
    } else {
      return {
        'status': false,
        'msg':
            res.data['result'] == null ? 'failed' : res.data['result']['toast']
      };
    }
  }

  // 查看视频同时在看人数
  static Future onlineTotal({int? aid, String? bvid, int? cid}) async {
    var res = await Request().get(Api.onlineTotal, data: {
      'aid': aid,
      'bvid': bvid,
      'cid': cid,
    });
    if (res.data['code'] == 0) {
      return {'status': true, 'data': res.data['data']};
    } else {
      return {'status': false, 'data': null, 'msg': res.data['message']};
    }
  }

  static Future aiConclusion({
    String? bvid,
    int? cid,
    int? upMid,
  }) async {
    Map params = await WbiSign().makSign({
      'bvid': bvid,
      'cid': cid,
      'up_mid': upMid,
    });
    var res = await Request().get(Api.aiConclusion, data: params);
    if (res.data['code'] == 0 && res.data['data']['code'] == 0) {
      return {
        'status': true,
        'data': AiConclusionModel.fromJson(res.data['data']),
      };
    } else {
      return {'status': false, 'data': []};
    }
  }

  static Future videoMetaInfo(
      {String? aid, String? bvid, required int cid}) async {
    assert(aid != null || bvid != null);
    var res = await Request().get(Api.videoMetaInfo, data: {
      if (aid != null) 'aid': aid,
      if (bvid != null) 'bvid': bvid,
      'cid': cid,
    });
    if (res.data['code'] == 0) {
      dynamic data = res.data['data'];
      List subtitlesJson = data['subtitle']['subtitles'];
      /*
      [
        {
          "id": 1430455228267894300,
          "lan": "ai-zh",
          "lan_doc": "中文（自动生成）",
          "is_lock": false,
          "subtitle_url": "//aisubtitle.hdslb.com/bfs/ai_subtitle/prod/15508958271448462983dacf99a49f40ccdf91a4df8d925e2b58?auth_key=1708941835-aaa0e44844594386ad356795733983a2-0-89af73c6aad5a1fca43b02113fa9d485",
          "type": 1,
          "id_str": "1430455228267894272",
          "ai_type": 0,
          "ai_status": 2
        }
      ]
       */
      return {
        'status': true,
        'data': subtitlesJson,
      };
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }

  static Future vttSubtitles(List subtitlesJson) async {
    if (subtitlesJson.isEmpty) {
      return [];
    }
    List<Map<String, String>> subtitlesVtt = [];

    String subtitleTimecode(num seconds) {
      int h = (seconds / 3600).floor();
      int m = ((seconds % 3600) / 60).floor();
      int s = (seconds % 60).floor();
      int ms = ((seconds * 1000) % 1000).floor();
      if (h == 0) {
        return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}";
      }
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}";
    }

    for (var i in subtitlesJson) {
      var res =
          await Request().get("https://${i['subtitle_url'].split('//')[1]}");
      /*
          {
            "font_size": 0.4,
            "font_color": "#FFFFFF",
            "background_alpha": 0.5,
            "background_color": "#9C27B0",
            "Stroke": "none",
            "type": "AIsubtitle",
            "lang": "zh",
            "version": "v1.6.0.4",
            "body": [
              {
                "from": 0.5,
                "to": 1.58,
                "sid": 1,
                "location": 2,
                "content": "很多人可能不知道",
                "music": 0.0
              },
              ……,
              {
                "from": 558.629,
                "to": 560.22,
                "sid": 280,
                "location": 2,
                "content": "我们下期再见",
                "music": 0.0
              }
            ]
          }
         */
      if (res.data != null) {
        String vttData = "WEBVTT\n\n";
        for (var item in res.data['body']) {
          vttData += "${item['sid'] ?? 0}\n";
          vttData +=
              "${subtitleTimecode(item['from'])} --> ${subtitleTimecode(item['to'])}\n";
          vttData += "${item['content'].trim()}\n\n";
        }
        subtitlesVtt.add({
          'language': i['lan'],
          'title': i['lan_doc'],
          'text': vttData,
        });
      } else {
        SmartDialog.showToast("字幕${i['lan_doc']}加载失败, ${res.data['message']}");
      }
    }
    if (subtitlesVtt.isNotEmpty) {
      subtitlesVtt.insert(0, {'language': '', 'title': '关闭字幕', 'text': ""});
    }
    return subtitlesVtt;
  }

  // 视频排行
  static Future getRankVideoList(int rid) async {
    try {
      var rankApi = "${Api.getRankApi}?rid=$rid&type=all";
      var res = await Request().get(rankApi);
      if (res.data['code'] == 0) {
        List<HotVideoItemModel> list = [];
        List<int> blackMidsList = onlineCache
            .get(OnlineCacheKey.blackMidsList, defaultValue: [-1])
            .map<int>((e) => e as int)
            .toList();
        for (var i in res.data['data']['list']) {
          if (!blackMidsList.contains(i['owner']['mid'])) {
            list.add(HotVideoItemModel.fromJson(i));
          }
        }
        return {'status': true, 'data': list};
      } else {
        return {'status': false, 'data': [], 'msg': res.data['message']};
      }
    } catch (err) {
      return {'status': false, 'data': [], 'msg': err};
    }
  }

  // 视频分区
  static Future getRegionVideoList(int tid, int pn, int ps) async {
    var res = await Request().get(Api.getRegionApi, data: {
      'rid': tid,
      'pn': pn,
      'ps': ps,
    });
    print("getRegionVideoList: $res");
    if (res.data['code'] == 0) {
      List<HotVideoItemModel> list = [];
      List<int> blackMidsList = onlineCache
          .get(OnlineCacheKey.blackMidsList, defaultValue: [-1])
          .map<int>((e) => e as int)
          .toList();
      print(res.data['data']['archives']);
      for (var i in res.data['data']['archives']) {
        if (!blackMidsList.contains(i['owner']['mid'])) {
          list.add(HotVideoItemModel.fromJson(i));
        }
      }
      return {'status': true, 'data': list};
    } else {
      return {'status': false, 'data': [], 'msg': res.data['message']};
    }
  }
}
