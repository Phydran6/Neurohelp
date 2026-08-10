import 'package:flutter/foundation.dart';

import '../ai/ai_client.dart';
import '../companion/companion_style.dart';
import 'app_settings.dart';
import 'settings_repository.dart';

/// Der aktuelle Stand der Einstellungen, plus Bescheid geben, wenn er sich
/// ändert.
///
/// Anlass: Ton und KI-Schalter wurden zwar gespeichert, aber niemand hat es
/// gemerkt. Die Startseite las ihren Ton einmal beim Bauen, der KI-Client
/// bekam seinen Schalter einmal beim App-Start – eine Änderung in den
/// Einstellungen wirkte erst nach einem Neustart, also gefühlt gar nicht.
///
/// Der Controller ist zugleich [SettingsRepository]: Aufrufer merken nichts
/// vom Zwischenspeicher.
class SettingsController extends ChangeNotifier implements SettingsRepository {
  SettingsController(this._inner);

  final SettingsRepository _inner;

  AppSettings _current = const AppSettings();

  /// Der zuletzt gelesene Stand. Vor dem ersten [load] die Standardwerte.
  AppSettings get current => _current;

  bool _loaded = false;

  /// Ob schon einmal aus der Datenbank gelesen wurde.
  bool get isLoaded => _loaded;

  @override
  Future<AppSettings> load() => _apply(_inner.load());

  @override
  Future<AppSettings> setOnboardingCompleted({required bool completed}) =>
      _apply(_inner.setOnboardingCompleted(completed: completed));

  @override
  Future<AppSettings> setAiEnabled({required bool enabled}) =>
      _apply(_inner.setAiEnabled(enabled: enabled));

  @override
  Future<AppSettings> setTone(AiTone tone) => _apply(_inner.setTone(tone));

  @override
  Future<AppSettings> setLockMethod(LockMethod method) =>
      _apply(_inner.setLockMethod(method));

  @override
  Future<AppSettings> setCompanionStyle(CompanionStyle style) =>
      _apply(_inner.setCompanionStyle(style));

  @override
  Future<AppSettings> setMfaHintShown({required bool shown}) =>
      _apply(_inner.setMfaHintShown(shown: shown));

  Future<AppSettings> _apply(Future<AppSettings> action) async {
    final settings = await action;
    _loaded = true;

    // Ohne echte Änderung kein Neubau: Jede Seite hängt an diesem Controller.
    if (settings == _current) return settings;

    _current = settings;
    notifyListeners();
    return settings;
  }
}
