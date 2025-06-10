//PROBLEM IN CODE: WHEN 2X2 BUTTON K1 IS PRESSED IN THE LIVE FEED IT IS LOGGING TWO DIFFERENT ENTERIES ONE WITH CHO WHICH IS VALID AND A REPEAT WITH 1 WHICH IS NOT VALID 

//Keypad 2x2 and keypad 2x6 official application

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth.dart';
import 'crc32.dart';
import 'package:flutter/cupertino.dart';
import 'globals.dart';
import 'can_log_entry.dart';
import 'shared_widgets.dart';

const int canId2x2 = 0x195;
const int canId2x6 = 0x1A5;

/*
//Log entry model for can messages
class CanLogEntry {
  final String channel;
  final String canId;
  final String dlc;
  final String data;
  final String dir;
  final String time;
  final String button;

  CanLogEntry({
    required this.channel,
    required this.canId,
    required this.dlc,
    required this.data,
    required this.dir,
    required this.time,
    required this.button,
  });
}

*/
List<int> dataBytes = List.filled(8, 0); // 8 bytes = 64 bits of state
List<int> ledBytes = List.filled(8, 0); // For LED states (used by PKP2200)

final Map<String, bool> buttonStates = {}; // Tracks ON/OFF state

//Main screen with keypad and CAN log display
class BMKeypadScreen extends StatefulWidget {
  const BMKeypadScreen({super.key});

  @override
  State<BMKeypadScreen> createState() => _BMKeypadScreenState();
}

class _BMKeypadScreenState extends State<BMKeypadScreen> {
  String getPressed2x2Buttons() {
    final pressed = keypad2x2.where((k) => buttonStates[k] == true).toList();
    return pressed.isEmpty ? 'None' : pressed.join(', ');
  }

  String _describePressedKeys() {
    final keys = keypad2x2.where((k) => buttonStates[k] == true).toList();
    return keys.isEmpty ? 'None' : keys.join(', ');
  }

  bool _showFixedFeed = false;
  Map<String, List<String>> fixedCanHistoryMap = {};

// new to prevent duplicates:

  bool _autoTestRunOnce = false;
  bool _autoTestHasRun = false;

  Timer? _liveCanTimer;
  DateTime? firstButtonPressTime;

  void _sendLastRawFrame() {
    if (sharedCanLog.isEmpty) {
      //Add \u274c for logo
      debugPrint("No frame in log to send.");
      return;
    }

    final lastEntry = sharedCanLog.last;

    // Parse CAN ID
    final canId = int.tryParse(lastEntry.canId, radix: 16);
    if (canId == null) {
      debugPrint("\u274c Invalid CAN ID format.");
      return;
    }

    // Parse data bytes
    final dataBytes = lastEntry.data
        .split(' ')
        .map((hex) => int.tryParse(hex, radix: 16) ?? 0)
        .toList();

    if (dataBytes.length != 8) {
      //add \u274c infront for logo opt
      debugPrint("Frame must be exactly 8 bytes.");
      return;
    }

    final deviceId = CanBluetooth.instance.connectedDevices.keys.firstOrNull;
    if (deviceId == null) {
      //Add \u274c infront for logo opt
      debugPrint("No connected Bluetooth device.");
      return;
    }
    // Represents a single CAN frame message to be sent over Bluetooth
    // Includes the CAN identifier, 8-byte payload, and a flag
    final message = BlueMessage(
      identifier: canId,
      data: dataBytes,
      flagged: true,
    );

    CanBluetooth.instance.sendCANMessage(deviceId, message);
    debugPrint(
      //Add \u2705 infront for logo (opt)
      // Formats the CAN ID as an 8-character zero-padded hexadecimal string (e.g., 00000180)
      "Sent raw frame from log: ID=\${canId.toRadixString(16).padLeft(8, '0')} DATA=\${dataBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}",
    );
  }

  bool _isDarkMode = true;
  bool _autoScrollEnabled = true;
  final TextEditingController _deviceFilterController = TextEditingController();
  String _deviceNameFilter = '';

  String getPressed2x6Buttons() {
    final pressed = keypad2x6.where((k) => buttonStates[k] == true).toList();
    return pressed.isEmpty ? 'None' : pressed.join(', ');
  }

