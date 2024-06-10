import 'dart:convert';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controller.dart';

class SysMsgPage extends StatefulWidget {
  const SysMsgPage({super.key});

  @override
  State<SysMsgPage> createState() => _SysMsgPageState();
}

class _SysMsgPageState extends State<SysMsgPage> {
  late final SysMsgController _sysMsgController = Get.put(SysMsgController());
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    _sysMsgController.queryMsgFeedSysMsg();
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  Future _scrollListener() async {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      EasyThrottle.throttle('my-throttler', const Duration(milliseconds: 800),
          () async {
        await _sysMsgController.onLoad();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统通知'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _sysMsgController.onRefresh();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            return Obx(
              () {
                if (_sysMsgController.msgFeedSysMsgList.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                return ListView.separated(
                  itemCount: _sysMsgController.msgFeedSysMsgList.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (_, int i) {
                    String? content = _sysMsgController.msgFeedSysMsgList[i].content;
                    if (content != null) {
                      try {
                        dynamic jsonContent = json.decode(content);
                        if (jsonContent != null && jsonContent['web'] != null) {
                          content = jsonContent['web'];
                        }
                      } catch (_) {}
                    }
                    return ListTile(
                        onTap: () {},
                        title: Text(
                          "${_sysMsgController.msgFeedSysMsgList[i].title}",
                          style: Theme.of(context).textTheme.titleMedium!.copyWith(
                              color: Theme.of(context).colorScheme.primary
                          ),
                        ),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                          Text(
                              "$content",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline)),
                              const SizedBox(height: 4),
                          Text(
                              "${_sysMsgController.msgFeedSysMsgList[i].timeAt}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline.withOpacity(0.8))),
                        ]));
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return Divider(
                      indent: 72,
                      endIndent: 20,
                      height: 6,
                      color: Colors.grey.withOpacity(0.1),
                    );
                  },
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
