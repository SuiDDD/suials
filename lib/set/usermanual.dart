import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:als/lang/l.dart';
import 'package:als/set/set.dart';

class SettingsUserManualPage extends StatelessWidget {
  const SettingsUserManualPage({super.key});
  Widget _btn(IconData i, String t, VoidCallback p, {double w = double.infinity}) => SizedBox(
    width: w > 0 ? w : double.infinity,
    child: OutlinedButton(
      onPressed: p,
      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(i),
          Text(t, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final l = L.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.userManual), centerTitle: false),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Text(l.firstLoadInstructions, style: SettingPage.ktext),
            _btn(Symbols.folder_shared_rounded, l.requestStoragePermission, () => Permission.storage.request()),
            _btn(Symbols.manage_accounts_rounded, l.requestAllFilesAccess, () => Permission.manageExternalStorage.request()),
            _btn(Symbols.battery_saver_rounded, l.ignoreBatteryOptimization, () => Permission.ignoreBatteryOptimizations.request()),
            const Divider(height: 18),
            Text(l.updateRequest, style: SettingPage.ktext),
          ],
        ),
      ),
    );
  }
}
