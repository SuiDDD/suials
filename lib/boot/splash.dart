import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'setup.dart';

class BootPage extends StatefulWidget {
  const BootPage({super.key});
  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> {
  String? log;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await Future.wait([BootSetup.bootstrap(), Future.delayed(const Duration(seconds: 3))]);
    } catch (e) {
      if (mounted) setState(() => log = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    var style = GoogleFonts.ubuntu(color: Colors.white);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.bottomCenter,
              child: Text("AndLinSys", style: style.copyWith(fontSize: 27)),
            ),
          ),
          Expanded(
            child: Container(
              alignment: Alignment.topCenter,
              child: log != null ? Text(log!, style: style.copyWith(color: Colors.red, fontSize: 12)) : null,
            ),
          ),
          Expanded(
            child: Container(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Powered by", style: style.copyWith(color: Colors.grey, fontSize: 9)),
                  Text("ChRoot", style: style.copyWith(fontSize: 18)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
