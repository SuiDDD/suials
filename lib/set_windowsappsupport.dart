import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'boot.dart';
import 'lang/l.dart';
import 'set.dart';

class SettingsWindowsAppSupportPage extends StatelessWidget {
  const SettingsWindowsAppSupportPage({super.key});
  Widget _btn(BuildContext ctx, IconData i, String t, String c, double w) => SizedBox(
    width: w,
    child: OutlinedButton.icon(
      onPressed: () {
        Util.termWrite(c);
        Navigator.pop(ctx);
        G.pageIndex.value = 0;
      },
      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
      icon: Icon(i),
      label: Text(t, overflow: TextOverflow.ellipsis),
    ),
  );
  Widget _g(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Wrap(spacing: 6, runSpacing: 6, children: children),
  );
  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    final w = (MediaQuery.of(context).size.width - 36 - 6) / 2;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    const p = "bash ~/.local/share/tiny/extra/";
    return Scaffold(
      appBar: AppBar(title: Text(l.windowsAppSupport), centerTitle: false),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.hangoverDescription, style: SettingPage.ktext),
            _g([_btn(context, Symbols.download_rounded, "${l.installHangoverStable}(10.14)", "${p}install-hangover-stable", w), _btn(context, Symbols.update_rounded, l.installHangoverLatest, "${p}install-hangover", w), _btn(context, Symbols.delete_sweep_rounded, l.uninstallHangover, "sudo apt autoremove --purge -y hangover*", w), _btn(context, Symbols.mop_rounded, l.clearWineData, "rm -rf ~/.wine", w)]),
            const Divider(height: 18, thickness: 1),
            Text(l.wineCommandsHint, style: SettingPage.ktext),
            Text(l.restartRequiredHint, style: SettingPage.ktext.copyWith(color: Theme.of(context).colorScheme.outline)),
            _g([for (var e in (isZh ? D.wineCommands : D.wineCommands4En)) _btn(context, Symbols.terminal_rounded, e["name"]!, e["command"]!, w)]),
          ],
        ),
      ),
    );
  }
}
