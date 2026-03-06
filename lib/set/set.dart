import 'dart:io';
import 'package:als/apps.dart';
import 'package:als/boot/globals.dart';
import 'package:als/boot/utils.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:als/lang/l.dart';
import 'package:als/set/display_group.dart';
import 'package:als/set/usermanual.dart';
import 'package:als/set/system.dart';
import 'package:als/set/sound.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});
  static const ktext = TextStyle(fontWeight: FontWeight.w300);
  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> with SingleTickerProviderStateMixin {
  late L _l;
  String _ipAddress = "...";
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _getIp();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _getIp() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      if (mounted) setState(() => _ipAddress = ifs.isNotEmpty ? ifs.first.addresses.first.address : "N/A");
    } catch (_) {
      if (mounted) setState(() => _ipAddress = "N/A");
    }
  }

  void _editCmd(int? i) {
    var cmds = Util.getCurrentProp("commands");
    String n = i != null ? cmds[i]["name"] : "", c = i != null ? cmds[i]["command"] : "";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l.commandEdit),
        content: Column(mainAxisSize: MainAxisSize.min, children: [_f(n, (v) => n = v, _l.commandName), const SizedBox(height: 9), _f(c, (v) => c = v, _l.commandContent)]),
        actions: [
          if (i != null) TextButton(onPressed: () => _saveCmd(cmds..removeAt(i), ctx), child: Text(_l.deleteItem)),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_l.cancel)),
          TextButton(onPressed: () => _saveCmd(i != null ? (cmds..[i] = {"name": n, "command": c}) : (cmds..add({"name": n, "command": c})), ctx), child: Text(i != null ? _l.save : _l.add)),
        ],
      ),
    );
  }

  void _saveCmd(dynamic data, BuildContext ctx) async {
    await Util.setCurrentProp("commands", data);
    if (!ctx.mounted) return;
    if (mounted) setState(() {});
    Navigator.pop(ctx);
  }

  Widget _f(String v, Function(String) c, String l) => TextFormField(
    initialValue: v,
    onChanged: c,
    decoration: InputDecoration(labelText: l, isDense: true, border: const OutlineInputBorder(), filled: true, fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100)),
  );
  Widget _tile(IconData i, String t, {String? s, Widget? p, Color? ic}) => ListTile(
    dense: true,
    contentPadding: null,
    leading: Icon(i, color: ic ?? Theme.of(context).colorScheme.primary),
    title: Text(t),
    trailing: s != null && s.isNotEmpty ? Text(s, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))) : null,
    onTap: p != null ? () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => p)) : null,
  );
  void _exec(String cmd) {
    Util.termWrite(cmd);
    G.pageIndex.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    _l = L.of(context)!;
    final List cmds = Util.getCurrentProp("commands");
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return GestureDetector(
      onHorizontalDragEnd: (d) => d.primaryVelocity! > 500 ? G.pageIndex.value = 0 : null,
      child: ListView(
        children: [
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  height: MediaQuery.of(context).size.height / 3,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: SweepGradient(center: Alignment.center, transform: GradientRotation(_controller.value * 6.283185), colors: const [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.cyan, Colors.blue, Colors.purple, Colors.red]),
                  ),
                  child: child,
                );
              },
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    children: [
                      if (!isLandscape) ...[
                        Center(
                          child: Text("AndLinSys", style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w600)),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(padding: const EdgeInsets.only(bottom: 18), child: Text("Debian 13 (Trixie)")),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              cmds.length > 3 ? 3 : cmds.length,
                              (i) => IconButton(
                                icon: Icon(
                                  i == 0
                                      ? Symbols.update_rounded
                                      : i == 1
                                      ? Symbols.info_i_rounded
                                      : Symbols.power_settings_new_rounded,
                                ),
                                onPressed: () => _exec(cmds[i]["command"]),
                                onLongPress: () => _editCmd(i),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("AndLinSys", style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 9),
                              Text("Debian 13 (Trixie)"),
                            ],
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              cmds.length > 3 ? 3 : cmds.length,
                              (i) => IconButton(
                                icon: Icon(
                                  i == 0
                                      ? Symbols.system_update_alt_rounded
                                      : i == 1
                                      ? Symbols.info_i_rounded
                                      : Symbols.power_settings_new_rounded,
                                ),
                                onPressed: () => _exec(cmds[i]["command"]),
                                onLongPress: () => _editCmd(i),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          _tile(Symbols.wifi_rounded, _l.network, s: _ipAddress, ic: _ipAddress == "N/A" ? Colors.grey : null),
          _tile(Symbols.display_settings_rounded, _l.display, p: const SettingsDisplayGroupPage()),
          _tile(Symbols.volume_up_rounded, _l.sound, p: const SettingsSoundPage()),
          _tile(Symbols.apps_rounded, _l.apps, p: const AppsPage()),
          _tile(Symbols.settings_suggest_rounded, _l.system, p: const SettingsSystemPage()),
          _tile(Symbols.help_center_rounded, _l.help, p: const SettingsUserManualPage()),
        ],
      ),
    );
  }
}
