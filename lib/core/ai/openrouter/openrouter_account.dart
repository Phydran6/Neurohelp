import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../logging/app_logger.dart';
import 'openrouter_api.dart';
import 'openrouter_exception.dart';
import 'openrouter_key.dart';
import 'openrouter_key_store.dart';
import 'openrouter_login.dart';
import 'pkce.dart';

/// Wie ein Verbindungsversuch ausgegangen ist.
enum OpenRouterConnectResult {
  /// Der Zugang liegt jetzt auf dem Gerät.
  connected,

  /// Der User hat den Login abgebrochen. Kein Fehler, keine Meldung.
  cancelled,
}

/// Der eigene KI-Zugang des Users (Konzept, Abschnitt 17a, Stufen 2 und 3).
///
/// Für den User ist das „mit Konto anmelden": ein Tap, danach nie wieder ein
/// Thema. Er sieht nie einen Schlüssel und kopiert nichts – das ist der
/// Unterschied zum klassischen Selbst-eintragen und der Grund, warum dieser
/// Weg das DAU-Prinzip nicht bricht.
class OpenRouterAccount extends ChangeNotifier {
  OpenRouterAccount({
    required OpenRouterKeyStore store,
    required OpenRouterApi api,
    OpenRouterLogin login = const WebOpenRouterLogin(),
  }) : _store = store,
       _api = api,
       _login = login;

  final OpenRouterKeyStore _store;
  final OpenRouterApi _api;
  final OpenRouterLogin _login;

  OpenRouterKey? _key;
  bool _hasCredit = false;
  bool _loaded = false;
  bool _needsReconnect = false;

  /// Der hinterlegte Zugang, oder `null`.
  OpenRouterKey? get key => _key;

  /// Ob ein eigener Zugang auf dem Gerät liegt.
  bool get isConnected => _key != null;

  /// Ob der hinterlegte Zugang zurückgewiesen wurde – abgelaufen, widerrufen
  /// oder von Hand falsch eingetragen.
  ///
  /// Der Schlüssel bleibt trotzdem liegen: Ihn stillschweigend wegzuwerfen
  /// wäre die schlechtere Überraschung. Stattdessen bietet die App einen
  /// sauberen neuen Login an, und bis dahin läuft die KI eine Stufe
  /// einfacher weiter.
  bool get needsReconnect => _needsReconnect;

  /// Ob die App diesen Zugang gerade benutzen darf.
  bool get isUsable => isConnected && !_needsReconnect;

  /// Ob der User bei OpenRouter Guthaben aufgeladen hat.
  ///
  /// Nur dann zieht die App auch kostenpflichtige Modelle in Betracht – das
  /// Geld liegt dort ausdrücklich für genau diesen Zweck.
  bool get hasCredit => _hasCredit;

  /// Ob schon einmal aus dem sicheren Speicher gelesen wurde.
  bool get isLoaded => _loaded;

  /// Liest den gespeicherten Zugang. Wird einmal beim App-Start aufgerufen.
  Future<void> load() async {
    _key = await _store.read();
    _loaded = true;
    notifyListeners();

    // Das Guthaben nachzureichen darf den Start nicht aufhalten.
    if (_key != null) unawaited(_refreshCredit());
  }

  /// Der ganze Weg: Login im Browser, Code zurück, Schlüssel eintauschen,
  /// verschlüsselt ablegen.
  ///
  /// Wirft [OpenRouterException], wenn etwas schiefgeht – der Aufrufer zeigt
  /// dann [OpenRouterException.reason] an. Ein Abbruch durch den User ist
  /// **kein** Fehler und kommt als [OpenRouterConnectResult.cancelled].
  Future<OpenRouterConnectResult> connect() async {
    final pkce = PkcePair.generate();

    final callback = await _login.authorize(
      OpenRouterApi.loginUrl(pkce),
      callbackScheme: OpenRouterApi.callbackScheme,
    );
    if (callback == null) return OpenRouterConnectResult.cancelled;

    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      // Manche Abbrüche kommen als Rücksprung ohne Code zurück – das ist
      // dasselbe wie „nicht gemacht", keine Fehlermeldung wert.
      final denied = callback.queryParameters['error'];
      if (denied != null) return OpenRouterConnectResult.cancelled;

      throw const OpenRouterException(
        OpenRouterFailure.malformed,
        'Die Anmeldung kam unvollständig zurück.',
      );
    }

    final value = await _api.exchangeCode(code: code, verifier: pkce.verifier);
    await _adopt(
      OpenRouterKey(value: value, origin: OpenRouterKeyOrigin.login),
    );

    return OpenRouterConnectResult.connected;
  }

  /// Die versteckte Expertenoption: ein selbst besorgter Schlüssel.
  ///
  /// Wird vor dem Speichern einmal ausprobiert. Ein Schlüssel, der erst
  /// mitten in einem Ablauf als falsch auffällt, ist schlimmer als gar keiner.
  Future<void> connectWithKey(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) {
      throw const OpenRouterException(
        OpenRouterFailure.unauthorized,
        'Da steht noch nichts.',
      );
    }

    final info = await _api.keyInfo(value);
    await _adopt(
      OpenRouterKey(value: value, origin: OpenRouterKeyOrigin.manual),
      credit: info.hasCredit,
    );
  }

  /// Wirft den Zugang vom Gerät.
  ///
  /// Danach läuft die KI wieder über die eigene gehostete Stufe – es fällt
  /// nichts aus, es wird nur wieder einfacher.
  Future<void> disconnect() async {
    await _store.clear();
    _key = null;
    _hasCredit = false;
    _needsReconnect = false;
    notifyListeners();
  }

  /// Meldet, dass OpenRouter den Zugang zurückgewiesen hat.
  ///
  /// Ruft die KI-Schicht auf, wenn eine Anfrage mit 401 zurückkommt. Ab dann
  /// versucht die App es nicht weiter, sondern geht eine Stufe tiefer.
  void markRejected() {
    if (_needsReconnect || _key == null) return;

    AppLogger.info('Zugang zurückgewiesen', scope: 'openrouter');
    _needsReconnect = true;
    notifyListeners();
  }

  Future<void> _adopt(OpenRouterKey key, {bool? credit}) async {
    await _store.write(key);
    _key = key;
    _hasCredit = credit ?? false;
    _needsReconnect = false;
    notifyListeners();

    if (credit == null) unawaited(_refreshCredit());
  }

  Future<void> _refreshCredit() async {
    final key = _key;
    if (key == null) return;

    try {
      final info = await _api.keyInfo(key.value);
      if (_key != key) return;

      _hasCredit = info.hasCredit;
      notifyListeners();
    } on OpenRouterException catch (error) {
      // Kein Grund, den User zu behelligen: Ohne diese Auskunft bleibt es
      // eben bei den kostenlosen Modellen.
      AppLogger.info(
        'Guthaben nicht abfragbar: ${error.failure.name}',
        scope: 'openrouter',
      );
    }
  }
}
