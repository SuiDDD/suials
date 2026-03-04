import 'package:flutter/material.dart';
import 'globals.dart';
import 'utils.dart';
import 'ffi.dart';
import 'terminal.dart';

class BootSetup {
  static Future<void> bootstrap() async {
    for (var d in ["share", "bin", "lib", "tmp", "proot_tmp", "pulseaudio_tmp"]) Util.mkdir("${G.dataPath}/$d");
    await Util.cp("assets/assets.xz", "${G.dataPath}/assets.xz");
    await Util.cp("assets/patch.xz", "${G.dataPath}/patch.xz");
    await Util.exec("""export DATA_DIR=${G.dataPath} && export LD_LIBRARY_PATH=\$DATA_DIR/lib && cd \$DATA_DIR && ln -sf ../applib/libexec_busybox.so bin/busybox && ln -sf ../applib/libexec_busybox.so bin/sh && ln -sf ../applib/libexec_busybox.so bin/cat && ln -sf ../applib/libexec_busybox.so bin/xz && ln -sf ../applib/libexec_busybox.so bin/gzip && ln -sf ../applib/libexec_proot.so bin/proot && ln -sf ../applib/libexec_tar.so bin/tar && ln -sf ../applib/libexec_virgl_test_server.so bin/virgl_test_server && ln -sf ../applib/libexec_getifaddrs_bridge_server.so bin/getifaddrs_bridge_server && ln -sf ../applib/libexec_pulseaudio.so bin/pulseaudio && ln -sf ../applib/libbusybox.so lib/libbusybox.so.1.37.0 && ln -sf ../applib/libtalloc.so lib/libtalloc.so.2 && ln -sf ../applib/libvirglrenderer.so lib/libvirglrenderer.so && ln -sf ../applib/libepoxy.so lib/libepoxy.so && ln -sf ../applib/libproot-loader32.so lib/loader32 && ln -sf ../applib/libproot-loader.so lib/loader && bin/tar xfJ assets.tar.xz && chmod -R +x bin/* && chmod 1777 tmp && bin/tar xfJ patch.tar.xz && rm assets.tar.xz patch.tar.xz""");
  }

  static Future<void> firstTime() async {
    final isZh = G.homePageStateContext.mounted && Localizations.localeOf(G.homePageStateContext).languageCode == 'zh';
    if (!G.termPtys.containsKey(0)) G.termPtys[0] = TermPty();
    await bootstrap();
    final xz = "${G.dataPath}/d13_xfce.tar.xz", dir = "${G.dataPath}/containers/0";
    Util.mkdir("$dir/.l2s");
    await Util.cp("assets/d13_xfce.tar.xz", xz);
    if (RustTar.unpack(xz, dir) != null) throw "FAIL";
    Util.termWrite(isZh ? "setup..." : "setup en...");
    await G.prefs.setStringList("containersInfo", ["{}"]);
    await G.prefs.setInt("defaultContainer", 0);
  }
}
