import '../account_repository.dart';

/// Konto-Verwaltung, solange kein Backend eingerichtet ist.
///
/// Das Konto ist laut Konzept (Abschnitt 13) Pflicht und läuft über
/// Supabase Auth. Solange das Projekt nicht existiert, kann die App kein
/// Konto anlegen – und sie tut auch nicht so.
///
/// Sobald `SUPABASE_URL` und `SUPABASE_KEY` gesetzt sind, tritt
/// `SupabaseAccountRepository` an diese Stelle.
class UnconfiguredAccountRepository implements AccountRepository {
  const UnconfiguredAccountRepository();

  static const String setupHint =
      'Die Kontoverwaltung ist noch nicht eingerichtet. '
      'Siehe docs/BACKEND.md.';

  @override
  Future<Account?> currentAccount() async => null;

  @override
  Future<Account> signUp({
    required String username,
    required String email,
    required String password,
  }) async => throw const AccountException(
    AccountFailure.unreachable,
    UnconfiguredAccountRepository.setupHint,
  );

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async => throw const AccountException(
    AccountFailure.unreachable,
    UnconfiguredAccountRepository.setupHint,
  );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) async =>
      throw const AccountException(
        AccountFailure.unreachable,
        UnconfiguredAccountRepository.setupHint,
      );
}

/// Konto nur auf dem Gerät – für die Entwicklung, bevor das Backend steht.
///
/// **Nicht für die Alpha.** Es gibt keine Wiederherstellung und keine
/// Reset-Mail; das Konzept verlangt beides. Diese Umsetzung existiert, damit
/// das Onboarding vollständig durchlaufbar und testbar ist.
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository();

  Account? _account;

  @override
  Future<Account?> currentAccount() async => _account;

  @override
  Future<Account> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    if (username.trim().length < 3) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Der Benutzername braucht mindestens 3 Zeichen.',
      );
    }
    if (!email.contains('@')) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Die E-Mail-Adresse sieht nicht richtig aus.',
      );
    }
    if (password.length < 8) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Das Passwort braucht mindestens 8 Zeichen.',
      );
    }

    return _account = Account(
      id: 'local',
      username: username.trim(),
      email: email.trim(),
    );
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    final account = _account;
    if (account == null || account.email != email.trim()) {
      throw const AccountException(AccountFailure.invalidCredentials);
    }
    return account;
  }

  @override
  Future<void> signOut() async => _account = null;

  @override
  Future<void> sendPasswordReset(String email) async =>
      throw const AccountException(
        AccountFailure.unreachable,
        'Reset-Mails brauchen das Backend.',
      );
}
