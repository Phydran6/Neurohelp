import 'package:flutter/widgets.dart';

import '../../features/calls/data/sqlite_call_repository.dart';
import '../../features/calls/domain/call_launcher.dart';
import '../../features/help/domain/help_service.dart';
import '../../features/messages/data/sqlite_message_repository.dart';
import '../../features/messages/domain/message_sender.dart';
import '../../features/tasks/data/sqlite_task_repository.dart';
import '../../features/tasks/domain/task_repository.dart';
import '../ai/ai_client.dart';
import '../db/app_database.dart';
import '../history/data/sqlite_history_repository.dart';
import '../history/domain/history_repository.dart';
import '../settings/data/sqlite_settings_repository.dart';
import '../settings/settings_repository.dart';

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
    required this.calls,
    required this.dialer,
    required this.ai,
    required this.help,
  });

  /// Baut die Dienste über einer geöffneten Datenbank auf.
  factory AppServices.from(
    AppDatabase database, {
    AiClient? ai,
    MessageSender sender = const NoMessageSender(),
    CallLauncher dialer = const NoCallLauncher(),
  }) {
    final history = SqliteHistoryRepository(database.raw);
    final aiClient = ai ?? const DisabledAiClient();

    return AppServices(
      help: HelpService(aiClient),
      database: database,
      history: history,
      settings: SqliteSettingsRepository(database.raw),
      tasks: SqliteTaskRepository(database.raw, history),
      messages: SqliteMessageRepository(database.raw, history),
      sender: sender,
      calls: SqliteCallRepository(database.raw, history),
      dialer: dialer,
      // Ohne KI-Anbindung läuft die App vollständig lokal. Der echte
      // Client kommt, sobald das Onboarding den Toggle setzt.
      ai: aiClient,
    );
  }

  final AppDatabase database;
  final HistoryRepository history;
  final SettingsRepository settings;
  final TaskRepository tasks;
  final SqliteMessageRepository messages;

  /// Übergabe an die System-App. In Tests bewusst wirkungslos.
  final MessageSender sender;

  final SqliteCallRepository calls;

  /// Startet das Telefonat. In Tests bewusst wirkungslos.
  final CallLauncher dialer;

  final AiClient ai;

  /// Fragen im Hilfe-Bereich – Katalog zuerst, KI nur wenn nötig.
  final HelpService help;

  Future<void> dispose() => database.close();
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
