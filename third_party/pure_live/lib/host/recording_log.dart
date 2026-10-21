import 'dart:developer' as developer;

/// Android/app log bridge for the vendored recording implementation.
/// It deliberately keeps recorder diagnostics out of Pure Live's unrelated
/// app-wide log server/settings graph.
abstract final class Log {
  static void d(String message) => developer.log(message, name: 'PureLive.Recorder', level: 500);
  static void i(String message) => developer.log(message, name: 'PureLive.Recorder', level: 800);
  static void w(String message) => developer.log(message, name: 'PureLive.Recorder', level: 900);
  static void e(String message, StackTrace stackTrace) =>
      developer.log(message, name: 'PureLive.Recorder', level: 1000, stackTrace: stackTrace);
  static void logPrint(String message) => developer.log(message, name: 'PureLive.Recorder', level: 1000);
  static void error(String message, [StackTrace? stackTrace]) =>
      developer.log(message, name: 'PureLive.Recorder', level: 1000, stackTrace: stackTrace);
}
