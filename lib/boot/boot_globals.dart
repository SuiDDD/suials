import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'terminal.dart';
class G {
  static late final String dataPath;
  static Pty? audioPty;
  static late WebViewController controller;
  static late BuildContext homePageStateContext;
  static int currentContainer = 0;
  static Map<int, TermPty> termPtys = {};
  static late VirtualKeyboard keyboard;
  static bool maybeCtrlJ = false;
  static ValueNotifier<double> termFontScale = ValueNotifier(1);
  static bool isStreamServerStarted = false, isStreaming = false;
  static String streamingOutput = "";
  static late Pty streamServerPty;
  static int? virglPid;
  static ValueNotifier<int> pageIndex = ValueNotifier(1);
  static ValueNotifier<bool> terminalPageChange = ValueNotifier(true), bootTextChange = ValueNotifier(true);
  static String postCommand = "";
  static bool wasAvncEnabled = false, wasX11Enabled = false;
  static late SharedPreferences prefs;
}