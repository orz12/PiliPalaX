import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebviewPage extends StatefulWidget {
  const WebviewPage({super.key});

  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  final WebviewController _webviewController = Get.put(WebviewController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          title: Text(
            _webviewController.pageTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          actions: [
            const SizedBox(width: 4),
            IconButton(
              tooltip: '刷新网页',
              onPressed: () {
                _webviewController.controller.reload();
              },
              icon: Icon(Icons.refresh_outlined,
                  color: Theme.of(context).colorScheme.primary),
            ),
            if (_webviewController.type.value != 'login')
              IconButton(
                tooltip: '用外部浏览器打开',
                onPressed: () {
                  launchUrl(Uri.parse(_webviewController.url));
                },
                icon: Icon(Icons.open_in_browser_outlined,
                    color: Theme.of(context).colorScheme.primary),
              ),
            if (_webviewController.type.value == 'login') ...<Widget>[
              TextButton(
                onPressed: () => _webviewController.confirmLogin(null),
                child: const Text('刷新登录态'),
              ),
              TextButton(
                child: const Text('电脑版'),
                onPressed: () => _webviewController.webviewInit(uaType: 'pc'),
              )
            ],
            const SizedBox(width: 12)
          ],
        ),
        body: Column(
          children: [
            Obx(
              () => AnimatedContainer(
                curve: Curves.easeInOut,
                duration: const Duration(milliseconds: 350),
                height: _webviewController.loadShow.value ? 4 : 0,
                child: LinearProgressIndicator(
                  key: ValueKey(_webviewController.loadProgress),
                  value: _webviewController.loadProgress / 100,
                ),
              ),
            ),
            if (_webviewController.type.value == 'login') ...<Widget>[
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.onInverseSurface,
                padding: const EdgeInsets.only(
                    left: 12, right: 12, top: 6, bottom: 6),
                child: const Text('登录成功未自动跳转? 请点击右上角「刷新登录态」'),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.onInverseSurface,
                padding: const EdgeInsets.only(
                    left: 12, right: 12, top: 6, bottom: 6),
                child: const Text(
                    '如需二维码登录，请点击「电脑版」，放大左侧二维码，截图后官方app或另一设备扫码，授权后点击「刷新登录态」'),
              ),
            ],
            Expanded(
              child: WebViewWidget(
                  controller: _webviewController.controller,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer(),
                    ),
                    Factory<PanGestureRecognizer>(
                      () => PanGestureRecognizer(),
                    ),
                    Factory<ForcePressGestureRecognizer>(
                      () => ForcePressGestureRecognizer(),
                    ),
                    Factory<EagerGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                    Factory<HorizontalDragGestureRecognizer>(
                      () => HorizontalDragGestureRecognizer(),
                    ),
                  }),
            ),
          ],
        ));
  }
}
