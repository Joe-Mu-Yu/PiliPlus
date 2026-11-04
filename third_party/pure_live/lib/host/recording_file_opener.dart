import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

/// Minimal file/folder opener used by the original recorder controllers.
abstract final class RecordingFileOpener {
  static Future<bool> openFileOrUrl(String pathOrUrl) async {
    final value = pathOrUrl.trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        final result = Platform.isMacOS
            ? await Process.run('open', [value])
            : Platform.isLinux
            ? await Process.run('xdg-open', [value])
            : await Process.start('explorer.exe', [value], mode: ProcessStartMode.detached);
        return result is ProcessResult ? result.exitCode == 0 : true;
      }
      return (await OpenFilex.open(value)).type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}
