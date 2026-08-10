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

  static const AccountException _unavailable = AccountException(
    AccountFailure.unreachable,
    setupHint,
    'AppConfig.hasBackend == false – SUPABASE_URL/SUPABASE_KEY fehlen',
  );

  @override
  bool get isConfigured => false;

  @override
  Future<Account?> currentAccount() async => null;

  @override
  Future<SignUpResult> signUp({
    required String username,
    required String email,
    required String password,
  }) async => throw _unavailable;

  @override
  Future<Account> confirmSignUp({
    required String email,
    required String code,
  }) async => throw _unavailable;

  @override
  Future<void> resendConfirmation(String email) async => throw _unavailable;

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async => throw _unavailable;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordReset(String email) async => throw _unavailable;

  @override
  Future<Account> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async => throw _unavailable;

  @override
  Future<MfaEnrollment> startMfaEnrollment() async => throw _unavailable;

  @override
  Future<void> confirmMfaEnrollment({
    required String factorId,
    required String code,
  }) async => throw _unavailable;

  @override
  Future<bool> hasMfa() async => false;

  @override
  Future<void> removeMfa() async => throw _unavailable;

  @override
  Future<bool> deleteAccount() async => throw _unavailable;
}

/// Konto nur auf dem Gerät – für die Entwicklung, bevor das Backend steht.
///
/// **Nicht für die Alpha.** Es gibt keine Wiederherstellung und keine
/// Reset-Mail; das Konzept verlangt beides. Diese Umsetzung existiert, damit
/// das Onboarding vollständig durchlaufbar und testbar ist.
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository({this.needsConfirmation = false});

  /// Ob der Bestätigungs-Schritt mitgespielt werden soll. Für Tests.
  final bool needsConfirmation;

  /// Der Code, den [confirmSignUp] und [resetPassword] akzeptieren.
  static const String testCode = '123456';

  Account? _account;
  String? _mfaFactorId;

  @override
  bool get isConfigured => true;

  @override
  Future<Account?> currentAccount() async => _account;

  @override
  Future<SignUpResult> signUp({
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

    _account = Account(
      id: 'local',
      username: username.trim(),
      email: email.trim(),
    );
    return SignUpResult(
      account: _account!,
      needsConfirmation: needsConfirmation,
    );
  }

  @override
  Future<Account> confirmSignUp({
    required String email,
    required String code,
  }) async {
    final account = _account;
    if (account == null || code.trim() != testCode) {
      throw const AccountException(
        AccountFailure.invalidCode,
        'Der Code hat nicht gepasst.',
      );
    }
    return account;
  }

  @override
  Future<void> resendConfirmation(String email) async {}

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    final account = _account;
    if (account == null || account.email != email.trim()) {
      throw const AccountException(
        AccountFailure.invalidCredentials,
        'E-Mail oder Passwort stimmt nicht.',
      );
    }
    return account;
  }

  @override
  Future<void> signOut() async => _account = null;

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!email.contains('@')) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Die E-Mail-Adresse sieht nicht richtig aus.',
      );
    }
  }

  @override
  Future<Account> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (code.trim() != testCode) {
      throw const AccountException(
        AccountFailure.invalidCode,
        'Der Code hat nicht gepasst.',
      );
    }
    if (newPassword.length < 8) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Das Passwort braucht mindestens 8 Zeichen.',
      );
    }

    return _account ??= Account(
      id: 'local',
      username: email.split('@').first,
      email: email.trim(),
    );
  }

  @override
  Future<MfaEnrollment> startMfaEnrollment() async => const MfaEnrollment(
    factorId: 'local-factor',
    secret: 'JBSWY3DPEHPK3PXP',
    uri: 'otpauth://totp/Neurohelp?secret=JBSWY3DPEHPK3PXP&issuer=Neurohelp',
  );

  @override
  Future<void> confirmMfaEnrollment({
    required String factorId,
    required String code,
  }) async {
    if (code.trim() != testCode) {
      throw const AccountException(
        AccountFailure.invalidCode,
        'Der Code hat nicht gepasst.',
      );
    }
    _mfaFactorId = factorId;
  }

  @override
  Future<bool> hasMfa() async => _mfaFactorId != null;

  @override
  Future<void> removeMfa() async => _mfaFactorId = null;

  @override
  Future<bool> deleteAccount() async {
    _account = null;
    _mfaFactorId = null;
    return false;
  }
}
