/// Das Pflicht-Konto aus dem Onboarding (Konzept, Abschnitt 13).
///
/// Serverseitig liegt nur, was zwingend zentral sein muss. Nutzerinhalte
/// bleiben auf dem Gerät.
class Account {
  const Account({
    required this.id,
    required this.username,
    required this.email,
  });

  final String id;
  final String username;
  final String email;
}

/// Wie lang ein Code aus einer Mail von Supabase sein kann.
///
/// Die Länge stellt das gehostete Projekt ein (Authentication → Providers →
/// Email → „Email OTP Length"), erlaubt sind 6 bis 10 Stellen. Das gehostete
/// Projekt verschickt 8 – die App hatte 6 fest eingebaut, und der Code ließ
/// sich nicht vollständig eintippen. Deshalb nimmt die App jede erlaubte
/// Länge an, statt eine bestimmte vorauszusetzen.
abstract final class EmailCode {
  static const int minLength = 6;
  static const int maxLength = 10;

  /// Entfernt Leerzeichen, die beim Kopieren aus der Mail mitkommen.
  static String normalize(String code) => code.replaceAll(RegExp(r'\s'), '');

  /// Ob der Code lang genug ist, um ihn abzuschicken.
  static bool looksComplete(String code) => normalize(code).length >= minLength;
}

/// Was ein Benutzername sein darf – dieselbe Regel wie in der Datenbank.
///
/// Die Tabelle `profiles` erlaubt nur 3 bis 32 Zeichen aus `A–Z`, `a–z`,
/// `0–9`, `_`, `.` und `-` (Migration `20260808120000_init.sql`). Die App
/// prüfte vorher nur die Mindestlänge. Wer eine Mail-Adresse als
/// Benutzernamen eintrug, kam bis zum Server durch und bekam von dort einen
/// unverständlichen Backend-Fehler zurück. Jetzt sagt die App es selbst,
/// schon beim Tippen.
abstract final class Username {
  static const int minLength = 3;
  static const int maxLength = 32;

  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9_.-]+$');

  /// Warum der Name nicht geht – oder `null`, wenn er passt.
  ///
  /// Mit [whileTyping] bleibt ein noch zu kurzer Name unkommentiert: Wer
  /// gerade erst den ersten Buchstaben getippt hat, braucht keinen Hinweis.
  static String? problem(String input, {bool whileTyping = false}) {
    final name = input.trim();

    if (name.contains('@')) {
      return 'Der Benutzername darf keine E-Mail-Adresse sein. Die Mail '
          'kommt ins Feld darunter – hier reicht ein Name, z.B. „philipp“.';
    }
    if (name.contains(RegExp(r'\s'))) {
      return 'Im Benutzernamen gehen keine Leerzeichen. Nimm z.B. einen '
          'Punkt oder Unterstrich: „max_mustermann“.';
    }
    if (name.isNotEmpty && !_allowed.hasMatch(name)) {
      return 'Im Benutzernamen gehen nur Buchstaben ohne Umlaute, Ziffern '
          'und _ . -';
    }
    if (name.length > maxLength) {
      return 'Der Benutzername darf höchstens $maxLength Zeichen haben.';
    }
    if (!whileTyping && name.length < minLength) {
      return 'Der Benutzername braucht mindestens $minLength Zeichen.';
    }
    return null;
  }

  /// Wirft eine [AccountException], wenn der Name nicht geht.
  static void check(String input) {
    final message = problem(input);
    if (message != null) {
      throw AccountException(AccountFailure.invalidInput, message);
    }
  }
}

/// Was nach einer Registrierung noch aussteht.
class SignUpResult {
  const SignUpResult({required this.account, required this.needsConfirmation});

  final Account account;

  /// Ob die Mail-Adresse noch mit einem Code bestätigt werden muss.
  ///
  /// Bewusst ein Code und kein Link: Ein Link in der Mail landet im Browser
  /// und muss von dort zurück in die App finden. Das ging in der Alpha
  /// regelmäßig schief („Email link is invalid or has expired"). Ein
  /// Code wird abgetippt und funktioniert überall.
  final bool needsConfirmation;
}

/// Eine begonnene Einrichtung der Zwei-Faktor-Anmeldung.
class MfaEnrollment {
  const MfaEnrollment({
    required this.factorId,
    required this.secret,
    required this.uri,
  });

  final String factorId;

  /// Der Schlüssel zum Abtippen, falls kein QR-Code gescannt werden kann.
  final String secret;

  /// `otpauth://…` für Authenticator-Apps.
  final String uri;
}

