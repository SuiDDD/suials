import 'package:flutter/material.dart';
import 'boot.dart';
import 'lang/l.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'set_windowsappsupport.dart';

class AppsPage extends StatelessWidget {
  const AppsPage({super.key});
  static const List<Map<String, String>> _apps = [
    {'n': 'Windows应用支持', 'in': '', 'un': ''},
    {'n': 'Krita', 'in': 'sudo apt update && sudo apt install -y krita krita-l10n', 'un': 'sudo apt autoremove --purge -y krita krita-l10n'},
    {'n': 'Kdenlive', 'in': 'sudo apt update && sudo apt install -y kdenlive', 'un': 'sudo apt autoremove --purge -y kdenlive'},
    {'n': 'Octave', 'in': 'sudo apt update && sudo apt install -y octave', 'un': 'sudo apt autoremove --purge -y octave'},
    {'n': 'WPS', 'in': 'cat << \'EOF\' | sh && sudo dpkg --configure -a && sudo apt update && sudo apt install -y /tmp/wps.deb\nwget https://github.akams.cn/https://github.com/tiny-computer/third-party-archives/releases/download/archives/wps-office_11.1.0.11720_arm64.deb -O /tmp/wps.deb\nEOF\nrm /tmp/wps.deb', 'un': 'sudo apt autoremove --purge -y wps-office'},
    {'n': 'CAJViewer', 'in': 'wget https://download.cnki.net/net.cnki.cajviewer_1.3.20-1_arm64.deb -O /tmp/caj.deb && sudo apt update && sudo apt install -y /tmp/caj.deb && bash /home/tiny/.local/share/tiny/caj/postinst; rm /tmp/caj.deb', 'un': 'sudo apt autoremove --purge -y net.cnki.cajviewer && bash /home/tiny/.local/share/tiny/caj/postrm'},
    {'n': '亿图图示', 'in': 'wget https://cc-download.wondershare.cc/business/prd/edrawmax_13.1.0-1_arm64_binner.deb -O /tmp/edraw.deb && sudo apt update && sudo apt install -y /tmp/edraw.deb && bash /home/tiny/.local/share/tiny/edraw/postinst; rm /tmp/edraw.deb', 'un': 'sudo apt autoremove --purge -y edrawmax libldap-2.4-2'},
    {'n': 'QQ', 'in': 'wget \$(curl -s https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js | grep -oP \'"armDownloadUrl":{[^}]*"deb":"\\K[^"]+\') -O /tmp/qq.deb && sudo apt update && sudo apt install -y /tmp/qq.deb && sed -i \'s#Exec=/opt/QQ/qq %U#Exec=/opt/QQ/qq --no-sandbox %U#g\' /usr/share/applications/qq.desktop; rm /tmp/qq.deb', 'un': 'sudo apt autoremove --purge -y linuxqq'},
    {'n': '微信', 'in': 'wget https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb -O /tmp/wechat.deb && sudo apt update && sudo apt install -y /tmp/wechat.deb; rm /tmp/wechat.deb', 'un': 'sudo apt autoremove --purge -y wechat'},
    {'n': '钉钉', 'in': 'wget \$(curl -sw %{redirect_url} https://www.dingtalk.com/win/d/qd=linux_arm64) -O /tmp/dingtalk.deb && sudo apt update && sudo apt install -y /tmp/dingtalk.deb libglut3.12 libglu1-mesa && sed -i \'s#\\./com.alibabainc.dingtalk#\\./com.alibabainc.dingtalk --no-sandbox#g\' /opt/apps/com.alibabainc.dingtalk/files/Elevator.sh; rm /tmp/dingtalk.deb', 'un': 'sudo apt autoremove --purge -y com.alibabainc.dingtalk'},
    {'n': '回收站', 'in': 'sudo apt update && sudo apt install -y gvfs', 'un': ''},
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.of(context)?.apps ?? '应用'), centerTitle: false),
      body: ListView.separated(padding: const EdgeInsets.all(18), itemCount: _apps.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, i) => _tile(context, _apps[i])),
    );
  }

  Widget _tile(BuildContext context, Map<String, String> a) {
    final c = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 3),
      leading: a['n'] == 'Windows应用支持'
          ? Icon(Symbols.window_rounded, color: c.primary, size: 24)
          : CircleAvatar(
              radius: 18,
              backgroundColor: c.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Text(
                a['n']![0],
                style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
      title: Text(a['n']!, style: const TextStyle(fontSize: 14)),
      trailing: a['n'] == 'Windows应用支持'
          ? const Icon(Symbols.chevron_right_rounded, size: 18)
          : _g([
              IconButton.filledTonal(
                onPressed: () {
                  Util.termWrite(a['in']!);
                  Navigator.pop(context);
                  G.pageIndex.value = 0;
                },
                icon: const Icon(Symbols.download_for_offline_rounded, size: 21),
              ),
              if (a['un']!.isNotEmpty)
                IconButton.outlined(
                  onPressed: () {
                    Util.termWrite(a['un']!);
                    Navigator.pop(context);
                    G.pageIndex.value = 0;
                  },
                  icon: const Icon(Symbols.delete_sweep_rounded, size: 21),
                ),
            ]),
      onTap: a['n'] == 'Windows应用支持' ? () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const SettingsWindowsAppSupportPage())) : null,
    );
  }

  Widget _g(List<Widget> children) => Wrap(spacing: 6, children: children);
}
