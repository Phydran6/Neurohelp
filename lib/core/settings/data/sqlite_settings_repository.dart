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

  Future<AppSettings> _write(String key, String value) async {
    await _db.insert(DbSchema.tableSettings, {
      'key': key,
      'value': value,
      'updated_at': _now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return load();
  }

  static bool? _readBool(String? raw) => raw == null ? null : raw == '1';

  static T? _readEnum<T extends Enum>(List<T> values, String? raw) {
    if (raw == null) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }
}
