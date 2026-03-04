import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter/material.dart';
import 'globals.dart';
import 'utils.dart';
import 'constants.dart';

class VirtualKeyboard extends TerminalInputHandler with ChangeNotifier {
  final TerminalInputHandler _h;
  VirtualKeyboard(this._h);
  bool ctrl = false, shift = false, alt = false;
  @override
  String? call(TerminalKeyboardEvent e) {
    final r = _h.call(e.copyWith(ctrl: e.ctrl || ctrl, shift: e.shift || shift, alt: e.alt || alt));
    G.maybeCtrlJ = e.key.name == "keyJ";
    if (!(Util.get("isStickyKey"))) {
      ctrl = shift = alt = false;
      notifyListeners();
    }
    return r;
  }
}

class TermPty {
  late final Terminal terminal;
  late final Pty pty;
  TermPty() {
    terminal = Terminal(inputHandler: G.keyboard, maxLines: Util.get("termMaxLines"));
    pty = Pty.start("/system/bin/sh", workingDirectory: G.dataPath, columns: terminal.viewWidth, rows: terminal.viewHeight);
    pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen(terminal.write);
    pty.exitCode.then((c) {
      terminal.write('exited: $c');
      if (c == 0) SystemChannels.platform.invokeMethod("SystemNavigator.pop");
      if (c == -9) D.androidChannel.invokeMethod("launchSignal9Page");
    });
    terminal.onOutput = (d) {
      if (!(Util.get("isTerminalWriteEnabled"))) return;
      for (var char in d.split("")) {
        if (char == "\n" && !G.maybeCtrlJ) {
          terminal.keyInput(TerminalKey.enter);
          continue;
        }
        G.maybeCtrlJ = false;
        pty.write(const Utf8Encoder().convert(char));
      }
    };
    terminal.onResize = (w, h, pw, ph) => pty.resize(h, w);
  }
}
