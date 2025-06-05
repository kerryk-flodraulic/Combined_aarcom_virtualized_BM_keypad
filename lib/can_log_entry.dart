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