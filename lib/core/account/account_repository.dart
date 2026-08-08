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

  unknown,
}

class AccountException implements Exception {
  const AccountException(this.failure, [this.details]);

  final AccountFailure failure;
  final String? details;

  @override
  String toString() =>
      'AccountException($failure)${details == null ? '' : ': $details'}';
}

/// Kontoverwaltung. Die Implementierung spricht mit Supabase Auth.
abstract interface class AccountRepository {
  /// Das aktuell angemeldete Konto, oder `null`.
  Future<Account?> currentAccount();

  /// Legt ein Konto an. Alle drei Felder sind laut Konzept Pflicht.
  Future<Account> signUp({
    required String username,
    required String email,
    required String password,
  });

  Future<Account> signIn({required String email, required String password});

  Future<void> signOut();

  /// Stößt die Reset-Mail an (Versand serverseitig über Supabase Auth).
  Future<void> sendPasswordReset(String email);
}
