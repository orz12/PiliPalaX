import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:nil/nil.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/utils/feed_back.dart';

import '../../../common/widgets/audio_video_progress_bar.dart';

class BottomControl extends StatelessWidget implements PreferredSizeWidget {
  final PlPlayerController? controller;
  final List<Widget>? buildBottomControl;
  const BottomControl({
    this.controller,
    this.buildBottomControl,
    Key? key,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    Color colorTheme = Theme.of(context).colorScheme.primary;
    final _ = controller!;
    //阅读器限制
    Timer? _accessibilityDebounce;
    double _lastAnnouncedValue = -1;
    return Container(
      color: Colors.transparent,
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Obx(
            () {
              final int value = _.sliderPositionSeconds.value;
              final int max = _.durationSeconds.value;
              final int buffer = _.bufferedSeconds.value;
              if (value > max || max <= 0) {
                return nil;
              }
              return Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 7),
                child: Semantics(
                    // label: '${(value / max * 100).round()}%',
                    value: '${(value / max * 100).round()}%',
                    // enabled: false,
                    child: ProgressBar(
                      progress: Duration(seconds: value),
                      buffered: Duration(seconds: buffer),
                      total: Duration(seconds: max),
                      progressBarColor: colorTheme,
                      baseBarColor: Colors.white.withOpacity(0.2),
                      bufferedBarColor: colorTheme.withOpacity(0.4),
                      timeLabelLocation: TimeLabelLocation.none,
                      thumbColor: colorTheme,
                      barHeight: 3.5,
                      thumbRadius: 7,
                      onDragStart: (duration) {
                        feedBack();
                        _.onChangedSliderStart();
                      },
                      onDragUpdate: (duration) {
                        double newProgress = duration.timeStamp.inSeconds / max;
                        if ((newProgress - _lastAnnouncedValue).abs() > 0.02) {
                          _accessibilityDebounce?.cancel();
                          _accessibilityDebounce =
                              Timer(const Duration(milliseconds: 200), () {
                            SemanticsService.announce(
                                "${(newProgress * 100).round()}%",
                                TextDirection.ltr);
                            _lastAnnouncedValue = newProgress;
                          });
                        }
                        _.onUpdatedSliderProgress(duration.timeStamp);
                      },
                      onSeek: (duration) {
                        _.onChangedSliderEnd();
                        _.onChangedSlider(duration.inSeconds.toDouble());
                        _.seekTo(Duration(seconds: duration.inSeconds),
                            type: 'slider');
                        SemanticsService.announce(
                            "${(duration.inSeconds / max * 100).round()}%",
                            TextDirection.ltr);
                      },
                    )),
              );
            },
          ),
          Row(
            children: [...buildBottomControl!],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
