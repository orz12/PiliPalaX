import 'dart:convert';
import 'dart:io';

import 'package:PiliPalaX/http/constants.dart';
import 'package:PiliPalaX/http/init.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

class CookieTool {
  static exportCookie() async {
    Map<String, String> allCookies = {};
    List<String> Urls = [HttpString.baseUrl, HttpString.apiBaseUrl, HttpString.tUrl];
    for (var url in Urls) {
      allCookies[url] = await WebviewCookieManager().getCookies(url)
          .then((cookies) => cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; '));
    }
    return jsonEncode(allCookies);
  }
  static importCookie(String cookie) async {
    var allCookies = jsonDecode(cookie);
    for (var url in allCookies.keys) {
      List<String> cookiesStringList = allCookies[url]!.split('; ');
      List<Cookie> cookies = [];
      for (var c in cookiesStringList) {
        List<String> kv = c.split('=');
        cookies.add(Cookie(kv[0], kv[1]));
      }
      await Request.cookieManager.cookieJar.saveFromResponse(Uri.parse(url), cookies);
      if (url == HttpString.baseUrl) {
        Request.dio.options.headers['cookie'] = allCookies[url];
      }
    }
  }
  static onSet() async {
    var cookies = await WebviewCookieManager().getCookies(HttpString.baseUrl);
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.baseUrl), cookies);
    var cookieString =
        cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
    Request.dio.options.headers['cookie'] = cookieString;

    cookies = await WebviewCookieManager().getCookies(HttpString.apiBaseUrl);
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.apiBaseUrl), cookies);

    cookies = await WebviewCookieManager().getCookies(HttpString.tUrl);
    await Request.cookieManager.cookieJar
        .saveFromResponse(Uri.parse(HttpString.tUrl), cookies);
  }
}
