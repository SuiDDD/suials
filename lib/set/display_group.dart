import 'dart:math';
import 'package:als/boot/utils.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:als/lang/l.dart';
import 'package:als/set/graphicsaccel.dart';
import 'package:als/set/output.dart';
import 'package:als/set/terminal.dart';

class SettingsDisplayGroupPage extends StatelessWidget {
  const SettingsDisplayGroupPage({super.key});
  void _resDialog(BuildContext context, L l) {
    final s = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final w0 = max(s.width, s.height), h0 = min(s.width, s.height);
    var w = (w0 * 0.75).round().toString(), h = (h0 * 0.75).round().toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.resolution),
        content: Column(mainAxisSize: MainAxisSize.min, children: [Text("${l.deviceScreenResolution} ${w0.round()}x${h0.round()}"), const SizedBox(height: 12), _f(ctx, l.width, w, (v) => w = v), const SizedBox(height: 12), _f(ctx, l.height, h, (v) => h = v)]),
        actions: [
          Row(
            children: [
              _btn(ctx, Symbols.close_rounded, l.cancel, () => Navigator.pop(ctx)),
              const SizedBox(width: 8),
              _btn(ctx, Symbols.save_rounded, l.save, () {
                Util.termWrite(
                  'sed -i -E "s@(geometry)=.*@\\1=${w}x$h@" /etc/tigervnc/vncserver-config-tmoe\n'
                  'sed -i -E "s@^(VNC_RESOLUTION)=.*@\\1=${w}x$h@" \$(command -v startvnc)\n',
                );
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text("${w}x$h. ${l.applyOnNextLaunch}")));
                  Navigator.pop(ctx);
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _f(BuildContext ctx, String l, String v, Function(String) c) => TextFormField(
    initialValue: v,
    onChanged: c,
    decoration: InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder(), filled: true, fillColor: Theme.of(ctx).colorScheme.surfaceContainerHighest.withAlpha(100)),
  );
  Widget _btn(BuildContext ctx, IconData i, String t, VoidCallback p) => Expanded(
    child: OutlinedButton(
      onPressed: p,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, size: 18), const SizedBox(width: 4), Text(t)]),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.display), centerTitle: false),
      body: ListView(
        children: [
          _t(context, Symbols.display_settings_rounded, l.output, l.restartAfterChange, page: SettingsDisplayPage(showAvncResolutionDialog: () => _resDialog(context, l))),
          _t(context, Symbols.terminal_rounded, l.terminal, l.enableTerminalEditing, page: const SettingsTerminalPage()),
          _t(context, Symbols.graphic_eq_rounded, l.graphicsAcceleration, l.experimentalFeature, page: const SettingsGraphicsAccelPage()),
        ],
      ),
    );
  }

  Widget _t(BuildContext context, IconData i, String t, String s, {Widget? page, VoidCallback? onTap}) => ListTile(
    leading: Icon(i, color: Theme.of(context).colorScheme.primary, size: 21),
    title: Text(t, style: const TextStyle(fontSize: 14)),
    subtitle: Text(s, style: const TextStyle(fontSize: 12)),
    onTap: onTap ?? () => Navigator.push(context, MaterialPageRoute(builder: (_) => page!)),
  );
}
