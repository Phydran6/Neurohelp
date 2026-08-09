import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/features/help/domain/about_info.dart';
import 'package:neurohelp/features/help/domain/faq.dart';
import 'package:neurohelp/features/help/domain/help_service.dart';

/// KI, die eine feste Antwort liefert und mitzählt, wie oft sie dran war.
class _FakeAi implements AiClient {
  _FakeAi({this.enabled = true, this.answer = 'Antwort der KI.'});

  final bool enabled;
  final String answer;
  int calls = 0;
  AiTask? lastTask;

  @override
  bool get isEnabled => enabled;

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async {
    calls++;
    lastTask = task;
    return answer;
  }
}

/// KI, die nicht erreichbar ist.
class _UnreachableAi implements AiClient {
  @override
  bool get isEnabled => true;

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async => throw const AiUnavailableException('kein Netz');
}

void main() {
  group('FAQ-Katalog', () {
    test('trägt auch ohne KI', () {
      expect(FaqCatalog.entries, isNotEmpty);
      for (final entry in FaqCatalog.entries) {
        expect(entry.question, isNotEmpty, reason: entry.id);
        expect(entry.answer, isNotEmpty, reason: entry.id);
      }
    });

    test('findet über Frage, Antwort und Schlagwörter', () {
      expect(FaqCatalog.search('Datenschutz'), isNotEmpty);
      expect(FaqCatalog.search('fingerabdruck'), isNotEmpty);
      expect(FaqCatalog.search('iphone'), isNotEmpty);
      expect(FaqCatalog.search('Quantenphysik'), isEmpty);
    });

    test('leere Eingabe zeigt alles', () {
      expect(FaqCatalog.search('   '), hasLength(FaqCatalog.entries.length));
    });

    test('hat eindeutige Kennungen', () {
      final ids = FaqCatalog.entries.map((e) => e.id).toSet();
      expect(ids, hasLength(FaqCatalog.entries.length));
    });
  });

  group('Fragen beantworten', () {
    test('der Katalog kommt vor der KI', () async {
      final ai = _FakeAi();
      final help = HelpService(ai);

      final answer = await help.ask('Wo liegen meine Daten?');

      expect(answer.source, HelpSource.catalog);
      expect(answer.entries, isNotEmpty);
      // Keine unnötige Anfrage nach draußen.
      expect(ai.calls, 0);
    });

    test('ohne Treffer fragt die KI – aber nur wenn sie an ist', () async {
      final ai = _FakeAi();
      final help = HelpService(ai);

      final answer = await help.ask('Kann ich Neurohelp auf Suaheli nutzen?');

      expect(answer.source, HelpSource.ai);
      expect(answer.text, 'Antwort der KI.');
      expect(ai.lastTask, AiTask.answerHelp);
    });

    test('mit abgeschalteter KI bleibt es beim ruhigen Hinweis', () async {
      final help = HelpService(_FakeAi(enabled: false));

      final answer = await help.ask('Kann ich Neurohelp auf Suaheli nutzen?');

      expect(answer.source, HelpSource.none);
      expect(answer.text, contains('KI einschaltest'));
    });

    test('nicht erreichbare KI ist kein Fehler des Users', () async {
      final help = HelpService(_UnreachableAi());

      final answer = await help.ask('Etwas völlig Abwegiges');

      expect(answer.source, HelpSource.none);
      expect(answer.text, isNot(contains('Fehler')));
    });

    test('der KI-lose Weg beantwortet die Kernfragen', () async {
      final help = HelpService(_FakeAi(enabled: false));

      for (final frage in ['Daten', 'PIN', 'KI', 'Mail']) {
        final answer = await help.ask(frage);
        expect(answer.source, HelpSource.catalog, reason: frage);
      }
    });
  });

  group('Über die App', () {
    test('nennt Herkunft, Entwickler, Lizenz und Version', () {
      const info = AboutInfo(version: '0.1.0', buildNumber: '42');

      expect(AboutInfo.appName, 'Neurohelp');
      expect(AboutInfo.developer, isNotEmpty);
      expect(AboutInfo.license, 'MIT');
      expect(AboutInfo.origin, isNotEmpty);
      expect(AboutInfo.thirdParty, isNotEmpty);
      expect(info.versionLabel, '0.1.0 (42)');
    });

    test('der Datenhinweis steht sichtbar im Info-Bereich', () {
      expect(AboutInfo.dataNotice, contains('auf deinem Gerät'));
    });
  });
}
