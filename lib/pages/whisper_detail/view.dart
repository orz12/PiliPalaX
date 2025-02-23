import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:hive/hive.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/pages/emote/index.dart';
import 'package:PiliPalaX/pages/whisper_detail/controller.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/models/video/reply/emote.dart';
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
  String toolbarType = 'none';
  Box userInfoCache = GStorage.userInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _whisperDetailController.querySessionMsg();
    _replyContentController = _whisperDetailController.replyContentController;
    _focusListener();
  }

  _focusListener() {
    replyContentFocusNode.addListener(() {
      if (replyContentFocusNode.hasFocus) {
        setState(() {
          toolbarType = 'input';
        });
      } else if (toolbarType == 'input') {
        setState(() {
          toolbarType = 'none';
        });
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _debouncer.run(() {
        if (!mounted) return;
        // 键盘高度
        final viewInsets = EdgeInsets.fromViewPadding(
            View.of(context).viewInsets, View.of(context).devicePixelRatio);
        if (keyboardHeight == 0) {
          emoteHeight = keyboardHeight =
              keyboardHeight == 0.0 ? viewInsets.bottom : keyboardHeight;
          if (emoteHeight == 0 || emoteHeight < keyboardHeight) {
            emoteHeight = keyboardHeight;
          }
          if (emoteHeight < 200) emoteHeight = 200;
          setState(() {});
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    replyContentFocusNode.removeListener(() {});
    replyContentFocusNode.dispose();
    super.dispose();
  }

  void onChooseEmote(Packages package, Emote emote) {
    int cursorPosition = _replyContentController.selection.baseOffset;
    if (cursorPosition == -1) cursorPosition = 0;
    final String currentText = _replyContentController.text;
    final String newText = currentText.substring(0, cursorPosition) +
        emote.text! +
        currentText.substring(cursorPosition);
    _replyContentController.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: cursorPosition + emote.text!.length),
    );
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
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    backgroundColor: WidgetStateProperty.resolveWith(
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
          setState(() {
            toolbarType = 'none';
          });
          FocusScope.of(context).unfocus();
        },
        child: Obx(() {
          List messageList = _whisperDetailController.messageList;
          if (messageList.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return RefreshIndicator(
              displacement: 10.0,
              edgeOffset: 10.0,
              onRefresh: _whisperDetailController.querySessionMsg,
              child: ListView.builder(
                itemCount: messageList.length,
                shrinkWrap: true,
                reverse: true,
                itemBuilder: (_, int i) {
                  return ChatItem(
                      item: messageList[i],
                      e_infos: _whisperDetailController.eInfos);
                },
                padding: const EdgeInsets.only(bottom: 20),
              ));
        }),
      ),
      // resizeToAvoidBottomInset: true,
      bottomNavigationBar: Container(
        width: double.infinity,
        height: MediaQuery.of(context).padding.bottom +
            70 +
            (toolbarType == 'none'
                ? 0
                : (toolbarType == 'input' ? keyboardHeight : emoteHeight)),
        padding: EdgeInsets.only(
          left: 8,
          right: 12,
          top: 10,
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
                    if (emoteHeight < 200) emoteHeight = 200;
                    if (toolbarType != 'emote') {
                      setState(() {
                        toolbarType = 'emote';
                      });
                    }
                    FocusScope.of(context).unfocus();
                  },
                  icon: Icon(
                    Icons.emoji_emotions,
                    color: toolbarType == 'emote'
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
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
                        label: '私信输入框',
                        child: TextField(
                          style: Theme.of(context).textTheme.titleMedium,
                          controller: _replyContentController,
                          autofocus: false,
                          focusNode: replyContentFocusNode,
                          decoration: const InputDecoration(
                            border: InputBorder.none, // 移除默认边框
                            hintText: '发个消息聊聊呗~', // 提示文本
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0), // 内边距
                          ),
                        )),
                  ),
                ),
                IconButton(
                  tooltip: '发送',
                  onPressed: _whisperDetailController.sendMsg,
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                // const SizedBox(width: 16),
              ],
            ),
            SizedBox(
              width: double.infinity,
              height: toolbarType == 'none'
                  ? 0
                  : (toolbarType == 'input' ? keyboardHeight : emoteHeight),
              child: EmotePanel(
                onChoose: onChooseEmote,
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
