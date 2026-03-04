import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:avnc_flutter/avnc_flutter.dart';
import 'package:x11_flutter/x11_flutter.dart';
import 'package:xterm/xterm.dart';
import 'globals.dart';
import 'utils.dart';
import 'setup.dart';
import 'terminal.dart';
class Workflow {
  static Future<void> launchX11() async => await X11Flutter.launchX11Page();
  static Future<void> launchAvnc() async => await AvncFlutter.launchUsingUri(Util.getCurrentProp("vncUri"), resizeRemoteDesktop: Util.get("avncResizeDesktop"), resizeRemoteDesktopScaleFactor: pow(4, Util.get("avncScaleFactor")).toDouble());
  static Future<void> launchBrowser() async {
    G.controller.loadRequest(Uri.parse(Util.getCurrentProp("vncUrl")));
    if (G.homePageStateContext.mounted) Navigator.push(G.homePageStateContext, MaterialPageRoute(builder: (c) => WebViewWidget(controller: G.controller)));
  }
  static Future<void> init() async {
    G.dataPath = (await getApplicationSupportDirectory()).path;
    G.termPtys = {};
    G.keyboard = VirtualKeyboard(defaultInputHandler);
    G.prefs = await SharedPreferences.getInstance();
    if (!G.prefs.containsKey("defaultContainer")) {
      await BootSetup.firstTime();
      G.prefs.setBool("getifaddrsBridge", (await DeviceInfoPlugin().androidInfo).version.sdkInt >= 31);
    }
    G.currentContainer = Util.get("defaultContainer") ?? 0;
    G.termFontScale.value = Util.get("termFontScale") ?? 1.0;
    G.controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    WakelockPlus.toggle(enable: Util.get("wakelock") ?? false);
  }
  static Future<void> start() async {
    await Permission.storage.request();
    await init();
    if (!G.termPtys.containsKey(G.currentContainer)) G.termPtys[G.currentContainer] = TermPty();
    Util.termWrite(Util.getCurrentProp("boot"));
    if (Util.get("autoLaunchVnc")) {
      if (Util.get("useX11")) {
        await launchX11();
      } else {
        await launchAvnc();
      }
    }
  }
}