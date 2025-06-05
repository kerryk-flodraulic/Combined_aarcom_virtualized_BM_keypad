import 'package:flutter/material.dart';
import 'bluetooth.dart';
import 'can_log_entry.dart'; // if you split CanLogEntry into its own file

// Shared CAN frame log (used by both UIs)
final List<CanLogEntry> sharedCanLog = [];

// Shared ValueNotifier to trigger rebuilds when log updates
final ValueNotifier<DateTime> canLogUpdated = ValueNotifier(DateTime.now());
