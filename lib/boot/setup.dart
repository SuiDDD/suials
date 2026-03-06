import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'globals.dart';
import 'utils.dart';
import 'terminal.dart';

class BootSetup {
  static Future<void> bootstrap() async {
    final ProcessResult result = await Process.run('su', ['-c', 'whoami']);
    if (result.stdout.toString().trim() != 'root') {
      return;
    }

    for (var name in ["share", "bin", "lib", "tmp", "proot_tmp", "pulseaudio_tmp"]) {
      Util.mkdir("${G.dataPath}/$name");
    }

    await Util.cp("assets/assets.xz", "${G.dataPath}/assets.xz");
    await Util.cp("assets/patch.xz", "${G.dataPath}/patch.xz");

    Util.termWrite("""
su -c "xz -d ${G.dataPath}/assets.xz && tar xf ${G.dataPath}/assets.tar -C ${G.dataPath}"
su -c "xz -d ${G.dataPath}/patch.xz && tar xf ${G.dataPath}/patch.tar -C ${G.dataPath}"
""");
    await Future.delayed(const Duration(seconds: 3));
  }

  static Future<void> firstTime() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xz']);
    if (result == null || result.files.isEmpty || result.files.single.path == null) throw "CANCELLED";

    if (!G.termPtys.containsKey(0)) G.termPtys[0] = TermPty();
    await bootstrap();

    final String xzPath = "${G.dataPath}/container_setup.tar.xz";
    final String directory = "${G.dataPath}/containers/0";
    Util.mkdir("$directory/.l2s");

    final String sourcePath = result.files.single.path!;
    await File(sourcePath).copy(xzPath);

    try {
      Util.termWrite("su -c 'xz -d -c $xzPath | tar xf - -C $directory --no-same-permissions'");
      await Future.delayed(const Duration(seconds: 5));
      if (await File(xzPath).exists()) await File(xzPath).delete();
    } catch (e) {}

    await G.prefs.setStringList("containersInfo", ["{}"]);
    await G.prefs.setInt("defaultContainer", 0);
  }
}
