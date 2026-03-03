import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'boot.dart';
import 'lang/l.dart';
import 'set.dart';

class SettingsSystemPage extends StatefulWidget {
  const SettingsSystemPage({super.key});
  @override
  State<SettingsSystemPage> createState() => _SettingsSystemPageState();
}

class _SettingsSystemPageState extends State<SettingsSystemPage> {
  late L _l;
  Widget _f(String l, String k, {bool m = false, Widget? s, bool g = false, int? n, int? x}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: TextFormField(
      maxLines: m ? 5 : 1,
      initialValue: (g ? Util.getGlobal(k) : Util.getCurrentProp(k)).toString(),
      keyboardType: n != null ? TextInputType.number : null,
      decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), labelText: l, suffixIcon: s, filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)),
      onChanged: n != null ? null : (v) => g ? G.prefs.setString(k, v) : Util.setCurrentProp(k, v),
      validator: n != null ? (v) => Util.validateBetween(v, n, x!, () => G.prefs.setInt(k, int.parse(v!))) : null,
      autovalidateMode: n != null ? AutovalidateMode.onUserInteraction : null,
    ),
  );
  Widget _s(String t, String k, {String? st}) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(t, style: const TextStyle(fontSize: 14)),
    subtitle: st != null ? Text(st, style: const TextStyle(fontSize: 12)) : null,
    value: Util.getGlobal(k) as bool,
    onChanged: (v) => setState(() => G.prefs.setBool(k, v)),
  );
  void _reset() async {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final cmd = isZh ? D.boot : D.boot.replaceFirst('LANG=zh_CN.UTF-8', 'LANG=en_US.UTF-8').replaceAllMapped(RegExp(r'(公共|图片|音乐|视频|下载|文档|照片)'), (m) => {'公共': 'Public', '图片': 'Pictures', '音乐': 'Music', '视频': 'Videos', '下载': 'Downloads', '文档': 'Documents', '照片': 'Photos'}[m.group(0)!]!);
    await Util.setCurrentProp("boot", cmd);
    G.bootTextChange.value = !G.bootTextChange.value;
  }

  @override
  Widget build(BuildContext context) {
    _l = L.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_l.system), centerTitle: false),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _f(_l.containerName, "name"),
            ValueListenableBuilder(valueListenable: G.bootTextChange, builder: (_, __, ___) => _f(_l.startupCommand, "boot", m: true)),
            _f(_l.vncStartupCommand, "vnc", m: true),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(icon: const Icon(Symbols.refresh_rounded, size: 18), label: Text(_l.resetStartupCommand), onPressed: _reset),
            ),
            const Divider(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(_l.restartRequiredHint, style: SettingPage.ktext),
            ),
            _s(_l.getifaddrsBridge, "getifaddrsBridge", st: _l.fixGetifaddrsPermission),
            _s(_l.fakeUOSSystem, "uos"),
          ],
        ),
      ),
    );
  }
}