  // Handles press logic for 2x2 and 2x6 buttons, updates CAN bytes and logs
  final List<String> keypad2x2 = ['K1', 'K2', 'K3', 'K4']; // K = Keypad PKP2200
  // Defines button labels for the 2x6 PKP2600 keypad (F1–F12)
  final List<String> keypad2x6 = [
    'F1',
    'F2',
    'F3',
    'F4',
    'F5',
    'F6',
    'F7',
    'F8',
    'F9',
    'F10',
    'F11',
    'F12',
  ];

  /*
  // Maps 2x2 keys (PKP2200) to LED control byte/bit positions in CAN frames
  final Map<String, List<int>> ledButtonMap = {
    'K1': [0, 0],
    'K2': [0, 1],
    'K3': [0, 2],
    'K4': [0, 3],
  };
  // Maps 2x6 keys (PKP2600) to data byte/bit positions for functional control
  final Map<String, List<int>> buttonBitMap = {
    'F1': [0, 0],
    'F2': [0, 1],
    'F3': [0, 2],
    'F4': [0, 3],
    'F5': [0, 4],
    'F6': [0, 5],
    'F7': [1, 0],
    'F8': [1, 1],
    'F9': [1, 2],
    'F10': [1, 3],
    'F11': [1, 4],
    'F12': [1, 5],
  };
  */

  // NEW BITMAP:

  final Map<String, List<int>> ledButtonMap = {
    'K1': [0, 0], // Bit 0
    'K2': [0, 1], // Bit 1
    'K3': [0, 2], // Bit 2
    'K4': [0, 3], // Bit 3
  };

  final Map<String, List<int>> buttonBitMap = {
    'F1': [0, 0],
    'F2': [0, 1],
    'F3': [0, 2],
    'F4': [0, 3],
    'F5': [0, 4],
    'F6': [0, 5],
    'F7': [0, 6],
    'F8': [0, 7],
    'F9': [1, 0],
    'F10': [1, 1],
    'F11': [1, 2],
    'F12': [1, 3],
  };

  //Reset all buttons and Led Data bytes
  void _resetAllButtons() {
    setState(() {
      dataBytes = List.filled(8, 0);
      ledBytes = List.filled(8, 0);
      buttonStates.clear();
    });
  }

  //Clears only the 2x2 keypad and sends cleared can frames + logs
  void _clear2x2Buttons() {
    setState(() {
      //Resets
      for (var key in ['K1', 'K2', 'K3', 'K4']) {
        buttonStates[key] = false;
      }
      ledBytes = List.filled(8, 0);

      // Only declare once
      final deviceId = CanBluetooth.instance.connectedDevices.keys.firstOrNull;
      if (deviceId == null) {
        debugPrint(" No connected device found.");
        return;
      }

      // Send Cleared Frame PKP2200
      final clearedFrame = BlueMessage(
        identifier: 0x00000195,
        data: List.filled(8, 0x00),
        flagged: true,
      );
      CanBluetooth.instance.sendCANMessage(deviceId, clearedFrame);

      // Log LED  Frame
      List<int> ledDataBytes = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
      String ledData = ledDataBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ')
          .toUpperCase();
      // Logs the outgoing CAN frame along with button state and timestamp

      sharedCanLog.add(
        CanLogEntry(
          channel: 'CH0',
          canId: '00000195', //225
          dlc: '8',
          data: ledData,
          dir: 'TX',
          time: _elapsedFormatted,
          button: 'LEDs Off',
        ),
      );

      // Send LED Frame over Bluetooth
      final ledFrame = BlueMessage(
        identifier: 0x00000195,
        data: [0x0F, 0x0F, 0x0F, 0x0F, 0x00, 0x00, 0x00, 0x00],
        flagged: true,
      );
      CanBluetooth.instance.sendCANMessage(deviceId, ledFrame);
    });
  }

  void _startAutoTest() async {
    final deviceId = CanBluetooth.instance.connectedDevices.keys.firstOrNull;
    if (deviceId == null) {
      debugPrint('No Bluetooth device connected for test.');
      return;
    }

    final allKeys = [...keypad2x2, ...keypad2x6];
    int initialFrameCount = sharedCanLog.length;

    debugPrint('Auto Test started with delay $_autoTestDelayMs ms');

    // PRESS phase — one by one
    for (String key in allKeys) {
      setState(() => _currentTestKey = key);
      _handleButtonPress(key);
      await Future.delayed(Duration(milliseconds: _autoTestDelayMs));
    }

    // Wait briefly before clearing
    await Future.delayed(const Duration(milliseconds: 600));

    // BULK DESELECT: like pressing "Reset All"
    _resetAllButtons();

    setState(() => _currentTestKey = null);
  /*
    // Show completion result
    final newFrames = sharedCanLog.length - initialFrameCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Auto Test complete: $newFrames frames sent')),
    );
    */
  }

