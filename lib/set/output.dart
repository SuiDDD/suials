import 'package:als/boot/globals.dart';
import 'package:als/boot/utils.dart';
import 'package:flutter/material.dart';
import 'package:avnc_flutter/avnc_flutter.dart';
import 'package:x11_flutter/x11_flutter.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:clipboard/clipboard.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:als/lang/l.dart';
import 'package:als/set/set.dart';

class SettingsDisplayPage extends StatefulWidget {
  final VoidCallback showAvncResolutionDialog;
  const SettingsDisplayPage({super.key, required this.showAvncResolutionDialog});
  @override
  State<SettingsDisplayPage> createState() => _SettingsDisplayPageState();
}

class _SettingsDisplayPageState extends State<SettingsDisplayPage> {
  late L _l;

  void _copy() async {
    if (G.wasX11Enabled) return _msg(_l.x11InvalidHint);
    final ip = await NetworkInfo().getWifiIP();
    if (mounted && ip != null) {
      await FlutterClipboard.copy((Util.getCurrentProp("vncUrl") as String).replaceAll("localhost", ip));
      _msg(_l.shareLinkCopied);
    } else {
      _msg(_l.cannotGetIpAddress);
    }
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(m)));
  Widget _f(String label, String key, {Widget? s}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: TextFormField(
      initialValue: Util.getCurrentProp(key),
      decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), labelText: label, filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2), suffixIcon: s),
      onChanged: (v) => Util.setCurrentProp(key, v),
    ),
  );
  Widget _s(String t, String k, {String? st, required ValueChanged<bool> oc}) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(t, style: const TextStyle(fontSize: 14)),
    subtitle: st != null ? Text(st, style: const TextStyle(fontSize: 12)) : null,
    value: Util.get(k) as bool,
    onChanged: oc,
  );
  Widget _btn(IconData i, String t, VoidCallback? p, {double w = double.infinity}) => SizedBox(
    width: w > 0 ? w : double.infinity,
    child: OutlinedButton(
      onPressed: p,
      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i), Text(t)]),
    ),
  );
  @override
  Widget build(BuildContext context) {
    _l = L.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_l.output), centerTitle: false),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _s(
              _l.keepScreenOn,
              "wakelock",
              oc: (v) => setState(() {
                G.prefs.setBool("wakelock", v);
                WakelockPlus.toggle(enable: v);
              }),
            ),
            _s(_l.startWithGUI, "autoLaunchVnc", oc: (v) => setState(() => G.prefs.setBool("autoLaunchVnc", v))),
            _f(_l.hidpiEnvVar, "defaultHidpiOpt"),
            _s(
              _l.hidpiSupport,
              "isHidpiEnabled",
              st: "${_l.hidpiAdvantages}\n${_l.applyOnNextLaunch}",
              oc: (v) => setState(() {
                G.prefs.setBool("isHidpiEnabled", v);
                X11Flutter.setX11ScaleFactor(v ? 0.5 : 2.0);
              }),
            ),
            const Divider(height: 18),
            Text(_l.avncAdvantages, style: SettingPage.ktext),
            _s(_l.useAVNCByDefault, "useAvnc", st: _l.applyOnNextLaunch, oc: (v) => setState(() => G.prefs.setBool("useAvnc", v))),
            _s(_l.avncScreenResize, "avncResizeDesktop", oc: (v) => setState(() => G.prefs.setBool("avncResizeDesktop", v))),
            _g([_btn(Symbols.settings_rounded, _l.avnc, () => AvncFlutter.launchPrefsPage(), w: 0), _btn(Symbols.info_rounded, _l.aboutAVNC, () => AvncFlutter.launchAboutPage(), w: 0)]),
            _btn(Symbols.aspect_ratio_rounded, _l.avncResolution, widget.showAvncResolutionDialog),
            const Divider(height: 18),
            _f(
              _l.webRedirectUrl,
              "vncUrl",
              s: IconButton(icon: const Icon(Symbols.share_rounded, size: 21), onPressed: _copy),
            ),
            _f(_l.vncLink, "vncUri"),
            const Divider(height: 18),
            Text(_l.termuxX11Advantages, style: SettingPage.ktext),
            _s(
              _l.useTermuxX11ByDefault,
              "useX11",
              st: _l.disableVNC,
              oc: (v) => setState(() {
                G.prefs.setBool("useX11", v);
                if (!v && (Util.get("dri3") as bool)) G.prefs.setBool("dri3", false);
              }),
            ),
            _btn(Symbols.tune_rounded, _l.termuxX11Preferences, () => X11Flutter.launchX11PrefsPage()),
          ],
        ),
      ),
    );
  }

  Widget _g(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Wrap(spacing: 3, runSpacing: 3, children: children),
  );
}
