import 'package:flutter/material.dart';

class ComBtn extends StatelessWidget {
  final Widget? icon;
  final Function? fuc;
  final String tooltip;

  const ComBtn({
    this.icon,
    this.fuc,
    required this.tooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        tooltip: tooltip,
        style: ButtonStyle(
          padding: MaterialStateProperty.all(EdgeInsets.zero),
        ),
        onPressed: () {
          fuc!();
        },
        icon: icon!,
      ),
    );
  }
}
