import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'dart:io';

class DownloadUtils {
  // 获取存储权限
  static Future<bool> requestStoragePer() async {
    await Permission.storage.request();
    PermissionStatus status = await Permission.storage.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      SmartDialog.show(
        useSystem: true,
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('存储权限未授权'),
            actions: [
              TextButton(
                onPressed: () async {
                  openAppSettings();
                },
                child: const Text('去授权'),
              )
            ],
          );
        },
      );
      return false;
    } else {
      return true;
    }
  }

  // 获取相册权限
  static Future<bool> requestPhotoPer() async {
    await Permission.photos.request();
    PermissionStatus status = await Permission.photos.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      // SmartDialog.show(
      //   useSystem: true,
      //   animationType: SmartAnimationType.centerFade_otherSlide,
      //   builder: (BuildContext context) {
      //     return AlertDialog(
      //       title: const Text('提示'),
      //       content: const Text('相册权限未授权'),
      //       actions: [
      //         TextButton(
      //           onPressed: () async {
      //             openAppSettings();
      //           },
      //           child: const Text('去授权'),
      //         )
      //       ],
      //     );
      //   },
      // );
      return false;
    } else {
      return true;
    }
  }

  static Future<bool> checkPermissionDependOnSdkInt() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        return await requestStoragePer();
      } else {
        return await requestPhotoPer();
      }
    }
    return await requestStoragePer();
  }
  static Future<bool> downloadImg(String imgUrl,
      {String imgType = 'cover'}) async {
    try {
      if (!await checkPermissionDependOnSdkInt()) {
      //   // return false;
      }
      SmartDialog.showLoading(msg: '正在下载原图');
      var response = await Dio()
          .get(imgUrl, options: Options(responseType: ResponseType.bytes));
      SmartDialog.dismiss();
      SmartDialog.showLoading(msg: '正在保存图片至图库');
      String picName =
          "${imgType}_${DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.').first}";
      final SaveResult result = await SaverGallery.saveImage(
        Uint8List.fromList(response.data),
        quality: 100,
        name: picName,
        fileExtension: 'jpg',
        // 保存到 PiliPalaX文件夹
        androidRelativePath: "Pictures/PiliPalaX",
        androidExistNotSave: false,
      );
      SmartDialog.dismiss();
      if (result.isSuccess) {
        await SmartDialog.showToast('「$picName」已保存 ');
      } else {
        await SmartDialog.showToast('保存失败，${result.errorMessage}');
      }
      return true;
    } catch (err) {
      SmartDialog.dismiss();
      SmartDialog.showToast(err.toString());
      return true;
    }
  }
}
