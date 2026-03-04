import 'package:als/boot/globals.dart';
import 'package:als/boot/utils.dart';
import 'package:flutter/material.dart';
import 'package:als/lang/l.dart';

class SettingsTerminalPage extends StatefulWidget {
  const SettingsTerminalPage({super.key});
  @override
  State<SettingsTerminalPage> createState() => _SettingsTerminalPageState();
}

class _SettingsTerminalPageState extends State<SettingsTerminalPage> {
  late L _l;
  Widget _f(String l, String k, int n, int x) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: TextFormField(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      initialValue: (Util.get(k) as int).toString(),
      decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), labelText: l, filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)),
      keyboardType: TextInputType.number,
      validator: (v) => Util.validateBetween(v, n, x, () => G.prefs.setInt(k, int.parse(v!))),
    ),
  );
  Widget _s(String t, String k, {VoidCallback? c}) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(t, style: const TextStyle(fontSize: 14)),
    value: Util.get(k) as bool,
    onChanged: (v) => setState(() {
      G.prefs.setBool(k, v);
      c?.call();
    }),
  );
  @override
  Widget build(BuildContext context) {
    _l = L.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(_l.terminal), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _f(_l.terminalMaxLines, "termMaxLines", 1024, 2147483647),
          _s(_l.enableTerminal, "isTerminalWriteEnabled"),
          _s(_l.enableTerminalKeypad, "isTerminalCommandsEnabled", c: () => G.terminalPageChange.value = !G.terminalPageChange.value),
          _s(_l.terminalStickyKeys, "isStickyKey"),
        ],
      ),
    );
  }
}
