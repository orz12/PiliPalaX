// ignore: camel_case_types
enum BtmProgressBehavior {
  alwaysShow,
  alwaysHide,
  onlyShowFullScreen,
  onlyHideFullScreen,
}

extension BtmProgresBehaviorDesc on BtmProgressBehavior {
  String get description => ['始终展示', '始终隐藏', '仅全屏时展示', '仅全屏时隐藏'][index];
}

extension BtmProgresBehaviorCode on BtmProgressBehavior {
  static final List<int> _codeList = [0, 1, 2, 3];
  int get code => _codeList[index];

  static BtmProgressBehavior? fromCode(int code) {
    final index = _codeList.indexOf(code);
    if (index != -1) {
      return BtmProgressBehavior.values[index];
    }
    return null;
  }
}
