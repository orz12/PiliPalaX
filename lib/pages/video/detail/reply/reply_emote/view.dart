import 'dart:async';
import 'package:PiliPalaX/models/user/my_emote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../../../../common/widgets/network_img_layer.dart';
import '../../../../../http/reply.dart';

class EmoteTab extends StatefulWidget {
  final Function(String) onEmoteTap;
  const EmoteTab({Key? key, required this.onEmoteTap}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _EmoteTabState();
}

class _EmoteTabState extends State<EmoteTab> with TickerProviderStateMixin {
  late TabController _myEmoteTabController;
  late MyEmote myEmote;
  late Future futureBuild;
  int startIndex = 0;
  int tabsCount = 3;
  Future getMyEmote() async {
    var result = await ReplyHttp.getMyEmote(business: "reply");
    if (result['status']) {
      myEmote = MyEmote.fromJson(result['data']);
      _myEmoteTabController = TabController(
          length: myEmote.packages!.length,
          initialIndex: myEmote.setting!.focusPkgId! - 1,
          vsync: this);
      startIndex = myEmote.setting!.focusPkgId! - 1;
    } else {
      SmartDialog.showToast(result['msg']);
      myEmote = MyEmote();
    }
    return;
  }

  @override
  void initState() {
    super.initState();
    futureBuild = getMyEmote();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: futureBuild,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              myEmote.packages != null) {
            return Column(
              children: [
                Expanded(child: TabBarView(controller: _myEmoteTabController, children: [
                  for (Packages i in myEmote.packages!) ...<Widget>[
                    GridView.builder(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: i.type == 4 ? 100 : 36,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 36,
                      ),
                      itemCount: i.emote!.length,
                      itemBuilder: (BuildContext context, int index) {
                        return GestureDetector(
                          onTap: () {
                            widget.onEmoteTap(i.emote![index].text!);
                          },
                          child: i.type == 4
                              ? Text(i.emote![index].text!,overflow: TextOverflow.clip,maxLines: 1,)
                              : NetworkImgLayer(
                            width: 36,
                            height: 36,
                            type: 'emote',
                            src: i.emote![index].url,
                          ),
                        );
                      },
                    ),
                  ],
                ]),),
                SizedBox(
                    height: 45,
                    child: TabBar(
                      isScrollable: true,
                      controller: _myEmoteTabController,
                      tabs: [
                        for (var i in myEmote.packages!)
                          NetworkImgLayer(
                            width: 36,
                            height: 36,
                            type: 'emote',
                            src: i.url,
                          ),
                      ],
                    ))
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      );
  }
}
