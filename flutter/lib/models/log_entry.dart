import 'package:flutter/material.dart';

enum LogType { info, success, error, data, send }

/// Represents an item in the BLE console log
class LogEntry {
  final String message;
  final LogType type;
  final String time;

  LogEntry({
    required this.message,
    required this.type,
    required this.time,
  });

  Color get color {
    switch (type) {
      case LogType.info:
        return const Color(0xFF88AADD);
      case LogType.success:
        return const Color(0xFF00E676);
      case LogType.error:
        return const Color(0xFFFF5252);
      case LogType.data:
        return const Color(0xFFFFAB40);
      case LogType.send:
        return const Color(0xFFCE93D8);
    }
  }
}
