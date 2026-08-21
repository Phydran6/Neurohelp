import '../../logging/app_logger.dart';
import '../ai_client.dart';

/// Die KI-Schicht mit ihren Stufen (Konzept, Abschnitt 17a).
///
/// ```
/// KiDienst
///  ├── OpenRouterKi   → direkt vom Gerät   [wenn verbunden]
///  ├── EigeneKi       → über Supabase      [Standard]
///  └── nichts         → der lokale Weg des Ablaufs
/// ```
///
/// **Merksatz: Fehler fallen weich.** Fällt eine Stufe aus – Ratenlimit,
/// Modell verschwunden, kein Netz zum eigenen Server – geht es stillschweigend
/// eine Stufe tiefer. Der User sieht nie eine technische Fehlermeldung,
/// höchstens, dass es gerade etwas einfacher zugeht.
///
/// Die App kennt dabei weiterhin **keinen Anbieter**, nur „die KI". Welche
/// Stufe geantwortet hat, steht nirgends auf dem Bildschirm.
class LayeredAiClient implements AiClient {
  LayeredAiClient(this._stages, {bool enabled = false}) : _enabled = enabled;

  /// In der Reihenfolge, in der versucht wird. Die beste zuerst.
  final List<AiClient> _stages;

  /// Der KI-Schalter aus dem Onboarding. Er steht über allen Stufen.
  bool _enabled;

  @override
  bool get isEnabled => _enabled && _stages.any((stage) => stage.isEnabled);

  @override
  void setEnabled({required bool enabled}) {
    _enabled = enabled;
    for (final stage in _stages) {
      stage.setEnabled(enabled: enabled);
    }
  }

  @override
  Future<void> probe() => _through((stage) => stage.probe());

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) {
    return _through((stage) => stage.run(task, input: input, tone: tone));
  }

  /// Probiert die Stufen durch und liefert das erste Ergebnis.
  ///
  /// Weitergereicht wird der Grund der **letzten** Stufe: Der ist der
  /// eigentliche Grund, warum es gerade nicht geht. Die Gründe der oberen
  /// Stufen sind Zwischenstationen und stehen im Log.
  Future<T> _through<T>(Future<T> Function(AiClient stage) action) async {
    if (!_enabled) {
      throw const AiUnavailableException('KI ist in den Einstellungen aus.');
    }

    final usable = _stages.where((stage) => stage.isEnabled).toList();

    if (usable.isEmpty) {
      // Der Schalter steht auf an, aber es gibt nichts, was antworten
      // könnte: kein Backend hinterlegt und kein eigener Zugang verbunden.
      // Das ehrlich zu sagen ist besser als ein stummer Schalter.
      throw const AiUnavailableException(
        'Für diese App ist gerade kein KI-Zugang hinterlegt.',
      );
    }

    AiUnavailableException? last;

    for (final stage in usable) {
      try {
        return await action(stage);
      } on AiUnavailableException catch (error) {
        last = error;
        AppLogger.info(
          'Stufe ${stage.runtimeType} übersprungen: ${error.reason}',
          scope: 'ai',
        );
      }
    }

    throw last ??
        const AiUnavailableException('Die KI ist gerade nicht erreichbar.');
  }
}
