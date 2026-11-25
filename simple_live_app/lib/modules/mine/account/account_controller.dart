import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/modules/mine/account/douyu/qr_login_controller.dart';
import 'package:simple_live_app/modules/mine/account/douyu/qr_login_page.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/douyin_account_service.dart';
import 'package:simple_live_app/services/douyu_account_service.dart';
import 'package:simple_live_core/simple_live_core.dart';

class AccountController extends GetxController {
  void bilibiliTap() async {
    if (BiliBiliAccountService.instance.logined.value) {
      var result = await Utils.showAlertDialog("确定要退出哔哩哔哩账号吗？", title: "退出登录");
      if (result) {
        BiliBiliAccountService.instance.logout();
      }
    } else {
      //AppNavigator.toBiliBiliLogin();
      bilibiliLogin();
    }
  }

  void bilibiliLogin() {
    Utils.showBottomSheet(
      title: "登录哔哩哔哩",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Visibility(
            visible: Platform.isAndroid || Platform.isIOS,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text("Web登录"),
              subtitle: const Text("填写用户名密码登录"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                Get.toNamed(RoutePath.kBiliBiliWebLogin);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text("扫码登录"),
            subtitle: const Text("使用哔哩哔哩APP扫描二维码登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.toNamed(RoutePath.kBiliBiliQRLogin);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("Cookie登录"),
            subtitle: const Text("手动输入Cookie登录"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              doBiliBiliCookieLogin();
            },
          ),
        ],
      ),
    );
  }

  void doBiliBiliCookieLogin() async {
    var cookie = await Utils.showEditTextDialog(
      "",
      title: "请输入Cookie",
      hintText: "请输入Cookie",
    );
    if (cookie == null || cookie.isEmpty) {
      return;
    }
    BiliBiliAccountService.instance.setCookie(cookie);
    await BiliBiliAccountService.instance.loadUserInfo();
  }

  void douyuTap() {
    final hasCookie = DouyuAccountService.instance.hasCookie.value;
    Utils.showBottomSheet(
      title: "斗鱼账号",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: const Text("扫码登录"),
            subtitle: const Text(
              "用斗鱼APP扫码确认，自动换取并续期 Cookie，无需定期手动更新",
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              Get.to(
                () => const DouyuQRLoginPage(),
                binding: BindingsBuilder.put(() => DouyuQRLoginController()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text("手动配置 Cookie"),
            subtitle: const Text("粘贴 www.douyu.com 的完整 Cookie"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Get.back();
              _showDouyuCookieDialog();
            },
          ),
          if (hasCookie)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("退出登录"),
              subtitle: const Text("清除 Cookie 与续期凭据，恢复匿名播放"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Get.back();
                DouyuAccountService.instance.clearCookie();
                SmartDialog.showToast("已退出斗鱼账号，将使用匿名播放");
              },
            ),
        ],
      ),
    );
  }

  void _showDouyuCookieDialog() {
    final account = DouyuAccountService.instance;
    final controller = TextEditingController(text: account.cookie);
    Get.dialog(
      AlertDialog(
        title: const Text("配置斗鱼 Cookie"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "匿名用户的斗鱼高画质可能约 10 分钟后断流；粘贴登录后的 www.douyu.com 完整 Cookie 可恢复高画质长期播放。Cookie 只保存在本机；若 Cookie 内含 LTP0/dy_did，过期后也会自动续期。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: "Cookie",
                  hintText: "粘贴 www.douyu.com 的完整 Cookie",
                  alignLabelWithHint: true,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (account.hasCookie.value)
            TextButton(
              onPressed: () {
                account.clearCookie();
                Get.back();
                SmartDialog.showToast("已清除斗鱼 Cookie，将使用匿名播放");
              },
              child: const Text("清除"),
            ),
          TextButton(onPressed: () => Get.back(), child: const Text("取消")),
          TextButton(
            onPressed: () {
              final cookie = _normalizeCookieInput(controller.text);
              account.setCookie(cookie);
              Get.back();
              SmartDialog.showToast(
                cookie.isEmpty ? "已清除斗鱼 Cookie，将使用匿名播放" : "斗鱼 Cookie 已保存",
              );
            },
            child: const Text("保存"),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  String getDouyuCookieSummaryText() {
    final account = DouyuAccountService.instance;
    final hasCookie = account.hasCookie.value;
    final cookie = account.cookie;
    return !hasCookie || cookie.isEmpty
        ? "未配置，匿名高画质可能约 10 分钟断流"
        : "已配置登录 Cookie（${cookie.length} 字符）";
  }

  String _normalizeCookieInput(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return "";
    }
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final item = line.trim();
      if (item.toLowerCase().startsWith("cookie:")) {
        return item.substring(item.indexOf(":") + 1).trim();
      }
    }
    return text;
  }

  void douyinTap() async {
    if (DouyinAccountService.instance.hasCookie.value) {
      var result = await Utils.showAlertDialog("确定要清除自定义 ttwid 吗？", title: "清除配置");
      if (result) {
        DouyinAccountService.instance.clearCookie();
        SmartDialog.showToast("已清除自定义 ttwid，将使用默认 ttwid");
      }
    } else {
      doDouyinCookieConfig();
    }
  }

  void doDouyinCookieConfig() {
    // 初始化文本框时，只显示 ttwid 的值部分
    var savedCookie = DouyinAccountService.instance.cookie;
    var displayText = savedCookie;
    if (savedCookie.startsWith('ttwid=')) {
      displayText = savedCookie.substring(6); // 去掉 "ttwid="
    }
    var controller = TextEditingController(text: displayText);

    Get.dialog(
      AlertDialog(
        title: const Text("配置抖音 ttwid"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "默认已内置有效的 ttwid，可观看所有画质（包括蓝光）。\n如有需要可自定义配置。",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "请粘贴 ttwid 值（留空则使用默认值）",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  // 提取 ttwid 的值部分（去掉 "ttwid=" 前缀）
                  var defaultValue = DouyinSite.kDefaultCookie;
                  if (defaultValue.startsWith('ttwid=')) {
                    defaultValue = defaultValue.substring(6); // 去掉 "ttwid="
                  }
                  controller.text = defaultValue;
                },
                icon: const Icon(Icons.restore),
                label: const Text("恢复默认 ttwid"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              var input = controller.text.trim();
              Get.back();
              if (input.isEmpty) {
                DouyinAccountService.instance.clearCookie();
                SmartDialog.showToast("已清除自定义 Cookie，将使用默认 ttwid");
              } else {
                // 如果用户只输入了 ttwid 值，自动添加 "ttwid=" 前缀
                var cookie = input;
                if (!input.startsWith('ttwid=')) {
                  cookie = 'ttwid=$input';
                }
                DouyinAccountService.instance.setCookie(cookie);
                SmartDialog.showToast("ttwid 已保存");
              }
            },
            child: const Text("确定"),
          ),
        ],
      ),
    );
  }
}
