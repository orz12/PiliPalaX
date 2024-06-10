import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:hive/hive.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/pages/emote/index.dart';
import 'package:PiliPalaX/pages/whisper_detail/controller.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import '../../utils/storage.dart';
import 'widget/chat_item.dart';

class WhisperDetailPage extends StatefulWidget {
  const WhisperDetailPage({super.key});

  @override
  State<WhisperDetailPage> createState() => _WhisperDetailPageState();
}

class _WhisperDetailPageState extends State<WhisperDetailPage>
    with WidgetsBindingObserver {
  final WhisperDetailController _whisperDetailController =
      Get.put(WhisperDetailController());
  late TextEditingController _replyContentController;
  final FocusNode replyContentFocusNode = FocusNode();
  final _debouncer = Debouncer(milliseconds: 200); // 设置延迟时间
  late double emoteHeight = 0.0;
  double keyboardHeight = 0.0; // 键盘高度
  String toolbarType = 'input';
  Box userInfoCache = GStrorage.userInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _whisperDetailController.querySessionMsg();
    _replyContentController = _whisperDetailController.replyContentController;
    _focuslistener();
  }

  _focuslistener() {
    replyContentFocusNode.addListener(() {
      if (replyContentFocusNode.hasFocus) {
        setState(() {
          toolbarType = 'input';
        });
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final String routePath = Get.currentRoute;
    if (mounted && routePath.startsWith('/whisper_detail')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // 键盘高度
        final viewInsets = EdgeInsets.fromViewPadding(
            View.of(context).viewInsets, View.of(context).devicePixelRatio);
        _debouncer.run(() {
          if (!mounted) return;
          if (keyboardHeight == 0) {
            setState(() {
              emoteHeight = keyboardHeight =
                  keyboardHeight == 0.0 ? viewInsets.bottom : keyboardHeight;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    replyContentFocusNode.removeListener(() {});
    replyContentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: SizedBox(
          width: double.infinity,
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  tooltip: '返回',
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all(EdgeInsets.zero),
                    backgroundColor: MaterialStateProperty.resolveWith(
                        (Set<MaterialState> states) {
                      return Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.6);
                    }),
                  ),
                  onPressed: () => Get.back(),
                  icon: Icon(
                    Icons.arrow_back_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  feedBack();
                  Get.toNamed(
                    '/member?mid=${_whisperDetailController.mid}',
                    arguments: {
                      'face': _whisperDetailController.face,
                      'heroTag': null
                    },
                  );
                },
                child: Row(
                  children: <Widget>[
                    NetworkImgLayer(
                      width: 34,
                      height: 34,
                      type: 'avatar',
                      src: _whisperDetailController.face,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _whisperDetailController.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 36, height: 36),
            ],
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            keyboardHeight = 0;
          });
        },
        child: Obx(() {
          List messageList = _whisperDetailController.messageList;
          if (messageList.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return ListView.builder(
            itemCount: messageList.length,
            shrinkWrap: true,
            reverse: true,
            itemBuilder: (_, int i) {
              return ChatItem(
                  item: messageList[i],
                  e_infos: _whisperDetailController.eInfos);
            },
          );
        }),
      ),
      // resizeToAvoidBottomInset: true,
      bottomNavigationBar: Container(
        width: double.infinity,
        height: MediaQuery.of(context).padding.bottom + 70 + keyboardHeight,
        padding: EdgeInsets.only(
          left: 8,
          right: 12,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              width: 4,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IconButton(
                //   onPressed: () {},
                //   icon: Icon(
                //     Icons.add_circle_outline,
                //     color: Theme.of(context).colorScheme.outline,
                //   ),
                // ),
                IconButton(
                  tooltip: '表情',
                  onPressed: () {
                    // if (toolbarType == 'input') {
                    //   setState(() {
                    //     toolbarType = 'emote';
                    //   });
                    // }
                    // FocusScope.of(context).unfocus();
                  },
                  icon: Icon(
                    Icons.emoji_emotions_outlined,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(40.0),
                    ),
                    child: Semantics(
                        label: '私信输入框（开发中）',
                        child: TextField(
                          readOnly: true,
                          style: Theme.of(context).textTheme.titleMedium,
                          controller: _replyContentController,
                          autofocus: false,
                          focusNode: replyContentFocusNode,
                          decoration: const InputDecoration(
                            border: InputBorder.none, // 移除默认边框
                            hintText: '开发中 ...', // 提示文本
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0), // 内边距
                          ),
                        )),
                  ),
                ),
                IconButton(
                  tooltip: '发送',
                  // onPressed: _whisperDetailController.sendMsg,
                  onPressed: null,
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                // const SizedBox(width: 16),
              ],
            ),
            AnimatedSize(
              curve: Curves.easeInOut,
              duration: const Duration(milliseconds: 300),
              child: SizedBox(
                width: double.infinity,
                height: toolbarType == 'input' ? keyboardHeight : emoteHeight,
                child: EmotePanel(
                  onChoose: (package, emote) => {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef DebounceCallback = void Function();

class Debouncer {
  DebounceCallback? callback;
  final int? milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds});

  run(DebounceCallback callback) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds!), () {
      callback();
    });
  }
}
