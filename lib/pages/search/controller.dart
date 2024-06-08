import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_workers/utils/debouncer.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/http/search.dart';
import 'package:PiliPalaX/models/search/hot.dart';
import 'package:PiliPalaX/models/search/suggest.dart';
import 'package:PiliPalaX/utils/storage.dart';

class SSearchController extends GetxController {
  final FocusNode searchFocusNode = FocusNode();
  RxString searchKeyWord = ''.obs;
  Rx<TextEditingController> controller = TextEditingController().obs;
  RxList<HotSearchItem> hotSearchList = <HotSearchItem>[].obs;
  Box historyWord = GStorage.historyWord;
  List<String> historyCacheList = [];
  RxList<String> historyList = <String>[].obs;
  RxList<SearchSuggestItem> searchSuggestList = <SearchSuggestItem>[].obs;
  final _debouncer =
      Debouncer(delay: const Duration(milliseconds: 200)); // 设置延迟时间
  String hintText = '搜索';
  RxString defaultSearch = ''.obs;
  Box setting = GStorage.setting;
  bool enableHotKey = true;

  @override
  void onInit() {
    super.onInit();
    // 其他页面跳转过来
    if (Get.parameters.keys.isNotEmpty) {
      if (Get.parameters['keyword'] != null) {
        onClickKeyword(Get.parameters['keyword']!);
      }
      if (Get.parameters['hintText'] != null) {
        hintText = Get.parameters['hintText']!;
        searchKeyWord.value = hintText;
      }
    }
    historyCacheList = List<String>.from(historyWord.get('cacheList')??[]);
    historyList.value = historyCacheList;
    enableHotKey = setting.get(SettingBoxKey.enableHotKey, defaultValue: true);
  }

  void onChange(value) {
    searchKeyWord.value = value;
    if (value == '') {
      searchSuggestList.value = [];
      return;
    }
    _debouncer.call(() => querySearchSuggest(value));
  }

  void onClear() {
    if (searchKeyWord.value.isNotEmpty && controller.value.text != '') {
      controller.value.clear();
      searchKeyWord.value = '';
      searchSuggestList.value = [];
    } else {
      Get.back();
    }
  }

  // 搜索
  void submit() {
    // ignore: unrelated_type_equality_checks
    if (searchKeyWord == '') {
      if (hintText == ''){
        return;
      }
      searchKeyWord.value = hintText;
    }
    List<String> arr = historyCacheList.where((e) => e != searchKeyWord.value).toList();
    arr.insert(0, searchKeyWord.value);
    historyCacheList = arr;

    historyList.value = historyCacheList;
    // 手动刷新
    historyList.refresh();
    historyWord.put('cacheList', historyCacheList);
    searchFocusNode.unfocus();
    Get.toNamed('/searchResult', parameters: {'keyword': searchKeyWord.value});
  }

  // 获取热搜关键词
  Future queryHotSearchList() async {
    var result = await SearchHttp.hotSearchList();
    if (result['status']) {
      hotSearchList.value = result['data'].list;
    }
    return result;
  }

  // 点击热搜关键词
  void onClickKeyword(String keyword) {
    searchKeyWord.value = keyword;
    controller.value.text = keyword;
    // 移动光标
    controller.value.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.value.text.length),
    );
    submit();
  }

  Future querySearchSuggest(String value) async {
    var result = await SearchHttp.searchSuggest(term: value);
    if (result['status']) {
      if (result['data'] is SearchSuggestModel) {
        searchSuggestList.value = result['data'].tag;
      }
    }
  }

  onSelect(word) {
    searchKeyWord.value = word;
    controller.value.text = word;
    submit();
  }

  onLongSelect(word) {
    int index = historyList.indexOf(word);
    historyList.removeAt(index);
    historyWord.put('cacheList', historyList);
  }

  onClearHis() {
    historyList.value = [];
    historyCacheList = [];
    historyList.refresh();
    historyWord.put('cacheList', []);
  }
}
