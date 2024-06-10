import 'package:flutter/material.dart';
import 'package:PiliPalaX/utils/feed_back.dart';

class ActionItem extends StatelessWidget {
  final Icon? icon;
  final Icon? selectIcon;
  final Function? onTap;
  final Function? onLongPress;
  final bool? loadingStatus;
  final String? text;
  final bool selectStatus;
  final String semanticsLabel;

  const ActionItem({
    Key? key,
    this.icon,
    this.selectIcon,
    this.onTap,
    this.onLongPress,
    this.loadingStatus,
    this.text,
    this.selectStatus = false,
    required this.semanticsLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Semantics(
            label: (text ?? "") + (selectStatus ? "已" : "") + semanticsLabel,
            child: InkWell(
              onTap: () => {
                feedBack(),
                onTap!(),
              },
              onLongPress: () => {
                if (onLongPress != null) {onLongPress!()}
              },
              // borderRadius: StyleString.mdRadius,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // const SizedBox(height: 2),
                  Icon(
                    selectStatus ? selectIcon!.icon! : icon!.icon!,
                    size: 18,
                    color: selectStatus
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 3),
                  AnimatedOpacity(
                    opacity: loadingStatus! ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Text(
                        text ?? '',
                        key: ValueKey<String>(text ?? ''),
                        style: TextStyle(
                            color: selectStatus
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                            fontSize: Theme.of(context)
                                .textTheme
                                .labelSmall!
                                .fontSize),
                        semanticsLabel: "",
                      ),
                    ),
                  ),
                ],
              ),
            )));
  }
}
