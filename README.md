
---
# Combined CAN Keypad Interface (BM Keypad + AARCOMM RCU)

This Flutter application combines two independent virtual control systems into a unified testing platform:

- BM Keypad Interface simulating PKP2200 (2x2) and PKP2600 (2x6) keypads.
- AARCOMM Virtualized RCU simulating digital hydrovac vehicle controls including Engine, Boom, Water Pump, Door, Wand, and others.

The app enables structured CAN message generation and transmission over Bluetooth Low Energy (BLE), allowing communication with embedded systems and live CAN log visualization for testing and validation.

---

## Features

- Dual simulation: BM Keypad (2x2 + 2x6) and AARCOMM RCU
- Shared Bluetooth scanner and connection status
- Real-time CAN frame generation using 8-byte structured payloads
- Full CAN log display with button name, ID, data, DLC, direction, and elapsed time
- LED control simulation via PKP2200 mapped CAN frames
- Auto test functionality to simulate all keypad inputs
- Stopwatch timer synced with CAN log timestamps
- Responsive layout with centralized controls and log visibility

---

## Interface Overview

| Section           | Description                                              |
|-------------------|----------------------------------------------------------|
| Left Panel        | AARCOMM RCU (grouped digital control buttons)            |
| Right Panel       | BM Keypad with 2x2 and 2x6 button layouts                |
| Top               | Shared Bluetooth scan and device list                    |
| Bottom            | Shared CAN status bar with connected device, timer, log  |

---

## Required Packages

- `flutter_blue_plus`
- `permission_handler`
- `cupertino_icons`


---

## Hardware Integration

This application is compatible with:

- Puisi MCBox (CAN-over-Bluetooth device)
- Axiomatic CAN-to-Bluetooth Converters
- Kvaser CANKing (for monitoring live CAN traffic)
- Peak PCAN-View (alternative CAN visualization tool)

---

## CAN Frame Format

| Field     | Description                               |
|-----------|-------------------------------------------|
| CAN ID    | 8-character hex string (e.g., 00000180)    |
| DLC       | Fixed to 8                                 |
| Data      | 8-byte hex payload (e.g., `00 00 00 ...`)  |
| Direction | 'TX' for transmitted CAN messages          |
| Time      | Elapsed time in seconds from test start    |
| Button    | Descriptive name of the pressed button     |

---

## CAN ID Mapping

| Source Component    | CAN ID     |
|---------------------|------------|
| BM Keypad 2x2       | 00000180   |
| BM Keypad 2x6       | 00000215   |
| AARCOMM RCU Control | 18FF1410   |

---

## Running the Application

1. Clone the repository and ensure Flutter is set up.
2. Install dependencies:
     -flutter_blue_plus: ^1.32.4
     -permission_handler: ^11.3.0
     -share_plus: ^11.0.0

```

flutter pub get

```

3. Connect your CAN Bluetooth (Puisi Box and Axiomatic) device and run:

```

flutter run

```



---

## Auto Test Mode

Click the 'Run Auto Test' button to simulate all button presses across both keypads and log all CAN messages automatically. Each test is logged with its elapsed timestamp and associated CAN ID.

---

## File Structure

- `main.dart`: Combined app UI and logic
- `bm_keypad.dart`: BM Keypad (2x2 & 2x6) logic
- `aarcom_rcu.dart`: AARCOMM Virtualized RCU logic
- `bluetooth.dart`: Shared BLE scanning and communication
- `shared_widgets.dart`: Shared Bluetooth controls and status bar
- `can_log_entry.dart`: Data model for CAN logs
- `globals.dart`: Shared state for CAN log list

---

## Notes

- Make sure your hardware is powered and broadcasting before scanning.
- The CAN frame log updates in real time as buttons are pressed.
- The application has been tested against live CAN tools such as CANKing.

```
