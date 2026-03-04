import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:als/lang/l.dart';
import 'globals.dart';
import 'constants.dart';

class Util {
  static Future<void> cp(String src, String dst) async => await File(dst).writeAsBytes((await rootBundle.load(src)).buffer.asUint8List());
  static void mkdir(String dir) => Directory.fromRawPath(const Utf8Encoder().convert(dir)).createSync(recursive: true);
  static Future<int> exec(String str) async {
    Pty pty = Pty.start("/system/bin/sh");
    pty.write(const Utf8Encoder().convert("$str\nexit \$?\n"));
    return await pty.exitCode;
  }

  static void termWrite(String str) => G.termPtys[G.currentContainer]!.pty.write(const Utf8Encoder().convert("$str\n"));
  static final Map<String, dynamic> _defs = {"defaultContainer": 0, "defaultAudioPort": 4718, "autoLaunchVnc": true, "lastDate": "1970-01-01", "isTerminalWriteEnabled": true, "isTerminalCommandsEnabled": false, "termMaxLines": 4095, "termFontScale": 0.6, "isStickyKey": true, "reinstallBootstrap": false, "getifaddrsBridge": false, "virgl": false, "turnip": false, "dri3": false, "wakelock": false, "isHidpiEnabled": false, "uos": false, "useX11": false, "useAvnc": true, "avncResizeDesktop": true, "avncScaleFactor": -0.5, "defaultFFmpegCommand": "...", "defaultVirglCommand": "...", "defaultVirglOpt": "...", "defaultTurnipOpt": "...", "defaultHidpiOpt": "..."};
  static dynamic get(String k) {
    if (k == "containersInfo") return G.prefs.getStringList(k) ?? [];
    if (!G.prefs.containsKey(k)) {
      final v = _defs[k];
      if (v != null) set(k, v);
      return v;
    }
    var res = G.prefs.get(k);
    return k == "avncScaleFactor" ? (res as double).clamp(-1.0, 1.0) : res;
  }

  static void set(String k, dynamic v) {
    if (v is int)
      G.prefs.setInt(k, v);
    else if (v is bool)
      G.prefs.setBool(k, v);
    else if (v is double)
      G.prefs.setDouble(k, v);
    else if (v is String)
      G.prefs.setString(k, v);
  }

  static dynamic getCurrentProp(String k) {
    final info = get("containersInfo");
    final Map m = jsonDecode(info[G.currentContainer]);
    if (m.containsKey(k)) return m[k];
    final defs = {"name": "Debian", "boot": D.boot, "vnc": "startnovnc", "vncUrl": "...", "vncUri": "...", "commands": D.commands};
    final v = defs[k];
    if (v != null) addProp(k, k == "commands" ? jsonDecode(jsonEncode(v)) : v);
    return v;
  }

  static Future<void> setCurrentProp(String k, dynamic v) async {
    var list = get("containersInfo");
    var m = jsonDecode(list[G.currentContainer])..update(k, (_) => v);
    await G.prefs.setStringList("containersInfo", list..setAll(G.currentContainer, [jsonEncode(m)]));
  }

  static Future<void> addProp(String k, dynamic v) async {
    var list = get("containersInfo");
    var m = jsonDecode(list[G.currentContainer])..addAll({k: v});
    await G.prefs.setStringList("containersInfo", list..setAll(G.currentContainer, [jsonEncode(m)]));
  }

  static String? validateBetween(String? v, int min, int max, Function opr) {
    final l = L.of(G.homePageStateContext)!;
    int? n = int.tryParse(v ?? "");
    if (n == null) return (v == null || v.isEmpty) ? l.enterNumber : l.enterValidNumber;
    if (n < min || n > max) return "请输入$min到$max";
    opr();
    return null;
  }

  static Future<bool> isPortOpen(String h, int p) async {
    try {
      final s = await Socket.connect(h, p, timeout: const Duration(seconds: 1));
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
