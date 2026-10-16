import '../ai_client.dart';
import '../ai_prompts.dart';
import '../custom/custom_endpoint_account.dart';

/// Die KI über den selbst eingetragenen Server (Konzept, Abschnitt 17a).
///
/// Steht als **oberste** Stufe über allem anderen: Wer sich die Mühe gemacht
/// hat, seinen eigenen Zugang einzutragen, will auch, dass er benutzt wird.
/// Fällt er aus, geht es still eine Stufe tiefer – wie überall in dieser
/// Schicht.
class CustomEndpointAiClient implements AiClient {
  CustomEndpointAiClient({
    required CustomEndpointAccount account,
    required bool enabled,
  }) : _account = account,
       _enabled = enabled;

  final CustomEndpointAccount _account;
  bool _enabled;

  @override
  bool get isEnabled => _enabled && _account.isConnected;

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

    final endpoint = _account.endpoint;
    if (endpoint == null) {
      throw const AiUnavailableException('Kein eigener KI-Zugang eingetragen.');
    }

    try {
      return await _account.complete(
        endpoint,
        system: AiPrompts.systemFor(task, tone),
        input: input,
      );
    } on CustomEndpointException catch (error) {
      // Den Zugang stehen lassen, auch wenn er abgelehnt wurde: Ein Server im
      // Heimnetz ist unterwegs nun einmal nicht erreichbar. Ihn deswegen
      // wegzuwerfen wäre die schlechtere Überraschung.
      throw AiUnavailableException(error.reason);
    }
  }
}
