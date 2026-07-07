import 'package:flutter/material.dart';

import 'screens/pairing_screen.dart';

void main() {
  runApp(const BeamngRemotePlusApp());
}

class BeamngRemotePlusApp extends StatelessWidget {
  const BeamngRemotePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeamNG RemotePlus',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orangeAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PairingScreen(),
    );
  }
}
