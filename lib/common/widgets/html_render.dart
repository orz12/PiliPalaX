import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import '../../utils/storage.dart';
import 'network_img_layer.dart';

// ignore: must_be_immutable
class HtmlRender extends StatelessWidget {
  const HtmlRender({
    this.htmlContent,
    this.imgCount,
    this.imgList,
    super.key,
  });

  final String? htmlContent;
  final int? imgCount;
  final List<String>? imgList;

  @override
  Widget build(BuildContext context) {
    double textScale =
        setting.get(SettingBoxKey.defaultTextScale, defaultValue: 1.0);
    return Html(
      data: htmlContent,
      onLinkTap: (String? url, Map<String, String> buildContext, attributes) {},
      extensions: [
        TagExtension(
          tagsToExtend: <String>{'img'},
          builder: (ExtensionContext extensionContext) {
            try {
              final Map<String, dynamic> attributes =
                  extensionContext.attributes;
              final List<dynamic> key = attributes.keys.toList();
              String imgUrl = key.contains('src')
                  ? attributes['src'] as String
                  : attributes['data-src'] as String;
              if (imgUrl.startsWith('//')) {
                imgUrl = 'https:$imgUrl';
              }
              if (imgUrl.startsWith('http://')) {
                imgUrl = imgUrl.replaceAll('http://', 'https://');
              }
              imgUrl = imgUrl.contains('@') ? imgUrl.split('@').first : imgUrl;
              final bool isEmote = imgUrl.contains('/emote/');
              final bool isMall = imgUrl.contains('/mall/');
              if (isMall) {
                return const SizedBox();
              }
              // bool inTable =
              //     extensionContext.element!.previousElementSibling == null ||
              //         extensionContext.element!.nextElementSibling == null;
              // imgUrl = Utils().imageUrl(imgUrl!);
              // return Image.network(
              //   imgUrl,
              //   width: isEmote ? 22 : null,
              //   height: isEmote ? 22 : null,
              // );
              return NetworkImgLayer(
                width: isEmote ? 22 : (Get.size.width - 23) / textScale,
                height: isEmote ? 22 : 200,
                src: imgUrl,
                ignoreHeight: !isEmote,
              );
            } catch (err) {
              return const SizedBox();
            }
          },
        ),
      ],
      style: {
        'html': Style(
          fontSize: FontSize.large,
          lineHeight: LineHeight.percent(160),
          letterSpacing: 0.3,
        ),
        // 'br': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
        'a': Style(
          color: Theme.of(context).colorScheme.primary,
          textDecoration: TextDecoration.none,
        ),
        'br': Style(
          lineHeight: LineHeight.percent(-1),
        ),
        'p': Style(
          margin: Margins.only(bottom: 4),
          // margin: Margins.zero,
        ),
        'span': Style(
          fontSize: FontSize.medium,
          height: Height(1.8),
        ),
        'div': Style(height: Height.auto()),
        'li > p': Style(
          display: Display.inline,
        ),
        'li': Style(
          padding: HtmlPaddings.only(bottom: 4),
          textAlign: TextAlign.justify,
        ),
        'img': Style(margin: Margins.only(top: 4, bottom: 4)),
        'h1,h2': Style(
          fontSize: FontSize.xLarge,
          fontWeight: FontWeight.bold,
          margin: Margins.only(bottom: 8),
        ),
        'h3,h4,h5': Style(
          fontSize: FontSize.large,
          fontWeight: FontWeight.bold,
          margin: Margins.only(bottom: 4),
        ),
        'figcaption': Style(
          fontSize: FontSize.medium,
          textAlign: TextAlign.center,
          // margin: Margins.only(top: 4),
        ),
        'strong': Style(fontWeight: FontWeight.bold),
        'figure': Style(
          margin: Margins.zero,
        ),
      },
    );
  }
}