  //Clears only 2x6 keypad and logs
  void _clear2x6Buttons() {
    setState(() {
      for (var key in [
        'F1',
        'F2',
        'F3',
        'F4',
        'F5',
        'F6',
        'F7',
        'F8',
        'F9',
        'F10',
        'F11',
        'F12',
      ]) {
        buttonStates[key] = false;
      }
      dataBytes = List.filled(8, 0);

      String data = dataBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ')
          .toUpperCase();

    });
  }

  List<int> getByteValues() {
    return dataBytes;
  }

  List<String> createCanFrame(List<int> bytes, Duration duration, int canId) {
    final formattedTime = _formatDuration(duration);
    final dataString = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();

    final pressed = [
      ...keypad2x2.where((k) => buttonStates[k] == true),
      ...keypad2x6.where((k) => buttonStates[k] == true),
    ].join(', ');

    return [
      //'CH0', // Channel COMMENTED OUT 
      canId.toRadixString(16).padLeft(8, '0'), // Proper dynamic CAN ID

      '8', // DLC
      dataString, // Data payload
      formattedTime, // Timestamp
      'TX', // Direction
     pressed.isEmpty ? 'No buttons pressed' : pressed,
    ];
    
  }
  

  int _getCurrentCanId() {
    // If any 2x2 key is pressed, return 0x195
    if (keypad2x2.any((k) => buttonStates[k] == true)) {
      return canId2x2;
    }
    // If any 2x6 key is pressed, return 0x1A5
    if (keypad2x6.any((k) => buttonStates[k] == true)) {
      return canId2x6;
    }
    // Default fallback
    return 0x000;
  }

