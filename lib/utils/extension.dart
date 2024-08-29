import 'package:flutter/material.dart';

extension ImageExtension on num {
  int cacheSize(BuildContext context) {
    return (this * MediaQuery.of(context).devicePixelRatio).round();
  }
}

extension ScrollControllerExt on ScrollController {
  void animToTop() {
    animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
  }
}
