import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth.dart';

Widget scanControl() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ElevatedButton.icon(
        onPressed: () => CanBluetooth.instance.startScan(),
        icon: const Icon(Icons.search),
        label: const Text('Scan Bluetooth Devices'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
      ),
      const SizedBox(width: 12),
      ElevatedButton.icon(
        onPressed: () => CanBluetooth.instance.stopScan(),
        icon: const Icon(Icons.stop),
        label: const Text('Stop Scan'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
      ),
    ],
  );
}

Widget bluetoothDeviceList() {
  return ValueListenableBuilder(
    valueListenable: CanBluetooth.instance.addedDevice,
    builder: (context, _, __) {
      final results = CanBluetooth.instance.scanResults.values.toList();
      return Column(
        children: results.map((scanResult) {
          final device = scanResult.device;
          final name = scanResult.advertisementData.localName.isNotEmpty
              ? scanResult.advertisementData.localName
              : "(Unnamed)";
          final rssi = scanResult.rssi;
          return Card(
            child: ListTile(
              title: Text('$name (${device.remoteId.str})'),
              subtitle: Text('RSSI: $rssi dBm'),
              trailing: ElevatedButton(
                onPressed: () => CanBluetooth.instance.connect(device),
                child: const Text("Connect"),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

Widget buildStatusBar(
  String connectedDevice,
  int logLength,
  String timer,
  bool isRunning,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: Colors.black87,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Connected: $connectedDevice",
          style: const TextStyle(color: Colors.tealAccent),
        ),
        Text(
          "Log Entries: $logLength",
          style: const TextStyle(color: Colors.orangeAccent),
        ),
        Text(
          "Timer: $timer ${isRunning ? '⏱' : '⏸'}",
          style: const TextStyle(color: Colors.lightBlueAccent),
        ),
      ],
    ),
  );
}
