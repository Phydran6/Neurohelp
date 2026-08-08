/// Setzt den Floskel-Rahmen um einen Nachrichtentext.
///
/// Regel aus dem Konzept (Abschnitt 10, Schritt 4): **Immer der gleiche
/// höflich-neutrale Standard, bei allen Empfängern.** Begründung: kostet
/// keine Denkkapazität, keine Fehlerquelle, funktioniert überall angemessen.
///
/// Floskel-Arbeit darf den User niemals belasten – auch nicht, wenn er den
/// Inhalt selbst schreibt.
abstract final class MessageFraming {
  /// Geschlechtsneutral und für Firmen wie Privatpersonen passend.
  static const String salutation = 'Guten Tag,';

  static const String closing = 'Mit freundlichen Grüßen';

  /// Legt Anrede und Grußformel um [body].
  ///
  /// Ist der Rahmen schon da – etwa weil die KI ihn mitgeliefert hat oder der
  /// User ihn selbst getippt hat – bleibt der Text unverändert. Doppelte
  /// Anreden sind peinlicher als gar keine.
  static String wrap(String body, {String? senderName}) {
    final content = body.trim();
    if (content.isEmpty) return '';

    final parts = <String>[];

    if (!hasSalutation(content)) {
      parts.add(salutation);
      parts.add('');
    }

    parts.add(content);

    if (!hasClosing(content)) {
      parts.add('');
      parts.add(closing);
      if (senderName != null && senderName.trim().isNotEmpty) {
        parts.add(senderName.trim());
      }
    }

    return parts.join('\n');
  }

  /// Nur der Inhalt, ohne Rahmen – für die Nachbearbeitung durch den User.
  static String unwrap(String message) {
    var lines = message.trim().split('\n');

    while (lines.isNotEmpty && _isSalutation(lines.first)) {
      lines = lines.sublist(1);
    }
    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines = lines.sublist(1);
    }

    final closingIndex = lines.indexWhere((line) => _isClosing(line));
    if (closingIndex >= 0) {
      lines = lines.sublist(0, closingIndex);
    }
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines = lines.sublist(0, lines.length - 1);
    }

    return lines.join('\n').trim();
  }

  static bool hasSalutation(String message) {
    final first = message.trim().split('\n').first;
    return _isSalutation(first);
  }

  static bool hasClosing(String message) =>
      message.trim().split('\n').any(_isClosing);

  static const List<String> _salutationStarts = [
    'guten tag',
    'sehr geehrte',
    'sehr geehrter',
    'hallo',
    'liebe',
    'lieber',
    'moin',
  ];

  static const List<String> _closingStarts = [
    'mit freundlichen grüßen',
    'freundliche grüße',
    'viele grüße',
    'beste grüße',
    'liebe grüße',
    'herzliche grüße',
  ];

  static bool _isSalutation(String line) {
    final normalized = line.trim().toLowerCase();
    return _salutationStarts.any(normalized.startsWith);
  }

  static bool _isClosing(String line) {
    final normalized = line.trim().toLowerCase();
    return _closingStarts.any(normalized.startsWith);
  }
}
