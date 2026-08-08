import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Schweregrad einer Log-Ausgabe.
enum LogLevel { debug, info, warning, error }

/// Schmale Log-Schicht. `print` ist im Projekt verboten (siehe
/// analysis_options.yaml), alles läuft über diese Klasse.
///
/// Wichtig: Es werden **keine** Nutzerinhalte geloggt – nur technische
/// Ereignisse. Die Historie der App ist etwas anderes als dieses Log.
abstract final class AppLogger {
  static const String _defaultName = 'neurohelp';

  static void debug(String message, {String? scope}) =>
      _log(LogLevel.debug, message, scope: scope);

  static void info(String message, {String? scope}) =>
      _log(LogLevel.info, message, scope: scope);

  static void warning(String message, {String? scope}) =>
      _log(LogLevel.warning, message, scope: scope);

  static void error(
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(
        LogLevel.error,
        message,
        scope: scope,
        error: error,
        stackTrace: stackTrace,
      );

  static void _log(
    LogLevel level,
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode && level == LogLevel.debug) {
      return;
    }

    developer.log(
      message,
      name: scope == null ? _defaultName : '$_defaultName.$scope',
      level: _severity(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _severity(LogLevel level) => switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      };
}
