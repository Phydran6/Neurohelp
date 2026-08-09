import 'package:flutter/widgets.dart';

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
    required this.ai,
  });

  /// Baut die Dienste über einer geöffneten Datenbank auf.
  factory AppServices.from(AppDatabase database, {AiClient? ai}) {
    final history = SqliteHistoryRepository(database.raw);

    return AppServices(
      database: database,
      history: history,
      settings: SqliteSettingsRepository(database.raw),
      tasks: SqliteTaskRepository(database.raw, history),
      // Ohne KI-Anbindung läuft die App vollständig lokal. Der echte
      // Client kommt, sobald das Onboarding den Toggle setzt.
      ai: ai ?? const DisabledAiClient(),
    );
  }

  final AppDatabase database;
  final HistoryRepository history;
  final SettingsRepository settings;
  final TaskRepository tasks;
  final AiClient ai;

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
