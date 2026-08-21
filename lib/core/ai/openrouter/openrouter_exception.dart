/// Warum ein Aufruf bei OpenRouter nicht durchging.
///
/// Die Unterscheidung ist kein Selbstzweck: Sie entscheidet, ob die App es
/// mit dem nächsten Modell erneut versucht, ob sie auf die nächste Stufe
/// zurückfällt oder ob der User seinen Zugang neu verbinden muss.
enum OpenRouterFailure {
  /// Kein Netz, Zeitüberschreitung, Server antwortet nicht.
  network,

  /// Schlüssel abgelaufen, widerrufen oder falsch. Hier hilft nur ein
  /// neuer Login – und den muss der User anstoßen.
  unauthorized,

  /// Ratenlimit erreicht. Kostenlose Modelle sind gedrosselt.
  rateLimited,

  /// Genau dieses Modell gibt es nicht mehr oder es ist gerade weg. Das
  /// nächste aus der Liste kann funktionieren.
  modelUnavailable,

  /// Der Anbieter hat die Anfrage abgelehnt.
  refused,

  /// Die Antwort war nicht das, was sie sein sollte.
  malformed,
}

/// Ein Aufruf bei OpenRouter ist fehlgeschlagen.
class OpenRouterException implements Exception {
  const OpenRouterException(this.failure, this.reason, {this.technical});

  final OpenRouterFailure failure;

  /// Ein ruhiger Satz, den man einem Menschen zeigen kann.
  final String reason;

  /// Für den aufklappbaren technischen Teil und das Log. Nie im Hauptext.
  final String? technical;

  /// Ob ein anderes Modell die Sache retten könnte.
  bool get worthAnotherModel =>
      failure == OpenRouterFailure.modelUnavailable ||
      failure == OpenRouterFailure.rateLimited ||
      failure == OpenRouterFailure.refused ||
      failure == OpenRouterFailure.malformed;

  @override
  String toString() => 'OpenRouterException(${failure.name}): $reason';
}
