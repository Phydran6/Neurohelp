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

/// Was nach einer Registrierung noch aussteht.
class SignUpResult {
  const SignUpResult({required this.account, required this.needsConfirmation});

  final Account account;

  /// Ob die Mail-Adresse noch mit einem Code bestätigt werden muss.
  ///
  /// Bewusst ein Code und kein Link: Ein Link in der Mail landet im Browser
  /// und muss von dort zurück in die App finden. Das ging in der Alpha
  /// regelmäßig schief („Email link is invalid or has expired"). Ein
  /// sechsstelliger Code wird abgetippt und funktioniert überall.
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
