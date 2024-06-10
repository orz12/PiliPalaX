import 'package:get/get.dart';
import '../../pages/dynamics/tab/controller.dart';
import '../../pages/dynamics/tab/view.dart';

enum DynamicsType {
  all,
  video,
  pgc,
  article,
  up,
}

extension BusinessTypeExtension on DynamicsType {
  String get values => ['all', 'video', 'pgc', 'article', 'up'][index];
  String get labels => ['全部', '投稿', '番剧', '专栏', 'Up'][index];
}

List tabsConfig = [
  {
    'value': DynamicsType.all,
    'label': '全部',
    'enabled': true,
    'ctr': Get.put<DynamicsTabController>(DynamicsTabController(), tag: 'all'),
    'page': const DynamicsTabPage(dynamicsType: 'all'),
  },
  {
    'value': DynamicsType.video,
    'label': '投稿',
    'enabled': true,
    'ctr':
        Get.put<DynamicsTabController>(DynamicsTabController(), tag: 'video'),
    'page': const DynamicsTabPage(dynamicsType: 'video'),
  },
  {
    'value': DynamicsType.pgc,
    'label': '番剧',
    'enabled': true,
    'ctr': Get.put<DynamicsTabController>(DynamicsTabController(), tag: 'pgc'),
    'page': const DynamicsTabPage(dynamicsType: 'pgc'),
  },
  {
    'value': DynamicsType.article,
    'label': '专栏',
    'enabled': true,
    'ctr':
        Get.put<DynamicsTabController>(DynamicsTabController(), tag: 'article'),
    'page': const DynamicsTabPage(dynamicsType: 'article'),
  },
  {
    'value': DynamicsType.up,
    'label': 'Up',
    'enabled': true,
    'ctr': Get.put<DynamicsTabController>(DynamicsTabController(), tag: 'up'),
    'page': const DynamicsTabPage(dynamicsType: 'up'),
  },
];
