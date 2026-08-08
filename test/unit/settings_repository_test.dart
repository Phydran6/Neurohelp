import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/settings/app_settings.dart';
import 'package:neurohelp/core/settings/data/sqlite_settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late SqliteSettingsRepository repository;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = SqliteSettingsRepository(
      database.raw,
      clock: () => DateTime.utc(2026, 8, 8),
    );
  });

  tearDown(() => database.close());

  test('liefert ohne gespeicherte Werte die Standards', () async {
    final settings = await repository.load();

    expect(settings, const AppSettings());
    expect(settings.onboardingCompleted, isFalse);
    expect(settings.aiEnabled, isFalse);
    expect(settings.lockMethod, LockMethod.none);
    expect(settings.isLocked, isFalse);
  });

  test('speichert jede Einstellung einzeln', () async {
    await repository.setAiEnabled(enabled: true);
    await repository.setTone(AiTone.sachlich);
    await repository.setLockMethod(LockMethod.biometric);
    final settings = await repository.setOnboardingCompleted(completed: true);

    expect(settings.aiEnabled, isTrue);
    expect(settings.tone, AiTone.sachlich);
    expect(settings.lockMethod, LockMethod.biometric);
    expect(settings.onboardingCompleted, isTrue);
  });

  test('überschreibt statt zu duplizieren', () async {
    await repository.setTone(AiTone.locker);
    await repository.setTone(AiTone.neutral);

    expect((await repository.load()).tone, AiTone.neutral);
  });

  test('KI lässt sich wieder abschalten', () async {
    await repository.setAiEnabled(enabled: true);
    final settings = await repository.setAiEnabled(enabled: false);

    expect(settings.aiEnabled, isFalse);
  });

  test('überlebt einen Neustart der App', () async {
    await repository.setTone(AiTone.sachlich);
    await repository.setOnboardingCompleted(completed: true);

    // Neues Repository auf derselben Datenbank – wie nach einem App-Start.
    final reopened = SqliteSettingsRepository(database.raw);
    final settings = await reopened.load();

    expect(settings.tone, AiTone.sachlich);
    expect(settings.onboardingCompleted, isTrue);
  });
}
