import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'lang/l.dart';
import 'package:avnc_flutter/avnc_flutter.dart';
import 'package:x11_flutter/x11_flutter.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});
  @override
  Widget build(BuildContext context) => Container(color: Colors.black);
}

class Util {
  static Future<void> copyAsset(String src, String dst) async => await File(dst).writeAsBytes((await rootBundle.load(src)).buffer.asUint8List());
  static Future<void> copyAsset2(String src, String dst) async {
    ByteData data = await rootBundle.load(src);
    await File(dst).writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  static void createDirFromString(String dir) => Directory.fromRawPath(const Utf8Encoder().convert(dir)).createSync(recursive: true);
  static Future<int> execute(String str) async {
    Pty pty = Pty.start("/system/bin/sh");
    pty.write(const Utf8Encoder().convert("$str\nexit \$?\n"));
    return await pty.exitCode;
  }

  static void termWrite(String str) => G.termPtys[G.currentContainer]!.pty.write(const Utf8Encoder().convert("$str\n"));
  static void runAndGoHome(BuildContext c, String cmd) {
    termWrite(cmd.endsWith('&') ? cmd : "$cmd &");
    if (Navigator.canPop(c)) Navigator.pop(c);
    G.pageIndex.value = 0;
  }

  static final Map<String, dynamic> _defaults = {"defaultContainer": 0, "defaultAudioPort": 4718, "autoLaunchVnc": true, "lastDate": "1970-01-01", "isTerminalWriteEnabled": true, "isTerminalCommandsEnabled": false, "termMaxLines": 4095, "termFontScale": 0.6, "isStickyKey": true, "reinstallBootstrap": false, "getifaddrsBridge": false, "virgl": false, "turnip": false, "dri3": false, "wakelock": false, "isHidpiEnabled": false, "uos": false, "useX11": false, "useAvnc": true, "avncResizeDesktop": true, "avncScaleFactor": -0.5, "defaultFFmpegCommand": "-hide_banner -an -max_delay 1000000 -r 30 -f android_camera -camera_index 0 -i 0:0 -vf scale=iw/2:-1 -rtsp_transport udp -f rtsp rtsp://127.0.0.1:8554/stream", "defaultVirglCommand": "--use-egl-surfaceless --use-gles --socket-path=\$CONTAINER_DIR/tmp/.virgl_test", "defaultVirglOpt": "GALLIUM_DRIVER=virpipe", "defaultTurnipOpt": "MESA_LOADER_DRIVER_OVERRIDE=zink VK_ICD_FILENAMES=/home/tiny/.local/share/tiny/extra/freedreno_icd.aarch64.json TU_DEBUG=noconform", "defaultHidpiOpt": "GDK_SCALE=2 QT_FONT_DPI=192"};

  static dynamic getGlobal(String key) {
    final p = G.prefs;
    if (key == "containersInfo") return p.getStringList(key) ?? [];
    if (!p.containsKey(key)) {
      final val = _defaults[key];
      if (val == null) return null;
      _setPref(key, val);
      return val;
    }
    var res = p.get(key);
    return key == "avncScaleFactor" ? (res as double).clamp(-1.0, 1.0) : res;
  }

  static void _setPref(String k, dynamic v) {
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
    final info = getGlobal("containersInfo");
    final Map m = jsonDecode(info[G.currentContainer]);
    if (m.containsKey(k)) return m[k];

    final Map<String, dynamic> propDefaults = {"name": "Debian", "boot": D.boot, "vnc": "startnovnc", "vncUrl": "http://localhost:99999/vnc.html?host=localhost&port=99999&autoconnect=true&resize=remote&password=12345678", "vncUri": "vnc://127.0.0.1:9999?VncPassword=12345678&SecurityType=2", "commands": D.commands};

    final v = propDefaults[k];
    if (v != null) addCurrentProp(k, k == "commands" ? jsonDecode(jsonEncode(v)) : v);
    return v;
  }

  static Future<void> setCurrentProp(String k, dynamic v) async {
    var list = getGlobal("containersInfo");
    var m = jsonDecode(list[G.currentContainer])..update(k, (_) => v);
    await G.prefs.setStringList("containersInfo", list..setAll(G.currentContainer, [jsonEncode(m)]));
  }

  static Future<void> addCurrentProp(String k, dynamic v) async {
    var list = getGlobal("containersInfo");
    var m = jsonDecode(list[G.currentContainer])..addAll({k: v});
    await G.prefs.setStringList("containersInfo", list..setAll(G.currentContainer, [jsonEncode(m)]));
  }

  static String? validateBetween(String? v, int min, int max, Function opr) {
    final l = L.of(G.homePageStateContext)!;
    int? n = int.tryParse(v ?? "");
    if (n == null) return (v == null || v.isEmpty) ? l.enterNumber : l.enterValidNumber;
    if (n < min || n > max) return "请输入$min到$max之间的数字";
    opr();
    return null;
  }

  static Future<bool> isXServerReady(String h, int p, {int t = 5}) async {
    try {
      final s = await Socket.connect(h, p, timeout: Duration(seconds: t));
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> waitForXServer() async {
    while (true) {
      if (await isXServerReady('127.0.0.1', 7897)) return;
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  static String getl10nText(String k, BuildContext c) {
    final l = L.of(c)!;
    final Map<String, String> m = {'projectUrl': l.projectUrl, 'issueUrl': l.issueUrl, 'faqUrl': l.faqUrl, 'solutionUrl': l.solutionUrl, 'discussionUrl': l.discussionUrl};
    return m[k] ?? l.projectUrl;
  }
}

class VirtualKeyboard extends TerminalInputHandler with ChangeNotifier {
  final TerminalInputHandler _h;
  VirtualKeyboard(this._h);
  bool ctrl = false, shift = false, alt = false;
  @override
  String? call(TerminalKeyboardEvent e) {
    final r = _h.call(e.copyWith(ctrl: e.ctrl || ctrl, shift: e.shift || shift, alt: e.alt || alt));
    G.maybeCtrlJ = e.key.name == "keyJ";
    if (!(Util.getGlobal("isStickyKey"))) {
      ctrl = shift = alt = false;
      notifyListeners();
    }
    return r;
  }
}

class TermPty {
  late final Terminal terminal;
  late final Pty pty;
  TermPty() {
    terminal = Terminal(inputHandler: G.keyboard, maxLines: Util.getGlobal("termMaxLines"));
    pty = Pty.start("/system/bin/sh", workingDirectory: G.dataPath, columns: terminal.viewWidth, rows: terminal.viewHeight);
    pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen(terminal.write);
    pty.exitCode.then((c) {
      terminal.write('the process exited with exit code $c');
      if (c == 0) SystemChannels.platform.invokeMethod("SystemNavigator.pop");
      if (c == -9) D.androidChannel.invokeMethod("launchSignal9Page");
    });
    terminal.onOutput = (d) {
      if (!(Util.getGlobal("isTerminalWriteEnabled"))) return;
      for (var char in d.split("")) {
        if (char == "\n" && !G.maybeCtrlJ) {
          terminal.keyInput(TerminalKey.enter);
          continue;
        }
        G.maybeCtrlJ = false;
        pty.write(const Utf8Encoder().convert(char));
      }
    };
    terminal.onResize = (w, h, pw, ph) => pty.resize(h, w);
  }
}

class D {
  static const baseCommands = ["sudo dpkg --configure -a && sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y", "neofetch -L && neofetch --off", "stopvnc\nexit\nexit"];
  static List<Map<String, String>> getCommands() {
    return List.generate(baseCommands.length, (i) => {"name": "", "command": baseCommands[i]});
  }

  static List<Map<String, String>> get commands => getCommands();
  static const baseWineCommands = ["winecfg", "regedit Z:\\\\home\\\\tiny\\\\.local\\\\share\\\\tiny\\\\extra\\\\chn_fonts.reg && wine reg delete \"HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes\" /va /f", "wine explorer \"C:\\\\ProgramData\\\\Microsoft\\\\Windows\\\\Start Menu\\\\Programs\"", """WINEDLLOVERRIDES="d3d8=n,d3d9=n,d3d10core=n,d3d11=n,dxgi=n" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v d3d8 /d native /f >/dev/null 2>&1WINEDLLOVERRIDES="d3d8=n,d3d9=n,d3d10core=n,d3d11=n,dxgi=n" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v d3d9 /d native /f >/dev/null 2>&1WINEDLLOVERRIDES="d3d8=n,d3d9=n,d3d10core=n,d3d11=n,dxgi=n" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v d3d10core /d native /f >/dev/null 2>&1WINEDLLOVERRIDES="d3d8=n,d3d9=n,d3d10core=n,d3d11=n,dxgi=n" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v d3d11 /d native /f >/dev/null 2>&1WINEDLLOVERRIDES="d3d8=n,d3d9=n,d3d10core=n,d3d11=n,dxgi=n" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v dxgi /d native /f >/dev/null 2>&1""", """WINEDLLOVERRIDES="d3d8=b,d3d9=b,d3d10core=b,d3d11=b,dxgi=b" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v d3d8 /d builtin /f >/dev/null 2>&1WINEDLLOVERRIDES="d3d8=b,d3d9=b,d3d10core=b,d3d11=b,dxgi=b" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v d3d9 /d builtin /f >/dev/null 2>&1WINEDLLOVERRIDES="d3d8=b,d3d9=b,d3d10core=b,d3d11=b,dxgi=b" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v d3d10core /d builtin /f >/dev/null 2>&1WINEDLLOVERRIDES="d3d8=b,d3d9=b,d3d10core=b,d3d11=b,dxgi=b" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v d3d11 /d builtin /f >/dev/null 2>&1WINEDLLOVERRIDES="d3d8=b,d3d9=b,d3d10core=b,d3d11=b,dxgi=b" wine reg add 'HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides' /v dxgi /d builtin /f >/dev/null 2>&1""", "wine explorer", "notepad", "winemine", "regedit", "wine control", "winefile", "wine taskmgr", "wine iexplore", "wineserver -k"];
  static const wineCommandNamesZh = ["Wine配置", "修复方块字", "开始菜单文件夹", "开启DXVK", "关闭DXVK", "我的电脑", "记事本", "扫雷", "注册表", "控制面板", "文件管理器", "任务管理器", "IE浏览器", "强制关闭Wine"];
  static const wineCommandNamesEn = ["Wine Configuration", "Fix CJK Characters", "Start Menu Dir", "Enable DXVK", "Disable DXVK", "Explorer", "Notepad", "Minesweeper", "Regedit", "Control Panel", "File Manager", "Task Manager", "Internet Explorer", "Kill Wine Process"];
  static List<Map<String, String>> getWineCommands(bool en) {
    final n = en ? wineCommandNamesEn : wineCommandNamesZh;
    return List.generate(min(baseWineCommands.length, n.length), (i) => {"name": n[i], "command": baseWineCommands[i]});
  }

  static List<Map<String, String>> get wineCommands => getWineCommands(false);
  static List<Map<String, String>> get wineCommands4En => getWineCommands(true);
  static const termCommands = [
    {"name": "Esc", "key": TerminalKey.escape},
    {"name": "Tab", "key": TerminalKey.tab},
    {"name": "↑", "key": TerminalKey.arrowUp},
    {"name": "↓", "key": TerminalKey.arrowDown},
    {"name": "←", "key": TerminalKey.arrowLeft},
    {"name": "→", "key": TerminalKey.arrowRight},
    {"name": "Del", "key": TerminalKey.delete},
    {"name": "PgUp", "key": TerminalKey.pageUp},
    {"name": "PgDn", "key": TerminalKey.pageDown},
    {"name": "Home", "key": TerminalKey.home},
    {"name": "End", "key": TerminalKey.end},
    {"name": "F1", "key": TerminalKey.f1},
    {"name": "F2", "key": TerminalKey.f2},
    {"name": "F3", "key": TerminalKey.f3},
    {"name": "F4", "key": TerminalKey.f4},
    {"name": "F5", "key": TerminalKey.f5},
    {"name": "F6", "key": TerminalKey.f6},
    {"name": "F7", "key": TerminalKey.f7},
    {"name": "F8", "key": TerminalKey.f8},
    {"name": "F9", "key": TerminalKey.f9},
    {"name": "F10", "key": TerminalKey.f10},
    {"name": "F11", "key": TerminalKey.f11},
    {"name": "F12", "key": TerminalKey.f12},
  ];
  static const String boot = r"""$DATA_DIR/bin/proot -H -0 --change-id=1000:1000 --kernel-release=6.1.0 --pwd=/home/tiny --rootfs=$CONTAINER_DIR --kill-on-exit --sysvipc -L --link2symlink -p -b --mount=/system --mount=/apex --mount=/sys --mount=/data --mount=/storage --mount=/proc --mount=/dev --mount=$CONTAINER_DIR/tmp:/dev/shm --mount=/dev/urandom:/dev/random --mount=/proc/self/fd:/dev/fd --mount=/proc/self/fd/0:/dev/stdin --mount=/proc/self/fd/1:/dev/stdout --mount=/proc/self/fd/2:/dev/stderr --mount=/dev/null:/dev/tty0 --mount=/dev/null:/proc/sys/kernel/cap_last_cap --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/.tmoe-container.stat:/proc/stat --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/.tmoe-container.version:/proc/version --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/bus:/proc/bus --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/buddyinfo:/proc/buddyinfo --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/cgroups:/proc/cgroups --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/consoles:/proc/consoles --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/crypto:/proc/crypto --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/devices:/proc/devices --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/diskstats:/proc/diskstats --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/execdomains:/proc/execdomains --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/fb:/proc/fb --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/filesystems:/proc/filesystems --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/interrupts:/proc/interrupts --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/iomem:/proc/iomem --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/ioports:/proc/ioports --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/kallsyms:/proc/kallsyms --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/keys:/proc/keys --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/key-users:/proc/key-users --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/kpageflags:/proc/kpageflags --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/loadavg:/proc/loadavg --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/locks:/proc/locks --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/misc:/proc/misc --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/modules:/proc/modules --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/pagetypeinfo:/proc/pagetypeinfo --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/partitions:/proc/partitions --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/sched_debug:/proc/sched_debug --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/softirqs:/proc/softirqs --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/timer_list:/proc/timer_list --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/uptime:/proc/uptime --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/vmallocinfo:/proc/vmallocinfo --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/vmstat:/proc/vmstat --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/zoneinfo:/proc/zoneinfo --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/meminfo:/proc/meminfo --mount=$CONTAINER_DIR/usr/local/etc/tmoe-linux/proot_proc/stat:/proc/stat $EXTRA_MOUNT /usr/bin/env -i HOSTNAME=TINY HOME=/home/tiny USER=tiny TERM=xterm-256color SDL_IM_MODULE=fcitx XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx GTK_IM_MODULE=fcitx TMOE_CHROOT=false TMOE_PROOT=true TMPDIR=/tmp MOZ_FAKE_NO_SANDBOX=1 QTWEBENGINE_DISABLE_SANDBOX=1 DISPLAY=:4 PULSE_SERVER=tcp:127.0.0.1:4718 LANG=zh_CN.UTF-8 SHELL=/bin/bash PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games $EXTRA_OPT /bin/bash -l""";
  static final commandButtonStyle = OutlinedButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap, minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2));
  static final controlButtonStyle = OutlinedButton.styleFrom(
    textStyle: const TextStyle(fontWeight: FontWeight.w400),
    side: const BorderSide(color: Color(0x1F000000)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    minimumSize: Size.zero,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );
  static const androidChannel = MethodChannel("android");
}

class G {
  static late final String dataPath;
  static Pty? audioPty;
  static late WebViewController controller;
  static late BuildContext homePageStateContext;
  static late int currentContainer;
  static late Map<int, TermPty> termPtys;
  static late VirtualKeyboard keyboard;
  static bool maybeCtrlJ = false;
  static ValueNotifier<double> termFontScale = ValueNotifier(1);
  static bool isStreamServerStarted = false, isStreaming = false;
  static String streamingOutput = "";
  static late Pty streamServerPty;
  static int? virglPid;
  static ValueNotifier<int> pageIndex = ValueNotifier(1);
  static ValueNotifier<bool> terminalPageChange = ValueNotifier(true), bootTextChange = ValueNotifier(true);
  static ValueNotifier<String> updateText = ValueNotifier("小小电脑");
  static String postCommand = "";
  static bool wasAvncEnabled = false, wasX11Enabled = false;
  static late SharedPreferences prefs;
}

class Workflow {
  static bool _isHomePageStateContextInitialized() {
    try {
      final _ = G.homePageStateContext;
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> grantPermissions() async => await Permission.storage.request();
  static Future<void> setupBootstrap() async {
    for (var d in ["share", "bin", "lib", "tmp", "proot_tmp", "pulseaudio_tmp"]) {
      Util.createDirFromString("${G.dataPath}/$d");
    }
    await Util.copyAsset("assets/assets.xz", "${G.dataPath}/assets.xz");
    await Util.copyAsset("assets/patch.xz", "${G.dataPath}/patch.xz");
    await Util.execute("""export DATA_DIR=${G.dataPath} && export LD_LIBRARY_PATH=\$DATA_DIR/lib && cd \$DATA_DIR && ln -sf ../applib/libexec_busybox.so bin/busybox && ln -sf ../applib/libexec_busybox.so bin/sh && ln -sf ../applib/libexec_busybox.so bin/cat && ln -sf ../applib/libexec_busybox.so bin/xz && ln -sf ../applib/libexec_busybox.so bin/gzip && ln -sf ../applib/libexec_proot.so bin/proot && ln -sf ../applib/libexec_tar.so bin/tar && ln -sf ../applib/libexec_virgl_test_server.so bin/virgl_test_server && ln -sf ../applib/libexec_getifaddrs_bridge_server.so bin/getifaddrs_bridge_server && ln -sf ../applib/libexec_pulseaudio.so bin/pulseaudio && ln -sf ../applib/libbusybox.so lib/libbusybox.so.1.37.0 && ln -sf ../applib/libtalloc.so lib/libtalloc.so.2 && ln -sf ../applib/libvirglrenderer.so lib/libvirglrenderer.so && ln -sf ../applib/libepoxy.so lib/libepoxy.so && ln -sf ../applib/libproot-loader32.so lib/loader32 && ln -sf ../applib/libproot-loader.so lib/loader && bin/tar xfJ assets.xz && chmod -R +x bin/* && chmod 1777 tmp && bin/tar xfJ patch.xz && rm assets.xz patch.xz""");
  }

  static Future<void> initForFirstTime() async {
    final isZh = _isHomePageStateContextInitialized() && G.homePageStateContext.mounted && Localizations.localeOf(G.homePageStateContext).languageCode == 'zh';
    G.currentContainer = 0;
    if (!G.termPtys.containsKey(0)) G.termPtys[0] = TermPty();
    await setupBootstrap();
    Util.createDirFromString("${G.dataPath}/containers/0/.l2s");
    await Util.copyAsset("assets/d13_xfce.tar.xz", "${G.dataPath}/d13_xfce.tar.xz");
    Util.termWrite("""cd ${G.dataPath} && export DATA_DIR=${G.dataPath} && export PATH=\$DATA_DIR/bin:\$PATH && export LD_LIBRARY_PATH=\$DATA_DIR/lib && export CONTAINER_DIR=\$DATA_DIR/containers/0 && export PROOT_TMP_DIR=\$DATA_DIR/proot_tmp && export PROOT_LOADER=\$DATA_DIR/applib/libproot-loader.so && export PROOT_LOADER_32=\$DATA_DIR/applib/libproot-loader32.so && bin/proot --link2symlink sh -c "bin/tar xvfJ d13_xfce.tar.xz --delay-directory-restore --preserve-permissions -C containers/0" && chmod u+rw "\$CONTAINER_DIR/etc/passwd" "\$CONTAINER_DIR/etc/shadow" "\$CONTAINER_DIR/etc/group" "\$CONTAINER_DIR/etc/gshadow" && echo "aid_\$(id -un):x:\$(id -u):\$(id -g):Termux:/:/sbin/nologin" >> "\$CONTAINER_DIR/etc/passwd" && echo "aid_\$(id -un):*:18446:0:99999:7:::" >> "\$CONTAINER_DIR/etc/shadow" && id -Gn | tr ' ' '\\n' > tmp1 && id -G | tr ' ' '\\n' > tmp2 && bin/busybox paste tmp1 tmp2 > tmp3 && cat tmp3 | while read -r n i; do echo "aid_\$n:x:\$i:root,aid_\$(id -un)" >> "\$CONTAINER_DIR/etc/group"; [ -f "\$CONTAINER_DIR/etc/gshadow" ] && echo "aid_\$n:*::root,aid_\$(id -un)" >> "\$CONTAINER_DIR/etc/gshadow"; done && bin/busybox rm -rf d13_xfce.tar.xz tmp1 tmp2 tmp3 && ${isZh ? "" : "echo 'LANG=en_US.UTF-8' > \$CONTAINER_DIR/usr/local/etc/tmoe-linux/locale.txt"}""");
    await G.prefs.setStringList("containersInfo", ["""{"name":"Debian","boot":"${isZh ? D.boot : D.boot.replaceFirst('LANG=zh_CN.UTF-8', 'LANG=en_US.UTF-8').replaceFirst('公共', 'Public').replaceFirst('图片', 'Pictures').replaceFirst('音乐', 'Music').replaceFirst('视频', 'Videos').replaceFirst('下载', 'Downloads').replaceFirst('文档', 'Documents').replaceFirst('照片', 'Photos')}","vnc":"startnovnc","vncUrl":"http://localhost:99999/vnc.html?host=localhost&port=99999&autoconnect=true&resize=remote&password=12345678","commands":${jsonEncode(D.commands)}}"""]);
    await G.prefs.setInt("defaultContainer", 0);
    Util.termWrite(D.boot);
  }

  static Future<void> initData() async {
    final isZh = _isHomePageStateContextInitialized() && G.homePageStateContext.mounted && Localizations.localeOf(G.homePageStateContext).languageCode == 'zh';
    G.dataPath = (await getApplicationSupportDirectory()).path;
    G.termPtys = {};
    G.keyboard = VirtualKeyboard(defaultInputHandler);
    G.prefs = await SharedPreferences.getInstance();
    await Util.execute("ln -sf ${await D.androidChannel.invokeMethod("getNativeLibraryPath")} ${G.dataPath}/applib");
    if (!G.prefs.containsKey("defaultContainer")) {
      await initForFirstTime();
      final s = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
      final w = (max(s.width, s.height) * 0.75).round(), h = (min(s.width, s.height) * 0.75).round();
      G.postCommand = """sed -i -E "s@(geometry)=.*@\\1=${w}x$h@" /etc/tigervnc/vncserver-config-tmoesed -i -E "s@^(VNC_RESOLUTION)=.*@\\1=${w}x$h@" \$(command -v startvnc)""";
      if (!isZh) {
        G.postCommand += "\nlocaledef -c -i en_US -f UTF-8 en_US.UTF-8";
        await G.prefs.setBool("isTerminalWriteEnabled", true);
        await G.prefs.setBool("isTerminalCommandsEnabled", true);
        await G.prefs.setBool("isStickyKey", false);
        await G.prefs.setBool("wakelock", true);
      }
      await G.prefs.setBool("getifaddrsBridge", (await DeviceInfoPlugin().androidInfo).version.sdkInt >= 31);
    }
    G.currentContainer = Util.getGlobal("defaultContainer");
    if (Util.getGlobal("reinstallBootstrap")) {
      G.updateText.value = _isHomePageStateContextInitialized() && G.homePageStateContext.mounted ? L.of(G.homePageStateContext)!.reinstallingBootPackage : "Reinstalling boot package";
      await setupBootstrap();
      G.prefs.setBool("reinstallBootstrap", false);
    }
    if (Util.getGlobal("useX11")) {
      G.wasX11Enabled = true;
      launchXServer();
    } else if (Util.getGlobal("useAvnc")) {
      G.wasAvncEnabled = true;
    }
    G.termFontScale.value = Util.getGlobal("termFontScale");
    G.controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    WakelockPlus.toggle(enable: Util.getGlobal("wakelock"));
  }

  static Future<void> initTerminalForCurrent() async {
    if (!G.termPtys.containsKey(G.currentContainer)) G.termPtys[G.currentContainer] = TermPty();
  }

  static Future<void> setupAudio() async {
    G.audioPty?.kill();
    G.audioPty = Pty.start("/system/bin/sh");
    G.audioPty!.write(const Utf8Encoder().convert("""export DATA_DIR=${G.dataPath} && export PATH=\$DATA_DIR/bin:\$PATH && export LD_LIBRARY_PATH=\$DATA_DIR/lib && bin/busybox sed "s/4713/${Util.getGlobal("defaultAudioPort")}/g" bin/pulseaudio.conf > bin/pulseaudio.conf.tmp && rm -rf pulseaudio_tmp/* && TMPDIR=pulseaudio_tmp HOME=pulseaudio_tmp XDG_CONFIG_HOME=pulseaudio_tmp pulseaudio -F bin/pulseaudio.conf.tmpexit"""));
    await G.audioPty?.exitCode;
  }

  static Future<void> launchCurrentContainer() async {
    String eM = "", eO = "";
    if (Util.getGlobal("getifaddrsBridge")) {
      Util.execute("${G.dataPath}/bin/getifaddrs_bridge_server ${G.dataPath}/containers/${G.currentContainer}/tmp/.getifaddrs-bridge");
      eO += "LD_PRELOAD=/home/tiny/.local/share/tiny/extra/getifaddrs_bridge_client_lib.so ";
    }
    if (Util.getGlobal("isHidpiEnabled")) eO += "${Util.getGlobal("defaultHidpiOpt")} ";
    if (Util.getGlobal("virgl")) {
      Util.execute("export DATA_DIR=${G.dataPath} && export PATH=\$DATA_DIR/bin:\$PATH && export LD_LIBRARY_PATH=\$DATA_DIR/lib && bin/virgl_test_server ${Util.getGlobal("defaultVirglCommand")}");
      eO += "${Util.getGlobal("defaultVirglOpt")} ";
    }
    if (Util.getGlobal("turnip")) {
      eO += "${Util.getGlobal("defaultTurnipOpt")} ";
      if (!(Util.getGlobal("dri3"))) eO += "MESA_VK_WSI_DEBUG=sw ";
    }
    eM += "--mount=\$DATA_DIR/tiny/font:/usr/share/fonts/tiny --mount=\$DATA_DIR/tiny/extra/cmatrix:/home/tiny/.local/bin/cmatrix ";
    Util.termWrite("""export DATA_DIR=${G.dataPath} && export PATH=\$DATA_DIR/bin:\$PATH && export LD_LIBRARY_PATH=\$DATA_DIR/lib && export CONTAINER_DIR=\$DATA_DIR/containers/${G.currentContainer} && export EXTRA_MOUNT="$eM" && export EXTRA_OPT="$eO" && cd \$DATA_DIR && export PROOT_TMP_DIR=\$DATA_DIR/proot_tmp && export PROOT_LOADER=\$DATA_DIR/applib/libproot-loader.so && export PROOT_LOADER_32=\$DATA_DIR/applib/libproot-loader32.so && ${Util.getCurrentProp("boot")}${G.postCommand}\n""");
  }

  static Future<void> launchGUIBackend() async {
    Util.termWrite((Util.getGlobal("autoLaunchVnc")) ? ((Util.getGlobal("useX11")) ? """mkdir -p "\$HOME/.vnc" && bash /etc/X11/xinit/Xsession &> "\$HOME/.vnc/x.log" &""" : Util.getCurrentProp("vnc")) : "");
    Util.termWrite("");
  }

  static Future<void> waitForConnection() async => await retry(() => http.get(Uri.parse(Util.getCurrentProp("vncUrl"))).timeout(const Duration(milliseconds: 250)), retryIf: (e) => e is SocketException || e is TimeoutException);
  static Future<void> launchBrowser() async {
    G.controller.loadRequest(Uri.parse(Util.getCurrentProp("vncUrl")));
    if (_isHomePageStateContextInitialized() && G.homePageStateContext.mounted) {
      Navigator.push(
        G.homePageStateContext,
        MaterialPageRoute(
          builder: (c) => Focus(
            onKeyEvent: (n, e) => (!kIsWeb && {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.tab}.contains(e.logicalKey)) ? KeyEventResult.skipRemainingHandlers : KeyEventResult.ignored,
            child: WebViewWidget(controller: G.controller),
          ),
        ),
      );
    }
  }

  static Future<void> launchAvnc() async => await AvncFlutter.launchUsingUri(Util.getCurrentProp("vncUri"), resizeRemoteDesktop: Util.getGlobal("avncResizeDesktop"), resizeRemoteDesktopScaleFactor: pow(4, Util.getGlobal("avncScaleFactor")).toDouble());
  static Future<void> launchXServer() async => await X11Flutter.launchXServer("${G.dataPath}/containers/${G.currentContainer}/tmp", "${G.dataPath}/containers/${G.currentContainer}/usr/share/X11/xkb", [":4"]);
  static Future<void> launchX11() async => await X11Flutter.launchX11Page();
  static Future<void> workflow() async {
    grantPermissions();
    await initData();
    await initTerminalForCurrent();
    setupAudio();
    await launchCurrentContainer();
    if (Util.getGlobal("autoLaunchVnc")) {
      if (G.wasX11Enabled) {
        await Util.waitForXServer();
        launchGUIBackend();
        launchX11();
        return;
      }
      launchGUIBackend();
      waitForConnection().then((_) => G.wasAvncEnabled ? launchAvnc() : launchBrowser());
    }
  }
}
