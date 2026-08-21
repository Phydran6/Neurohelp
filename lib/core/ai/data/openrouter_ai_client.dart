import '../../logging/app_logger.dart';
import '../ai_client.dart';
import '../ai_prompts.dart';
import '../openrouter/openrouter_account.dart';
import '../openrouter/openrouter_api.dart';
import '../openrouter/openrouter_exception.dart';
import '../openrouter/openrouter_model.dart';
import '../openrouter/openrouter_model_choice.dart';

/// Die KI über den nutzereigenen OpenRouter-Zugang (Konzept, Abschnitt 17a,
/// Stufen 2 und 3).
///
/// Diese Anfragen gehen **direkt vom Gerät** raus. Das ist kein Bruch der
/// Proxy-Regel, sondern ihre andere Hälfte: Der Proxy schützt die eigene
/// Infrastruktur. Bei fremdem Zugang gäbe es nichts zu schützen – er wäre
/// nur eine weitere Station, auf der fremde Daten landen.
class OpenRouterAiClient implements AiClient {
  OpenRouterAiClient({
    required OpenRouterAccount account,
    required OpenRouterApi api,
    required bool enabled,
    DateTime Function()? clock,
  }) : _account = account,
       _api = api,
       _enabled = enabled,
       _now = clock ?? DateTime.now;

  final OpenRouterAccount _account;
  final OpenRouterApi _api;
  final DateTime Function() _now;

  bool _enabled;

  List<OpenRouterModel> _candidates = const [];
  DateTime? _fetchedAt;

  /// Wie lange das Modellverzeichnis gilt.
  ///
  /// Es rotiert, aber nicht im Minutentakt. Bei jeder Anfrage neu zu laden
  /// wäre ein zweiter Netzaufruf für nichts.
  static const Duration _catalogTtl = Duration(hours: 6);

  @override
  bool get isEnabled => _enabled && _account.isUsable;

  @override
  void setEnabled({required bool enabled}) => _enabled = enabled;

  @override
  Future<void> probe() async {
    await run(
      AiTask.answerHelp,
      input: 'Verbindungstest. Antworte mit einem kurzen Satz.',
    );
  }

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async {
    if (!_enabled) {
      throw const AiUnavailableException('KI ist in den Einstellungen aus.');
    }

    final key = _account.key;
    if (key == null || _account.needsReconnect) {
      throw const AiUnavailableException('Kein eigener KI-Zugang verbunden.');
    }

    final system = AiPrompts.systemFor(task, tone);

    try {
      return await _tryCandidates(
        key: key.value,
        system: system,
        input: input,
        task: task,
      );
    } on OpenRouterException catch (error) {
      if (error.failure == OpenRouterFailure.unauthorized) {
        _account.markRejected();
      }
      throw AiUnavailableException(error.reason);
    }
  }

  /// Geht die Kandidaten der Reihe nach durch.
  ///
  /// Ein Modell kann am Ratenlimit hängen oder über Nacht verschwunden sein.
  /// Das ist der Normalfall bei kostenlosen Modellen, kein Ausnahmefall –
  /// deshalb wird still das nächste genommen.
  Future<String> _tryCandidates({
    required String key,
    required String system,
    required String input,
    required AiTask task,
  }) async {
    var models = await _models();

    if (models.isEmpty) {
      // Kann am veralteten Zwischenspeicher liegen: einmal frisch holen.
      _fetchedAt = null;
      models = await _models();
    }

    if (models.isEmpty) {
      throw const OpenRouterException(
        OpenRouterFailure.modelUnavailable,
        'Gerade ist kein passendes Modell verfügbar.',
      );
    }

    OpenRouterException? last;

    for (final model in models) {
      try {
        return await _api.complete(
          key: key,
          model: model.id,
          system: system,
          input: input,
        );
      } on OpenRouterException catch (error) {
        AppLogger.info(
          '${model.id} hat nicht geantwortet (${error.failure.name})',
          scope: 'openrouter',
        );

        // Abgelaufener Zugang oder kein Netz: Ein anderes Modell ändert
        // daran nichts.
        if (!error.worthAnotherModel) rethrow;

        last = error;

        // Ist das Modell weg, ist auch das Verzeichnis veraltet.
        if (error.failure == OpenRouterFailure.modelUnavailable) {
          _fetchedAt = null;
        }
      }
    }

    AppLogger.warning(
      'Kein Modell hat ${task.wireName} beantwortet',
      scope: 'openrouter',
    );
    throw last ??
        const OpenRouterException(
          OpenRouterFailure.modelUnavailable,
          'Gerade ist kein passendes Modell verfügbar.',
        );
  }

  Future<List<OpenRouterModel>> _models() async {
    final fetchedAt = _fetchedAt;
    if (fetchedAt != null && _now().difference(fetchedAt) < _catalogTtl) {
      return _candidates;
    }

    final all = await _api.listModels();
    _candidates = OpenRouterModelChoice.rank(
      all,
      allowPaid: _account.hasCredit,
    );
    _fetchedAt = _now();

    AppLogger.info(
      'Modellauswahl: ${_candidates.map((m) => m.id).join(', ')}',
      scope: 'openrouter',
    );
    return _candidates;
  }
}
