import 'dart:convert';

import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/models/version_model.dart';
import 'package:simple_live_app/requests/http_client.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  static const List<String> _manifestUrls = [
    // raw updates immediately; jsDelivr can cache @master for up to 12h.
    'https://raw.githubusercontent.com/myhMARS/dart_simple_live/master/assets/app_version.json',
    'https://cdn.jsdelivr.net/gh/myhMARS/dart_simple_live@master/assets/app_version.json',
    'https://fastly.jsdelivr.net/gh/myhMARS/dart_simple_live@master/assets/app_version.json',
  ];

  Future<VersionModel> _fetchLatest() async {
    Object? lastError;
    for (final url in _manifestUrls) {
      try {
        final result = await HttpClient.instance
            .getJson(
              url,
              queryParameters: {
                'ts': DateTime.now().millisecondsSinceEpoch,
              },
            )
            .timeout(const Duration(seconds: 10));
        if (result is Map) {
          return VersionModel.fromJson(Map<String, dynamic>.from(result));
        }
        if (result is String) {
          final decoded = json.decode(result);
          if (decoded is Map) {
            return VersionModel.fromJson(Map<String, dynamic>.from(decoded));
          }
        }
        throw const FormatException('版本信息格式错误');
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('检查更新失败');
  }

  int get _currentVersionNum {
    final buildNumber = int.tryParse(Utils.packageInfo.buildNumber);
    if (buildNumber != null && buildNumber > 0) {
      return buildNumber;
    }
    return Utils.parseVersion(Utils.packageInfo.version);
  }

  Future<void> checkForUpdates({bool silent = false}) async {
    try {
      final latest = await _fetchLatest();
      if (latest.versionNum <= _currentVersionNum) {
        if (!silent) {
          SmartDialog.showToast('已是最新版本');
        }
        return;
      }

      final go = await Utils.showAlertDialog(
        '${latest.versionDesc}\n\n当前版本：${Utils.packageInfo.version}\n最新版本：${latest.version}',
        title: '发现新版本 ${latest.version}',
        confirm: '前往下载',
        cancel: '稍后',
      );
      if (go) {
        await launchUrlString(
          latest.downloadUrl,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (!silent) {
        SmartDialog.showToast('检查更新失败');
      }
    }
  }
}
