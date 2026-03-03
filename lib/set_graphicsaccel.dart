import 'package:flutter/material.dart';
import 'boot.dart';
import 'lang/l.dart';
import 'set.dart';

class SettingsGraphicsAccelPage extends StatefulWidget {
  const SettingsGraphicsAccelPage({super.key});
  @override
  State<SettingsGraphicsAccelPage> createState() => _SettingsGraphicsAccelPageState();
}

class _SettingsGraphicsAccelPageState extends State<SettingsGraphicsAccelPage> {
  late L _l;
  Widget _f(String label, String key) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: TextFormField(
      initialValue: Util.getCurrentProp(key),
      decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), labelText: label, filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)),
      onChanged: (v) => Util.setCurrentProp(key, v),
    ),
  );
  Widget _s(String t, String k, {String? st, required ValueChanged<bool> oc}) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(t, style: const TextStyle(fontSize: 14)),
    subtitle: st != null ? Text(st, style: const TextStyle(fontSize: 12)) : null,
    value: Util.getGlobal(k) as bool,
    onChanged: oc,
  );
  @override
  Widget build(BuildContext context) {
    _l = L.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_l.graphicsAcceleration), centerTitle: false),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Text(_l.graphicsAccelerationHint, style: SettingPage.ktext),
            _f(_l.virglServerParams, "defaultVirglCommand"),
            _f(_l.virglEnvVar, "defaultVirglOpt"),
            _s(_l.enableVirgl, "virgl", st: _l.applyOnNextLaunch, oc: (v) => setState(() => G.prefs.setBool("virgl", v))),
            const Divider(height: 18),
            Text(_l.turnipAdvantages, style: SettingPage.ktext),
            _f(_l.turnipEnvVar, "defaultTurnipOpt"),
            _s(
              _l.enableTurnipZink,
              "turnip",
              st: _l.applyOnNextLaunch,
              oc: (v) => setState(() {
                G.prefs.setBool("turnip", v);
                if (!v && (Util.getGlobal("dri3") as bool)) G.prefs.setBool("dri3", false);
              }),
            ),
            _s(
              _l.enableDRI3,
              "dri3",
              st: _l.applyOnNextLaunch,
              oc: (v) {
                if (v && !((Util.getGlobal("turnip") as bool) && (Util.getGlobal("useX11") as bool))) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(_l.dri3Requirement)));
                  return;
                }
                setState(() => G.prefs.setBool("dri3", v));
              },
            ),
          ],
        ),
      ),
    );
  }
}
