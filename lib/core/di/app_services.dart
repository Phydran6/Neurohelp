import 'package:flutter/widgets.dart';

import '../../features/calls/data/sqlite_call_repository.dart';
import '../../features/calls/domain/call_launcher.dart';
import '../../features/appointments/data/sqlite_appointment_repository.dart';
import '../../features/help/domain/help_service.dart';
import '../../features/messages/data/sqlite_message_repository.dart';
import '../../features/messages/domain/message_sender.dart';
import '../files/file_saver.dart';
import '../../features/tasks/data/sqlite_task_repository.dart';
import '../../features/tasks/domain/task_repository.dart';
import '../account/account_repository.dart';
import '../account/data/unconfigured_account_repository.dart';
import '../ai/ai_client.dart';
import '../db/app_database.dart';
import '../db/schema.dart';
import '../history/data/sqlite_history_repository.dart';
import '../security/app_lock.dart';
import '../security/data/device_app_lock.dart';
import '../history/domain/history_repository.dart';
import '../settings/data/sqlite_settings_repository.dart';
import '../settings/settings_controller.dart';

/// Alles, was die Oberfläche braucht, an einer Stelle.
///
/// Bewusst kein Paket für Abhängigkeitsverwaltung: Die App hat wenige,
/// langlebige Dienste. Ein Konstruktor und ein [AppScope] genügen.
class AppServices {
  AppServices({
    required this.database,
    required this.history,
    required this.settings,
    required this.tasks,
    required this.messages,
    required this.sender,
    required this.appointments,
    required this.calls,
    required this.dialer,
    required this.ai,
    required this.help,
    required this.account,
    required this.lock,
    required this.files,
  });

  /// Baut die Dienste über einer geöffneten Datenbank auf.
  factory AppServices.from(
    AppDatabase database, {
    AiClient? ai,
    MessageSender sender = const NoMessageSender(),
    CallLauncher dialer = const NoCallLauncher(),

    /// Nur für Tests: eine feste Uhr statt der echten Zeit.
    DateTime Function()? clock,
    AccountRepository? account,
    AppLock? lock,
    FileSaver files = const NoFileSaver(),
  }) {
    final history = SqliteHistoryRepository(database.raw, clock: clock);
    final aiClient = ai ?? const DisabledAiClient();
    final settings = SettingsController(
      SqliteSettingsRepository(database.raw, clock: clock),
    );

    // Der KI-Schalter muss sofort wirken, nicht erst nach einem Neustart.
    settings.addListener(
      () => aiClient.setEnabled(enabled: settings.current.aiEnabled),
    );

    return AppServices(
      help: HelpService(aiClient),
      database: database,
      history: history,
      settings: settings,
      tasks: SqliteTaskRepository(database.raw, history, clock: clock),
      messages: SqliteMessageRepository(database.raw, history, clock: clock),
      sender: sender,
      appointments: SqliteAppointmentRepository(
        database.raw,
        history,
        clock: clock,
      ),
      calls: SqliteCallRepository(database.raw, history, clock: clock),
      dialer: dialer,
      // Ohne KI-Anbindung läuft die App vollständig lokal. Der echte
      // Client kommt, sobald das Onboarding den Toggle setzt.
      ai: aiClient,
      // Ohne eingerichtetes Backend kann kein Konto angelegt werden - die
      // App sagt das, statt eines vorzutaeuschen.
      account: account ?? const UnconfiguredAccountRepository(),
      lock: lock ?? InMemoryAppLock(),
      files: files,
    );
  }

  final AppDatabase database;
  final HistoryRepository history;

  /// Einstellungen samt aktuellem Stand. Seiten dürfen daran horchen, damit
  /// ein Umstellen von Ton oder KI-Schalter sofort ankommt.
  final SettingsController settings;
  final TaskRepository tasks;
  final SqliteMessageRepository messages;

  /// Übergabe an die System-App. In Tests bewusst wirkungslos.
  final MessageSender sender;

  final SqliteAppointmentRepository appointments;
  final SqliteCallRepository calls;

  /// Startet das Telefonat. In Tests bewusst wirkungslos.
  final CallLauncher dialer;

  final AiClient ai;

  /// Fragen im Hilfe-Bereich – Katalog zuerst, KI nur wenn nötig.
  final HelpService help;

  final AccountRepository account;
  final AppLock lock;

  /// Gibt Dateien aus der App heraus – die Sicherung des Zugangs, den
  /// ICS-Export eines Termins. In Tests bewusst wirkungslos.
  final FileSaver files;

  /// Räumt alles weg, was auf diesem Gerät liegt.
  ///
  /// Gehört zum Löschen des Kontos: Erst räumt das Backend auf, dann das
  /// Gerät. Danach ist die App wie frisch installiert – Historie, Vorgänge,
  /// Einstellungen, PIN und Wiederherstellungs-Codes sind weg, und weil damit
  /// auch das Onboarding wieder offen ist, steht der User nicht mehr in einer
  /// angemeldeten App ohne Konto.
  ///
  /// Was die App nicht selbst geschrieben hat, kann sie auch nicht
  /// zurückholen: Bereits übergebene Mails liegen in der Mail-App, exportierte
  /// Termine im Kalender. Deshalb „so gut es geht", nicht „restlos".
  Future<void> wipeLocalData() async {
    await database.raw.transaction((txn) async {
      for (final table in DbSchema.userTables) {
        await txn.delete(table);
      }
    });

    await lock.clearPin();
    await lock.clearRecoveryCodes();

    // Neu lesen heißt: Standardwerte, und jede horchende Seite erfährt davon.
    await settings.load();
  }

  Future<void> dispose() {
    settings.dispose();
    return database.close();
  }
}

/// Reicht die [AppServices] durch den Widget-Baum.
class AppScope extends InheritedWidget {
  const AppScope({required this.services, required super.child, super.key});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Kein AppScope über diesem Widget.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
