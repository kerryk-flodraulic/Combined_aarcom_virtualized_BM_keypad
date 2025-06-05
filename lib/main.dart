import 'package:flutter/material.dart';
import 'aarcom_rcu.dart';
import 'bm_keypad.dart';


void main() {
  runApp(const CombinedApp());
}

class CombinedApp extends StatelessWidget {
  const CombinedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Combined AARCOMM + BM Keypad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CombinedHome(),
    );
  }
}

class CombinedHome extends StatelessWidget {
  const CombinedHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AARCOMM Virtualized RCU + BM Keypad Interface'),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          // 🟦 Left side: AARCOMM RCU
          Expanded(
            flex: 1,
            child: AARCommRCU(),
          ),

          VerticalDivider(width: 1, color: Colors.white30),

          // 🟨 Right side: BM Keypad
          Expanded(
            flex: 1,
            child: BMKeypadScreen(),
          ),
        ],
      ),
    );
  }
}
