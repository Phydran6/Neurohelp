/// Woher der nutzereigene Schlüssel stammt.
enum OpenRouterKeyOrigin {
  /// Über den Login geholt – ein Tap, der User hat nie einen Schlüssel
  /// gesehen. Das ist der vorgesehene Weg (Konzept, Abschnitt 17a, Stufe 2).
  login,

  /// Von Hand eingetragen. Die versteckte Expertenoption (Stufe 3).
  manual,
}

/// Der nutzereigene Zugang zu OpenRouter.
///
/// Liegt **ausschließlich** verschlüsselt auf dem Gerät (Keystore bzw.
/// Keychain) und geht nie ins Backend. Genau deshalb gehen Anfragen mit
/// diesem Schlüssel auch direkt vom Gerät raus: Ein Proxy wäre nur eine
/// weitere Station, auf der fremde Daten landen.
class OpenRouterKey {
  const OpenRouterKey({required this.value, required this.origin});

  final String value;
  final OpenRouterKeyOrigin origin;

  /// Für Anzeigen. Der volle Schlüssel gehört nirgends auf den Bildschirm.
  ///
  /// Sichtbar bleiben nur die letzten vier Zeichen – genug, um zwei Zugänge
  /// auseinanderzuhalten, zu wenig, um damit etwas anzufangen.
  String get hint {
    if (value.length <= 4) return '••••';
    return '••••${value.substring(value.length - 4)}';
  }

  @override
  bool operator ==(Object other) =>
      other is OpenRouterKey && other.value == value && other.origin == origin;

  @override
  int get hashCode => Object.hash(value, origin);
}
