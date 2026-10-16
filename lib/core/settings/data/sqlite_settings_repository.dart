import 'package:sqflite/sqflite.dart';

import '../../ai/ai_client.dart';
import '../../companion/companion_style.dart';
import '../../db/schema.dart';
import '../app_settings.dart';
import '../settings_repository.dart';

/// Einstellungen im lokalen Schlüssel/Wert-Speicher.
class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

  static const _keyOnboardingCompleted = 'onboarding_completed';
  static const _keyAiEnabled = 'ai_enabled';
  static const _keyTone = 'tone';
  static const _keyLockMethod = 'lock_method';
  static const _keyCompanionStyle = 'companion_style';
  static const _keyMfaHintShown = 'mfa_hint_shown';
  static const _keyThemeChoice = 'theme_choice';
  static const _keySettingsMode = 'settings_mode';
  static const _keyAutoBackup = 'auto_backup';
  static const _keyLastBackupAt = 'last_backup_at';
  static const _keyRestoreOffered = 'restore_offered';

  @override
  Future<AppSettings> load() async {
    final rows = await _db.query(DbSchema.tableSettings);
    final values = {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };

    const defaults = AppSettings();

    return AppSettings(
      onboardingCompleted:
          _readBool(values[_keyOnboardingCompleted]) ??
          defaults.onboardingCompleted,
      aiEnabled: _readBool(values[_keyAiEnabled]) ?? defaults.aiEnabled,
      tone: _readEnum(AiTone.values, values[_keyTone]) ?? defaults.tone,
      lockMethod:
          _readEnum(LockMethod.values, values[_keyLockMethod]) ??
          defaults.lockMethod,
      companionStyle:
          _readEnum(CompanionStyle.values, values[_keyCompanionStyle]) ??
          defaults.companionStyle,
      mfaHintShown:
          _readBool(values[_keyMfaHintShown]) ?? defaults.mfaHintShown,
      themeChoice:
          _readEnum(AppThemeChoice.values, values[_keyThemeChoice]) ??
          defaults.themeChoice,
      settingsMode:
          _readEnum(SettingsMode.values, values[_keySettingsMode]) ??
          defaults.settingsMode,
      autoBackup: _readBool(values[_keyAutoBackup]) ?? defaults.autoBackup,
      lastBackupAt: _readDate(values[_keyLastBackupAt]),
      restoreOffered:
          _readBool(values[_keyRestoreOffered]) ?? defaults.restoreOffered,
    );
  }

  @override
  Future<AppSettings> setOnboardingCompleted({required bool completed}) =>
      _write(_keyOnboardingCompleted, completed ? '1' : '0');

  @override
  Future<AppSettings> setAiEnabled({required bool enabled}) =>
      _write(_keyAiEnabled, enabled ? '1' : '0');

  @override
  Future<AppSettings> setTone(AiTone tone) => _write(_keyTone, tone.name);

  @override
  Future<AppSettings> setLockMethod(LockMethod method) =>
      _write(_keyLockMethod, method.name);

  @override
  Future<AppSettings> setCompanionStyle(CompanionStyle style) =>
      _write(_keyCompanionStyle, style.name);

  @override
  Future<AppSettings> setMfaHintShown({required bool shown}) =>
      _write(_keyMfaHintShown, shown ? '1' : '0');

  @override
  Future<AppSettings> setThemeChoice(AppThemeChoice choice) =>
      _write(_keyThemeChoice, choice.name);

  @override
  Future<AppSettings> setSettingsMode(SettingsMode mode) =>
      _write(_keySettingsMode, mode.name);

  @override
  Future<AppSettings> setAutoBackup({required bool enabled}) =>
      _write(_keyAutoBackup, enabled ? '1' : '0');

  @override
  Future<AppSettings> setLastBackupAt(DateTime moment) =>
      _write(_keyLastBackupAt, moment.millisecondsSinceEpoch.toString());

  @override
  Future<AppSettings> setRestoreOffered({required bool offered}) =>
      _write(_keyRestoreOffered, offered ? '1' : '0');

  Future<AppSettings> _write(String key, String value) async {
    await _db.insert(DbSchema.tableSettings, {
      'key': key,
      'value': value,
      'updated_at': _now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return load();
  }

  static bool? _readBool(String? raw) => raw == null ? null : raw == '1';

  /// Ein unlesbarer Zeitstempel ist kein Grund, die Einstellungen
  /// hinzuwerfen – er kann aus einer eingespielten Sicherung stammen.
  static DateTime? _readDate(String? raw) {
    if (raw == null) return null;
    final millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static T? _readEnum<T extends Enum>(List<T> values, String? raw) {
    if (raw == null) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
