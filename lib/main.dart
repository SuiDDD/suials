import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'boot.dart';
import 'lang/l.dart';
import 'set.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
    builder: (l, d) => MaterialApp(
      localizationsDelegates: const [L.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: ['en', 'zh'].map((s) => Locale(s)),
      theme: ThemeData(colorScheme: l, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: d, useMaterial3: true),
      home: const MyHomePage(),
    ),
  );
}

class ForceScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) => super.acceptGesture(pointer);
}

class TerminalPage extends StatelessWidget {
  const TerminalPage({super.key});
  void _jump() => G.wasX11Enabled ? Workflow.launchX11() : (G.wasAvncEnabled ? Workflow.launchAvnc() : Workflow.launchBrowser());
  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragEnd: (e) => e.primaryVelocity! > 500 ? _jump() : (e.primaryVelocity! < -500 ? G.pageIndex.value = 1 : null),
    child: SizedBox.expand(
      child: Column(
        children: [
          Expanded(
            child: RawGestureDetector(
              gestures: {
                ForceScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ForceScaleGestureRecognizer>(() => ForceScaleGestureRecognizer(), (d) {
                  d.onUpdate = (x) => G.termFontScale.value = (x.scale * (Util.getGlobal("termFontScale") as double)).clamp(0.2, 5);
                  d.onEnd = (x) => G.prefs.setDouble("termFontScale", G.termFontScale.value);
                }),
              },
              child: ValueListenableBuilder(
                valueListenable: G.termFontScale,
                builder: (_, v, __) => TerminalView(G.termPtys[G.currentContainer]!.terminal, textScaler: TextScaler.linear(v), keyboardType: TextInputType.multiline),
              ),
            ),
          ),
          if (Util.getGlobal("isTerminalCommandsEnabled") as bool) _cmdBar(),
        ],
      ),
    ),
  );
  Widget _cmdBar() => Padding(
    padding: const EdgeInsets.all(6),
    child: Row(
      children: [
        AnimatedBuilder(
          animation: G.keyboard,
          builder: (_, __) => ToggleButtons(constraints: const BoxConstraints(minWidth: 42, minHeight: 27), tapTargetSize: MaterialTapTargetSize.shrinkWrap, borderRadius: BorderRadius.circular(6), isSelected: [G.keyboard.ctrl, G.keyboard.alt, G.keyboard.shift], onPressed: (i) => i == 0 ? G.keyboard.ctrl = !G.keyboard.ctrl : (i == 1 ? G.keyboard.alt = !G.keyboard.alt : G.keyboard.shift = !G.keyboard.shift), children: const [Text('Ctrl'), Text('Alt'), Text('Shift')]),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 27,
            child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: D.termCommands.length, separatorBuilder: (_, __) => const SizedBox(width: 3), itemBuilder: (_, i) => _b(D.termCommands[i]["name"] as String, () => G.termPtys[G.currentContainer]!.terminal.keyInput(D.termCommands[i]["key"] as TerminalKey))),
          ),
        ),
      ],
    ),
  );
  Widget _b(String text, VoidCallback tap) => OutlinedButton(
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 9), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    onPressed: tap,
    child: Text(text),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _ok = false;
  @override
  void initState() {
    super.initState();
    Workflow.workflow().then((_) {
      if (mounted) setState(() => _ok = true);
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    G.homePageStateContext = context;
    return Scaffold(
      body: _ok
          ? ValueListenableBuilder(
              valueListenable: G.pageIndex,
              builder: (_, i, __) => IndexedStack(
                index: i,
                children: [
                  const TerminalPage(),
                  const Scrollbar(child: SettingPage()),
                ],
              ),
            )
          : const LoadingPage(),
    );
  }
}
