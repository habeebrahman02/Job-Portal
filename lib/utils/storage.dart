// lib/utils/storage.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Storage {
  static const String filename = 'job_report_data.json';

  /// Get app documents directory
  static Future<Directory> _getAppDir() async => await getApplicationDocumentsDirectory();

  /// Full path to JSON file
  static Future<File> _file() async {
    final dir = await _getAppDir();
    return File('${dir.path}/$filename');
  }

  /// Read JSON as Map (returns {} if no file)
  static Future<Map<String, dynamic>> readJson() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      final s = await f.readAsString();
      if (s.trim().isEmpty) return {};
      final m = json.decode(s) as Map<String, dynamic>;
      return m;
    } catch (e) {
      return {};
    }
  }

  /// Save map to JSON file
  static Future<void> writeJson(Map<String, dynamic> map) async {
    final f = await _file();
    await f.writeAsString(json.encode(map), flush: true);
  }
}
