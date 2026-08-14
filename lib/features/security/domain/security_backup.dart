/// Die Sicherung für den Zugang, als Text (Konzept, Abschnitt 13).
///
/// Zwei Dinge, die der User genau **einmal** zu sehen bekommt und danach nie
/// wieder: den Schlüssel für die Authenticator-App und die
/// Wiederherstellungs-Codes. Ein Bildschirm, den man abschreiben soll, ist
/// dafür der falsche Ort – abgeschrieben wird er nicht, abfotografiert
/// vielleicht, und beim Gerätewechsel fehlt er.
///
/// Deshalb als Datei zum Mitnehmen. Reiner Text: Das lässt sich in jedem
/// Passwort-Manager, jeder Notiz-App und auf jedem Drucker öffnen, auch in
/// zehn Jahren.
class SecurityBackup {
  const SecurityBackup({
    required this.createdAt,
    this.accountEmail,
    this.totpSecret,
    this.totpUri,
    this.recoveryCodes = const [],
  });

  final DateTime createdAt;
  final String? accountEmail;

  /// Der Schlüssel zum Abtippen in eine Authenticator-App.
  final String? totpSecret;

  /// `otpauth://…` – von vielen Authenticator-Apps direkt einlesbar.
  final String? totpUri;

  /// Klartext der Wiederherstellungs-Codes. Gespeichert wird davon nirgends
  /// etwas – nur die Hashes, und die liegen im sicheren Speicher.
  final List<String> recoveryCodes;

  /// Dateiname mit Datum, damit mehrere Sicherungen unterscheidbar bleiben.
  String get fileName {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'neurohelp-sicherung-'
        '${createdAt.year}-${two(createdAt.month)}-${two(createdAt.day)}.txt';
  }

  /// Der Inhalt der Datei.
  String toText() {
    final buffer = StringBuffer()
      ..writeln('Neurohelp – Sicherung für deinen Zugang')
      ..writeln('Erstellt am ${_timestamp(createdAt)}')
      ..writeln()
      ..writeln(
        'Bewahr das so auf, wie du wichtige Papiere aufbewahrst. Wer diese '
        'Datei hat, kommt an dein Konto.',
      )
      ..writeln();

    if (accountEmail != null && accountEmail!.isNotEmpty) {
      buffer
        ..writeln('Konto: $accountEmail')
        ..writeln();
    }

    if (totpSecret != null) {
      buffer
        ..writeln(_rule('Schlüssel für die Authenticator-App'))
        ..writeln()
        ..writeln(_grouped(totpSecret!))
        ..writeln();

      if (totpUri != null && totpUri!.isNotEmpty) {
        buffer
          ..writeln('Als Link (viele Apps lesen das direkt ein):')
          ..writeln(totpUri!)
          ..writeln();
      }

      buffer
        ..writeln(
          'Damit richtest du die Zwei-Faktor-Anmeldung auf einem neuen Gerät '
          'wieder ein. Du trägst den Schlüssel in deine Authenticator-App '
          'ein – nicht in Neurohelp.',
        )
        ..writeln();
    }

    if (recoveryCodes.isNotEmpty) {
      buffer
        ..writeln(_rule('Wiederherstellungs-Codes'))
        ..writeln()
        ..writeln(
          'Jeder Code funktioniert genau einmal. Damit kommst du an der '
          'App-Sperre vorbei, wenn PIN und Fingerabdruck nicht mehr gehen.',
        )
        ..writeln();

      for (var i = 0; i < recoveryCodes.length; i++) {
        buffer.writeln(
          '  ${(i + 1).toString().padLeft(2)}. ${recoveryCodes[i]}',
        );
      }
      buffer.writeln();
    }

    buffer.writeln(
      'Deine Vorgänge – Anrufe, Termine, Nachrichten, Aufgaben – stehen hier '
      'bewusst nicht drin. Die liegen ausschließlich auf deinem Gerät und '
      'gehen bei einem Gerätewechsel verloren.',
    );

    return buffer.toString();
  }

  static String _rule(String title) => '$title\n${'─' * title.length}';

  /// Schlüssel in Vierergruppen – so ist er abzutippen, ohne die Stelle zu
  /// verlieren.
  static String _grouped(String secret) {
    final clean = secret.replaceAll(RegExp(r'\s'), '');
    final groups = <String>[];

    for (var i = 0; i < clean.length; i += 4) {
      groups.add(
        clean.substring(i, i + 4 > clean.length ? clean.length : i + 4),
      );
    }
    return groups.join(' ');
  }

  static String _timestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}, '
        '${two(value.hour)}:${two(value.minute)} Uhr';
  }
}
