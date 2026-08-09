import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logging/app_logger.dart';
import '../ai_client.dart';

/// Der KI-Zugang der App – ausschließlich über die Backend-Funktion
/// `ai-proxy` (Konzept, Abschnitt 17).
///
/// Hier steht bewusst kein Anbieter, kein Modell und kein Prompt. Die App
/// schickt einen Aufgabentyp und bekommt Text zurück. Ein Anbieterwechsel
/// passiert im Backend, nicht hier.
class SupabaseAiClient implements AiClient {
  const SupabaseAiClient(this._client, {required bool enabled})
    : _enabled = enabled;

  final SupabaseClient _client;
  final bool _enabled;

  static const String _functionName = 'ai-proxy';

  @override
  bool get isEnabled => _enabled;

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async {
    if (!_enabled) {
      throw const AiUnavailableException('KI ist in den Einstellungen aus.');
    }

    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: {'task': task.wireName, 'input': input, 'tone': tone.name},
      );

      final data = response.data;
      if (data is! Map) {
        throw const AiUnavailableException('Unerwartete Antwort vom Backend.');
      }

      final text = data['text'];
      if (text is! String || text.trim().isEmpty) {
        throw const AiUnavailableException('Die Antwort war leer.');
      }

      return text.trim();
    } on FunctionException catch (error, stackTrace) {
      AppLogger.error(
        'KI-Aufruf fehlgeschlagen (${task.wireName})',
        scope: 'ai',
        error: error,
        stackTrace: stackTrace,
      );

      // 401 heißt: nicht angemeldet. Alles andere ist eine Störung.
      throw AiUnavailableException(
        error.status == 401
            ? 'Dafür musst du angemeldet sein.'
            : 'Die KI ist gerade nicht erreichbar.',
      );
    } on Exception catch (error, stackTrace) {
      AppLogger.error(
        'KI-Aufruf fehlgeschlagen (${task.wireName})',
        scope: 'ai',
        error: error,
        stackTrace: stackTrace,
      );
      throw const AiUnavailableException('Die KI ist gerade nicht erreichbar.');
    }
  }
}
