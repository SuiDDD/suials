import 'package:flutter/material.dart';
import 'boot.dart';
import 'lang/l.dart';
import 'set.dart';

class SettingsSoundPage extends StatefulWidget {
  const SettingsSoundPage({super.key});
  @override
  State<SettingsSoundPage> createState() => _SettingsSoundPageState();
}

class _SettingsSoundPageState extends State<SettingsSoundPage> {
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
  @override
  Widget build(BuildContext context) {
    _l = L.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_l.sound), centerTitle: false),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _f(_l.pulseaudioPort, "defaultAudioPort", g: true, n: 0, x: 65535),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(_l.restartRequiredHint, style: SettingPage.ktext),
            ),
          ],
        ),
      ),
    );
  }
}