  void _startLiveFeed() {
    _liveCanTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final elapsed = now.difference(firstButtonPressTime ?? now);

      final hasAnyPressed = keypad2x2.any((k) => buttonStates[k] == true) ||
          keypad2x6.any((k) => buttonStates[k] == true);
      if (!hasAnyPressed) return;

      final bytes = getByteValues();
      // Skip if no button is pressed (prevents spamming 'No buttons pressed')
      if (!buttonStates.values.any((v) => v == true)) return;

    //  Only build a frame if buttons are pressed
      final frame = createCanFrame(bytes, elapsed, _getCurrentCanId());

      final key = '${frame[3]}|${frame[6]}';
      fixedCanHistoryMap[key] = frame;

      sharedCanLog.add(
        CanLogEntry(
          channel: frame[0],
          canId: frame[1],
          dlc: frame[2],
          data: frame[3],
          time: frame[4],
          dir: frame[5],
          button: frame[6],
        ),
      );

      if (CanBluetooth.instance.connectedDevices.isNotEmpty) {
        CanBluetooth.instance.sendCANMessage(
          CanBluetooth.instance.connectedDevices.keys.first,
          BlueMessage(
            data: bytes,
            identifier: 0x0CFF0171,
            flagged: true,
          ),
        );
      }
    });
  }

  // Returns the name of the currently connected Bluetooth device (or fallback)
  String get connectedDeviceName {
    if (CanBluetooth.instance.connectedDevices.isEmpty) {
      return 'No Bluetooth connected';
    }
    final deviceId = CanBluetooth.instance.connectedDevices.keys.first;
    final device = CanBluetooth.instance.scanResults[deviceId]?.device;
    final name = CanBluetooth
        .instance.scanResults[deviceId]?.advertisementData.localName;

    return name != null && name.isNotEmpty
        ? 'Connected to: $name'
        : 'Connected to: $deviceId';
  }

  //Formats elapsed stopwatch time as MM:SS.mmm for display
  String get _elapsedFormatted {
    final elapsed = _stopwatch.elapsed;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (elapsed.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }

  // Builds the Bluetooth scan results list with signal strength and connect/disconnect control
  Widget bluetoothDeviceList() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.tealAccent),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ValueListenableBuilder(
        valueListenable: CanBluetooth.instance.addedDevice,
        builder: (_, __, ___) {
          // Filter device names using the user-defined text filter
          final entries =
              CanBluetooth.instance.scanResults.entries.where((entry) {
            final name = entry.value.advertisementData.localName.toLowerCase();
            return name.contains(_deviceNameFilter);
          }).toList();

          return ListView(
            children: entries.map((entry) {
              final device = entry.value.device;
              final name = entry.value.advertisementData.localName;
              final isConnected = CanBluetooth.instance.connectedDevices
                  .containsKey(device.remoteId.str);
              // Shows signal icon, RSSI in dBm, and device name
              return ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Row(
                  children: [
                    Icon(
                      entry.value.rssi > -60
                          ? Icons.signal_cellular_4_bar
                          : entry.value.rssi > -80
                              ? Icons.signal_cellular_alt
                              : Icons.signal_cellular_null,
                      size: 18,
                      color: entry.value.rssi > -70
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(name.isNotEmpty ? name : '(Unnamed)'),
                  ],
                ),
                subtitle: Text(device.remoteId.str),
                // Connection button
                trailing: ElevatedButton(
                  onPressed: () {
                    if (isConnected) {
                      CanBluetooth.instance.disconnect(device);
                    } else {
                      CanBluetooth.instance.connect(device);
                    }
                  },
                  child: Text(isConnected ? 'Disconnect' : 'Connect'),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget scanControl() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () => CanBluetooth.instance.startScan(),
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text("Scan"),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => CanBluetooth.instance.stopScan(),
          icon: const Icon(Icons.stop),
          label: const Text("Stop"),
        ),
      ],
    );
  }

  // Requests Bluetooth and location permissions required for scanning
  Future<void> _ensureBluetoothPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  @override
  void initState() {
    super.initState();

    _stopwatch = Stopwatch()..start();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {});
    });

    _ensureBluetoothPermissions();

    CanBluetooth.instance.init();
    CanBluetooth.instance.startScan();
/*
    // NEW AUTO CONNECT feauture - Pratik said it may not be necessary
    Future.delayed(const Duration(seconds: 2), () async {
      final targetId = 'fd000000000i0'.toLowerCase();
      final matches = CanBluetooth.instance.scanResults.values.where((result) {
        final name = result.advertisementData.localName.toLowerCase();
        final id = result.device.remoteId.str.toLowerCase();
        return name == targetId || id == targetId;
      });

      if (matches.isNotEmpty) {
        final device = matches.first.device;
        await CanBluetooth.instance.connect(device);
        debugPrint('Auto-connected to $targetId');

        if (!_autoTestRunOnce) {
          _autoTestRunOnce = true;
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              // _startAutoTest();
            }
          });
        }
      }
    });

    */

    CanBluetooth.instance.addedDevice.addListener(() {
      setState(() {});
    });

    firstButtonPressTime = DateTime.now();
    _startLiveFeed();
  }

  @override
  void dispose() {
    _liveCanTimer?.cancel(); // Cancel periodic timer
    super.dispose();
  }

  Widget build2x2Keypad() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: _keypadBoxDecoration(),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                2,
                (i) => buildKeypadButton(keypad2x2[i]),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                2,
                (i) => buildKeypadButton(keypad2x2[i + 2]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget build2x6Keypad() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        decoration: _keypadBoxDecoration(),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: List.generate(3, (row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (col) {
                int index = row * 6 + col;
                return index < keypad2x6.length
                    ? buildKeypadButton(keypad2x6[index])
                    : const SizedBox(width: 56, height: 56);
              }),
            );
          }),
        ),
      ),
    );
  }

  Widget buildKeypadButton(String label) {
    final is2x2 = ['K1', 'K2', 'K3', 'K4'].contains(label);
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: SizedBox(
        width: 80,
        height: 80,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: buttonStates[label] == true
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color:
                buttonStates[label] == true ? Colors.green : Colors.grey[800],
            shape: is2x2 ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: is2x2 ? null : BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: buildButton(label),
        ),
      ),
    );
  }

  BoxDecoration _keypadBoxDecoration() {
    return BoxDecoration(
      color: Colors.grey.shade900,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  //Cacnels timer to avoid mem leaks

  late final Stopwatch _stopwatch; //Tracks elapsed time
  late final Timer _timer; //Triggers UI to refresh every 100ms
  bool _isTimerRunning = true; // Controls pause/resume
  int _tickCounter = 0;

  int _nextTickByte() {
    _tickCounter = (_tickCounter + 1) % 256;
    return _tickCounter;
  }

  //Added for testing
  int _autoTestDelayMs = 400; // Default: Normal speed
  String? _currentTestKey; // Used to highlight the active button

  //final List<CanLogEntry> canFrameLog = [];
  //CAN log ents.
  final ScrollController _logScrollController = ScrollController();
  // Handles press logic for 2x2 and 2x6 buttons, updates CAN bytes and logs
  void _handleButtonPress(String label) {
    HapticFeedback.lightImpact();
    final elapsed = _stopwatch.elapsed;
    final timestamp =
        '${elapsed.inSeconds}.${(elapsed.inMilliseconds % 1000).toString().padLeft(3, '0')}s';

    // Toggle the state
    buttonStates[label] = !(buttonStates[label] ?? false);
    /*
    // Update 2x6 data bytes if applicable
    if (buttonBitMap.containsKey(label)) {
      final byteIndex = buttonBitMap[label]![0];
      final bitIndex = buttonBitMap[label]![1];
      if (buttonStates[label] == true) {
        dataBytes[byteIndex] |= (1 << bitIndex);
      } else {
        dataBytes[byteIndex] &= ~(1 << bitIndex);
      }
    }
        */

    //NEW BITMAP:

    // Update 2x6 data bytes if applicable
    if (buttonBitMap.containsKey(label)) {
      final byteIndex = buttonBitMap[label]![0];
      final bitIndex = buttonBitMap[label]![1];
      if (buttonStates[label] == true) {
        dataBytes[byteIndex] |= (1 << bitIndex);
      } else {
        dataBytes[byteIndex] &= ~(1 << bitIndex);
      }
      _sendFunctionFrame(); // Send over Bluetooth
    }

    /*
    // Update 2x2 LED bytes if applicable
    if (ledButtonMap.containsKey(label)) {
      final byteIndex = ledButtonMap[label]![0];
      final bitIndex = ledButtonMap[label]![1];
      if (buttonStates[label] == true) {
        ledBytes[byteIndex] |= (1 << bitIndex);
      } else {
        ledBytes[byteIndex] &= ~(1 << bitIndex);
      }
    }
      */

    //NEW BITMAP:

    String formattedData;
    String canId;
    String buttonExplanation;

    if (ledButtonMap.containsKey(label)) {
      final byteIndex = ledButtonMap[label]![0];
      final bitIndex = ledButtonMap[label]![1];

      if (buttonStates[label] == true) {
        ledBytes[byteIndex] |= (1 << bitIndex);
      } else {
        ledBytes[byteIndex] &= ~(1 << bitIndex);
      }

      List<int> keyStateMessage = [
        ledBytes[0],
        0x00,
        0x00,
        0x00,
        _nextTickByte(), // Use the updated tick generator
        0x00,
        0x00,
        0x00
      ];

      _sendLEDFrame(); // Send over Bluetooth

      formattedData = keyStateMessage
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ')
          .toUpperCase();

      canId = '00000195';
      buttonExplanation =
          buttonStates[label] == true ? '$label pressed' : '$label released';
    } else if (buttonBitMap.containsKey(label)) {
      // For 2x6 functional PKP2600
      formattedData = dataBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ')
          .toUpperCase();

      canId = '000001A5';
      buttonExplanation =
          buttonStates[label] == true ? '$label pressed' : '$label released';
    } else {
      // Fallback
      formattedData = List.filled(8, 0)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ')
          .toUpperCase();

      canId = '00000000';
      buttonExplanation = 'Key #$label toggled';
    }

    final entry = CanLogEntry(
      channel: 'CH0',
      canId: canId,
      dlc: '8',
      data: formattedData,
      dir: 'TX',
      time: (_stopwatch.elapsed.inMilliseconds / 1000).toStringAsFixed(2),
      button: buttonExplanation,
    );

    // Log to Fixed Feed as well
    final frameKey = '$formattedData|$buttonExplanation';
    fixedCanHistoryMap[frameKey] = [
      'CH0',
      canId,
      '8',
      formattedData,
      (_stopwatch.elapsed.inMilliseconds / 1000).toStringAsFixed(2),
      'TX',
      buttonExplanation,
    ];

    setState(() {
      sharedCanLog.add(entry);
      canLogUpdated.value = DateTime.now();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_autoScrollEnabled &&
          _logScrollController.hasClients &&
          _logScrollController.offset >=
              _logScrollController.position.maxScrollExtent - 100) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Clears the entire CAN log and resets the stopwatch
  void _clearLog() {
    setState(() {
      sharedCanLog.clear();
      _stopwatch.reset();
      if (!_isTimerRunning) {
        _stopwatch.stop();
      }
    });
  }

  // Resets only the timer (does not clear log or button states)
  void _resetTimerOnly() {
    setState(() {
      _stopwatch.reset();
      if (_isTimerRunning) {
        _stopwatch.start();
      } else {
        _stopwatch.stop();
      }
    });
  }

  //Returns styled buttons with tool tios and icons and assignes icons based on button logic
  Widget buildButton(String label) {
    IconData? icon;
    String tooltip = '';
    String stateSuffix = buttonStates[label] == true ? 'ON' : 'OFF';
    switch (label) {
      // 2x2 PKP2200 Keys
      case 'K1':
        icon = Icons.power; // ON
        tooltip = 'Power On';
        break;
      case 'K2':
        icon = Icons.power_off; // OFF
        tooltip = 'Power Off ';
        break;
      case 'K3':
        icon = Icons.warning_amber_rounded; // Emergency Stop
        tooltip = 'Emergency Stop ';
        break;
      case 'K4':
        icon = Icons.settings_backup_restore; // Reset
        tooltip = 'System Reset ';
        break;

      //2x6 PKP2600 Functions
      case 'F1':
        icon = Icons.water_drop;
        tooltip = 'Water Pump On';
        break;
      case 'F2':
        icon = Icons.water_drop_outlined;
        tooltip = 'Water Pump Off';
        break;
      case 'F3':
        icon = CupertinoIcons.gear_solid;
        tooltip = 'Engine On';
        break;
      case 'F4':
        icon = CupertinoIcons.gear_big;
        tooltip = 'Engine Off';
        break;
      case 'F5':
        icon = Icons.vertical_align_top;
        tooltip = 'Boom Up';
        break;
      case 'F6':
        icon = Icons.vertical_align_bottom;
        tooltip = 'Boom Down';
        break;
      case 'F7':
        icon = Icons.lock_open;
        tooltip = 'Door Unlock';
        break;
      case 'F8':
        icon = Icons.lock;
        tooltip = 'Door Lock';
        break;
      case 'F9':
        icon = Icons.sensors; // Vacuum On
        tooltip = 'Vacuum On';
        break;
      case 'F10':
        icon = Icons.sensors_off; // Vacuum Off
        tooltip = 'Vacuum Off';
        break;
      case 'F11':
        icon = Icons.arrow_circle_up;
        tooltip = 'Tank Raise / Dozer Out';
        break;
      case 'F12':
        icon = Icons.arrow_circle_down;
        tooltip = 'Tank Lower / Dozer In';
        break;

      // Fallback
      default:
        icon = Icons.help_outline;
        tooltip = 'Unlabeled Button';
    }

    return Tooltip(
      message: tooltip,
      child: ElevatedButton.icon(
        onPressed: () => _handleButtonPress(label),
        icon: Icon(
          icon ?? Icons.help_outline,
          size: 24,
          color: Colors.tealAccent,
        ),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonStates[label] == true
              ? Colors.green.shade700
              : Colors.grey.shade800,
          elevation: 4,
          shadowColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        ).copyWith(
          overlayColor: MaterialStateProperty.all(Colors.teal.withOpacity(0.1)),
        ),
      ),
    );
  }

  // scrollable table of all the CAN frame logs
  Widget buildCanLogTable() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            border: const Border(bottom: BorderSide(color: Colors.white24)),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(Icons.device_hub, size: 14, color: Colors.tealAccent),
                    SizedBox(width: 4),
                    Text('CH', style: _headerStyle),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(Icons.code, size: 14, color: Colors.tealAccent),
                    SizedBox(width: 4),
                    Text('CAN ID', style: _headerStyle),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number,
                      size: 14,
                      color: Colors.tealAccent,
                    ),
                    SizedBox(width: 4),
                    Text('DLC', style: _headerStyle),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(Icons.memory, size: 14, color: Colors.tealAccent),
                    SizedBox(width: 4),
                    Text('Data', style: _headerStyle),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(
                      Icons.compare_arrows,
                      size: 14,
                      color: Colors.tealAccent,
                    ),
                    SizedBox(width: 4),
                    Text('Dir', style: _headerStyle),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.tealAccent),
                    SizedBox(width: 4),
                    Text('Time', style: _headerStyle),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      size: 14,
                      color: Colors.tealAccent,
                    ),
                    SizedBox(width: 4),
                    Text('Button', style: _headerStyle),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 4),

        // Scrollable log area
        Expanded(
          child: ListView.builder(
            controller: _logScrollController,
            itemCount: logToDisplay.length,
            itemBuilder: (context, index) {
              final f = logToDisplay[index];
              final isLatest = index == logToDisplay.length - 1;

              final isEven = index % 2 == 0;
              return Container(
                color: isLatest
                    ? Colors.teal.withOpacity(0.2)
                    : (isEven ? Colors.black : Colors.grey.shade900),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Text(f.channel, style: _rowStyle)),
                    Expanded(flex: 2, child: Text(f.canId, style: _rowStyle)),
                    Expanded(flex: 1, child: Text(f.dlc, style: _rowStyle)),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(f.data, style: _rowStyle),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        children: [
                          Icon(
                            f.dir == 'TX' ? Icons.upload : Icons.download,
                            size: 12,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 4),
                          Text(f.dir, style: _rowStyle),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: Text(f.time, style: _rowStyle)),
                    Expanded(
                      flex: 2,
                      child: Text(
                        f.button,
                        style: _rowStyle.copyWith(
                          color: f.button.contains('No')
                              ? Colors.redAccent
                              : Colors.greenAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  //Displays BT status and number of frames at the bottom
  Widget buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth, color: Colors.tealAccent),
          const SizedBox(width: 6),
          Text(
            connectedDeviceName,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.list_alt, color: Colors.tealAccent, size: 16),
              const SizedBox(width: 4),
              Text(
                'Frames: ${sharedCanLog.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.timer, color: Colors.tealAccent, size: 16),
              const SizedBox(width: 4),
              Text(
                _elapsedFormatted,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _isTimerRunning ? Colors.greenAccent : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow: _isTimerRunning
                      ? [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<CanLogEntry> get logToDisplay {
    if (_showFixedFeed) {
      return fixedCanHistoryMap.values
          .map((f) => CanLogEntry(
                channel: f[0],
                canId: f[1],
                dlc: f[2],
                data: f[3],
                time: f[4],
                dir: f[5],
                button: f[6],
              ))
          .toList();
    } else {
      return sharedCanLog;
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('BM Keypad Interface'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade800,
        elevation: 2,
        actions: [
          const SizedBox(width: 0),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bluetooth,
                          color: Colors.tealAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Bluetooth Device Scanner',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                            shadows: [
                              Shadow(
                                blurRadius: 3,
                                color: Colors.black45,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: scanControl(),
                  ),
                  //Device stat. display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: 'Connected to: $connectedDeviceName',
                        preferBelow: false,
                        waitDuration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.bluetooth_connected,
                          size: 28,
                          color: connectedDeviceName == 'Not connected'
                              ? Colors.grey
                              : Colors.tealAccent,
                        ),
                      ),
                      //Text feild to filter scanned devices by name
                      const SizedBox(width: 8),
                      Text(
                        connectedDeviceName,
                        style: TextStyle(
                          color: connectedDeviceName == 'Not connected'
                              ? Colors.grey
                              : Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  // Filter Field
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    child: TextField(
                      controller: _deviceFilterController,
                      decoration: InputDecoration(
                        hintText: 'Filter by device name...',
                        prefixIcon: const Icon(Icons.filter_alt),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.tealAccent,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _deviceNameFilter = value.trim().toLowerCase();
                        });
                      },
                    ),
                  ),

                  // Device List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: bluetoothDeviceList(),
                  ),
                  buildControlHeader(),
                  // Keypad Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Card(
                      elevation: 6,
                      color: Colors.grey.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 2x2 Keypad Section
                              Text(
                                '2x2 Keypad (PKP2200 - Node ID: 25h)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pressed: ${getPressed2x2Buttons()}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: build2x2Keypad(),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _clear2x2Buttons,
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear 2x2'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade800,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 12),

                              // 2x6 Keypad Section
                              Text(
                                '2x6 Keypad (PKP2600 - Node ID: 15h)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pressed: ${getPressed2x6Buttons()}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: build2x6Keypad(),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _clear2x6Buttons,
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Clear 2x6'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // CAN Frame Log Title
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.dns,
                                color: Colors.tealAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'CAN Frame Log',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                      color: Colors.tealAccent,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),

                  // Toggle buttons for switching feed mode
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _showFixedFeed = false),
                          child: Text(
                            'Live Feed',
                            style: TextStyle(
                              fontWeight: !_showFixedFeed
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: !_showFixedFeed
                                  ? Colors.greenAccent
                                  : Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () =>
                              setState(() => _showFixedFeed = true),
                          child: Text(
                            'Fixed Feed',
                            style: TextStyle(
                              fontWeight: _showFixedFeed
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _showFixedFeed
                                  ? Colors.greenAccent
                                  : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Timer + Label this is commented out because we moved where we want the new timer

                  /*
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Colors.tealAccent, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Live: ${_elapsedFormatted}s',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
    */
                  // Log Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        // Row 1
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isTimerRunning = !_isTimerRunning;
                                  if (_isTimerRunning) {
                                    _stopwatch.start();
                                  } else {
                                    _stopwatch.stop();
                                  }
                                });
                              },
                              icon: Icon(_isTimerRunning
                                  ? Icons.pause
                                  : Icons.play_arrow),
                              label: Text(_isTimerRunning
                                  ? 'Pause Timer'
                                  : 'Resume Timer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal.shade800,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (!_autoTestHasRun) {
                                  _autoTestHasRun = true;
                                  _startAutoTest();
                                }
                              },
                              icon: const Icon(Icons.play_circle_fill),
                              label: const Text('Run Auto Test'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _resetTimerOnly,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reset Timer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 2
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _clearLog,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear Log'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _resetAllButtons,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _sendLastRawFrame,
                              icon: const Icon(Icons.send_rounded),
                              label: const Text(
                                'Send to CANKing',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF37474F),
                                foregroundColor: Colors.white,
                                elevation: 6,
                                shadowColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ).copyWith(
                                overlayColor: MaterialStateProperty.all(
                                  const Color.fromARGB(255, 59, 172, 78),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Log Container
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Card(
                      elevation: 4,
                      color: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox(height: 260, child: buildCanLogTable()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Status Bar
          buildStatusBar(),
        ],
      ),
    );
  }

  Widget buildControlHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.key, color: Colors.tealAccent),
          const SizedBox(width: 8),
          const Text(
            'Blink Marine Control Keypads 2x2 & 2x6',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.tealAccent,
              shadows: [
                Shadow(
                  blurRadius: 3,
                  color: Colors.black45,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard, color: Colors.tealAccent),
        ],
      ),
    );
  }

//NEW BITMAP
  void _sendFunctionFrame() {
    if (CanBluetooth.instance.connectedDevices.isNotEmpty) {
      CanBluetooth.instance.sendCANMessage(
        CanBluetooth.instance.connectedDevices.keys.first,
        BlueMessage(
          identifier: 0x000001A5,
          data: dataBytes,
          flagged: true,
        ),
      );
    }
  }

  void _sendLEDFrame() {
    if (CanBluetooth.instance.connectedDevices.isEmpty) return;

    final deviceId = CanBluetooth.instance.connectedDevices.keys.first;

    final ledFrameData = [
      ledBytes[0], // Byte 0: bits for K1–K4
      0x00, // Byte 1 (not used)
      0x00, // Byte 2 (not used)
      0x00, // Byte 3 (not used)
      _nextTickByte(), // Byte 4 = tick timer
      0x00,
      0x00,
      0x00
    ];

    // Send actual CAN frame
    CanBluetooth.instance.sendCANMessage(
      deviceId,
      BlueMessage(
        identifier: 0x00000195,
        data: ledFrameData,
        flagged: true,
      ),
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  color: Colors.white,
  fontWeight: FontWeight.bold,
  fontFamily: 'Courier',
  fontSize: 13,
);

const TextStyle _rowStyle = TextStyle(
  color: Colors.greenAccent,
  fontFamily: 'Courier',
  fontSize: 12.5,
);