/// Warum eine Konto-Aktion nicht geklappt hat.
///
/// Bewusst grob gehalten: der User soll eine ruhige, verständliche Meldung
/// bekommen, keine technische Fehlerkette.
enum AccountFailure {
  /// Benutzername oder E-Mail ist schon vergeben.
  alreadyTaken,

  /// Zugangsdaten stimmen nicht.
  invalidCredentials,

  /// Kein Netz oder Backend nicht erreichbar.
  unreachable,

  /// Eingabe passt formal nicht (z.B. zu kurzes Passwort).
  invalidInput,

  /// Der Bestätigungs-Code stimmt nicht oder ist abgelaufen.
  invalidCode,

  /// Die Mail-Adresse ist noch nicht bestätigt.
  notConfirmed,

  unknown,
}

class AccountException implements Exception {
  const AccountException(this.failure, [this.details, this.technical]);

  final AccountFailure failure;

  /// Was der User lesen soll – ruhig, ohne Vorwurf, ohne Fachbegriffe.
  final String? details;

  /// Was beim Suchen hilft: Fehlercode, Endpunkt, Originalmeldung.
  ///
  /// Steht in der Oberfläche hinter „Details" und wird nicht von selbst
  /// angezeigt. Ohne das ist jede Störung eine Sackgasse.
  final String? technical;

  @override
  String toString() =>
      'AccountException($failure)${details == null ? '' : ': $details'}';
}

/// Kontoverwaltung. Die Implementierung spricht mit Supabase Auth.
abstract interface class AccountRepository {
  /// Ob überhaupt ein Backend hinterlegt ist. Ohne das gibt es kein Konto,
  /// und die App sagt das, statt eines vorzutäuschen.
  bool get isConfigured;

  /// Das aktuell angemeldete Konto, oder `null`.
  Future<Account?> currentAccount();

  /// Meldet jeden Wechsel zwischen angemeldet (`true`) und abgemeldet
  /// (`false`).
  ///
  /// Darauf horcht der Einstieg der App: Wer sich abmeldet – oder dessen
  /// Sitzung serverseitig abläuft –, landet wieder bei der Anmeldung, statt
  /// in einer App zu stehen, die so tut, als wäre nichts gewesen.
  Stream<bool> get signedInChanges;

  /// Legt ein Konto an. Alle drei Felder sind laut Konzept Pflicht.
  Future<SignUpResult> signUp({
    required String username,
    required String email,
    required String password,
  });

  /// Bestätigt die Mail-Adresse mit dem Code aus der Willkommens-Mail.
  Future<Account> confirmSignUp({required String email, required String code});

  /// Schickt die Bestätigungs-Mail noch einmal.
  Future<void> resendConfirmation(String email);

  Future<Account> signIn({required String email, required String password});

  Future<void> signOut();

  /// Stößt die Reset-Mail an (Versand serverseitig über Supabase Auth).
  Future<void> sendPasswordReset(String email);

  /// Setzt das Passwort mit dem Code aus der Reset-Mail neu.
  Future<Account> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Ändert das Passwort der **laufenden** Sitzung – ohne Code, ohne Mail.
  ///
  /// Der Unterschied zu [resetPassword]: Dort beweist der Code aus der Mail,
  /// dass das Postfach dem Anrufer gehört. Wer schon angemeldet ist, hat das
  /// längst bewiesen; ihn trotzdem durch eine Mail zu schicken wäre eine
  /// Hürde ohne Gewinn.
  ///
  /// Das fehlte bis hierher komplett: Das Passwort ließ sich **nur** über
  /// „vergessen" im Einstieg ändern – wer angemeldet war, kam gar nicht
  /// daran.
  Future<Account> changePassword(String newPassword);

  /// Beginnt die Einrichtung der Zwei-Faktor-Anmeldung (TOTP).
  Future<MfaEnrollment> startMfaEnrollment();

  /// Schließt die Einrichtung mit dem sechsstelligen Code der
  /// Authenticator-App ab.
  Future<void> confirmMfaEnrollment({
    required String factorId,
    required String code,
  });

  /// Ob für dieses Konto bereits ein zweiter Faktor eingerichtet ist.
  Future<bool> hasMfa();

  /// Entfernt alle eingerichteten zweiten Faktoren.
  Future<void> removeMfa();

  /// Löscht das Konto und **alle** serverseitigen Daten dazu.
  ///
  /// Liefert `true`, wenn das Backend zusätzlich eine Bestätigungs-Mail
  /// verschickt hat.
  Future<bool> deleteAccount();
}
