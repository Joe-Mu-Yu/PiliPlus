import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Keeps recording-owned files under the PiliPlus app-support directory.
class AppPathManager {
  AppPathManager._();
  static final AppPathManager _instance = AppPathManager._();
  factory AppPathManager() => _instance;

  static const String dirRecords = 'RECORDS';

  Future<Directory> getDir(String segment) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'pure_live', segment));
    await directory.create(recursive: true);
    return directory;
  }
}
