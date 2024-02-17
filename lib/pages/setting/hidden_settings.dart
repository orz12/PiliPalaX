import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HiddenSetting extends StatefulWidget {
  const HiddenSetting({super.key});

  @override
  State<HiddenSetting> createState() => _HiddenSettingState();
}

class _HiddenSettingState extends State<HiddenSetting> {

  @override
  void initState() {
    super.initState();
  }

  void test(Object? val) {
    print(val);
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
          '开发人员选项',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: Column(
        children: [
          ListTile(
            title: Text('手动产生异常', style: titleStyle),
            dense: false,
            subtitle: Column(
              children: [
                ListTile(
                  onTap: () {
                    test([][0]);
                  },
                  dense: true,
                  title: const Text('数组越界'),
                ),
                ListTile(
                  onTap: () {
                    test(null!.value);
                  },
                  dense: true,
                  title: const Text('非空断言'),
                ),
                ListTile(
                  onTap: () {
                    test(int.parse("壹"));
                  },
                  dense: true,
                  title: const Text('非法整数解析'),
                ),
                ListTile(
                  onTap: () {
                    test(DateTime.parse("2050-01-aa"));
                  },
                  dense: true,
                  title: const Text('非法日期解析'),
                ),
                ListTile(
                  onTap: () {
                    throw Exception("测试异常");
                  },
                  dense: true,
                  title: const Text('抛出测试异常'),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('查看日志'),
            onTap: () {
              Get.toNamed('/logs');
            },
          ),
        ],
      ),
    );
  }
}
