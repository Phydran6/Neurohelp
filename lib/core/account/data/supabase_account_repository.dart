import 'package:supabase_flutter/supabase_flutter.dart';

import '../../logging/app_logger.dart';
import '../account_repository.dart';

/// Kontoverwaltung über Supabase Auth.
///
/// Serverseitig entsteht dabei nur ein Eintrag in `auth.users` und das
/// zugehörige Profil – Nutzerinhalte bleiben auf dem Gerät.
class SupabaseAccountRepository implements AccountRepository {
  const SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  /// Backend-Funktion, die ein Konto restlos entfernt.
  static const String _deleteFunction = 'delete-account';

  @override
  bool get isConfigured => true;

  @override
  Future<Account?> currentAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _toAccount(user);
  }

  @override
  Future<SignUpResult> signUp({
    required String username,
    required String password,
    required String email,
  }) async {
    _checkInput(username: username, email: email, password: password);

    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        // Der Datenbank-Trigger legt daraus das Profil an.
        data: {'username': username.trim()},
      );

      final user = response.user;
      if (user == null) {
        throw const AccountException(
          AccountFailure.unknown,
          'Das Konto wurde nicht angelegt.',
        );
      }

      // Ohne Sitzung heißt: Supabase verlangt die Bestätigung der Mail.
      return SignUpResult(
        account: _toAccount(user),
        needsConfirmation: response.session == null,
      );
    } on AuthException catch (error) {
      throw _translate(error, 'auth.signUp');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.signUp');
    }
  }

  @override
  Future<Account> confirmSignUp({
    required String email,
    required String code,
  }) async {
    _checkCode(code);

    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim(),
        token: code.trim(),
      );

      final user = response.user;
      if (user == null) {
        throw const AccountException(
          AccountFailure.invalidCode,
          'Der Code hat nicht gepasst.',
        );
      }
      return _toAccount(user);
    } on AuthException catch (error) {
      throw _translate(error, 'auth.verifyOTP(signup)');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.verifyOTP(signup)');
    }
  }

  @override
  Future<void> resendConfirmation(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email.trim());
    } on AuthException catch (error) {
      throw _translate(error, 'auth.resend(signup)');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.resend(signup)');
    }
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AccountException(AccountFailure.invalidCredentials);
      }
      return _toAccount(user);
    } on AuthException catch (error) {
      throw _translate(error, 'auth.signInWithPassword');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.signInWithPassword');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw _translate(error, 'auth.signOut');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!email.contains('@')) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Das sieht nicht nach einer E-Mail-Adresse aus.',
      );
    }

    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      throw _translate(error, 'auth.resetPasswordForEmail');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.resetPasswordForEmail');
    }
  }

  @override
  Future<Account> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _checkCode(code);
    if (newPassword.length < 8) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Das Passwort braucht mindestens 8 Zeichen.',
      );
    }

    try {
      // Der Code aus der Mail schaltet eine Sitzung frei; erst damit lässt
      // sich das Passwort setzen.
      final verified = await _client.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim(),
        token: code.trim(),
      );
      if (verified.user == null) {
        throw const AccountException(
          AccountFailure.invalidCode,
          'Der Code hat nicht gepasst.',
        );
      }

      final updated = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      final user = updated.user;
      if (user == null) {
        throw const AccountException(
          AccountFailure.unknown,
          'Das Passwort wurde nicht geändert.',
        );
      }
      return _toAccount(user);
    } on AuthException catch (error) {
      throw _translate(error, 'auth.verifyOTP(recovery)');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.verifyOTP(recovery)');
    }
  }

  @override
  Future<MfaEnrollment> startMfaEnrollment() async {
    try {
      final response = await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: 'Neurohelp ${DateTime.now().millisecondsSinceEpoch}',
      );

      final totp = response.totp;
      if (totp == null) {
        throw const AccountException(
          AccountFailure.unknown,
          'Das Backend hat keinen Schlüssel geliefert.',
          'auth.mfa.enroll → totp fehlt in der Antwort',
        );
      }

      return MfaEnrollment(
        factorId: response.id,
        secret: totp.secret,
        uri: totp.uri,
      );
    } on AuthException catch (error) {
      throw _translate(error, 'auth.mfa.enroll');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.mfa.enroll');
    }
  }

  @override
  Future<void> confirmMfaEnrollment({
    required String factorId,
    required String code,
  }) async {
    _checkCode(code);

    try {
      final challenge = await _client.auth.mfa.challenge(factorId: factorId);
      await _client.auth.mfa.verify(
        factorId: factorId,
        challengeId: challenge.id,
        code: code.trim(),
      );
    } on AuthException catch (error) {
      throw _translate(error, 'auth.mfa.verify');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.mfa.verify');
    }
  }

  @override
  Future<bool> hasMfa() async {
    try {
      final factors = await _client.auth.mfa.listFactors();
      return factors.totp.isNotEmpty;
    } on Exception catch (error) {
      AppLogger.info('Faktoren nicht lesbar: $error', scope: 'account');
      return false;
    }
  }

  @override
  Future<void> removeMfa() async {
    try {
      final factors = await _client.auth.mfa.listFactors();
      for (final factor in factors.totp) {
        await _client.auth.mfa.unenroll(factor.id);
      }
    } on AuthException catch (error) {
      throw _translate(error, 'auth.mfa.unenroll');
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'auth.mfa.unenroll');
    }
  }

  @override
  Future<bool> deleteAccount() async {
    if (_client.auth.currentUser == null) {
      throw const AccountException(
        AccountFailure.invalidCredentials,
        'Dafür musst du angemeldet sein.',
      );
    }

    try {
      final response = await _client.functions.invoke(_deleteFunction);
      final data = response.data;

      // Ob eine Bestätigungs-Mail rausging, entscheidet das Backend – nur
      // dort liegen die Zugangsdaten für den Mailversand.
      final emailed = data is Map && data['emailed'] == true;

      // Die Sitzung ist mit dem Konto weg. Lokal aufräumen, damit die App
      // nicht mit einem Token weiterläuft, hinter dem nichts mehr steht.
      try {
        await _client.auth.signOut();
      } on Exception catch (error) {
        AppLogger.info('Abmelden nach dem Löschen: $error', scope: 'account');
      }

      return emailed;
    } on FunctionException catch (error, stackTrace) {
      AppLogger.error(
        'Konto konnte nicht gelöscht werden',
        scope: 'account',
        error: error,
        stackTrace: stackTrace,
      );
      throw AccountException(
        error.status == 404
            ? AccountFailure.unreachable
            : AccountFailure.unknown,
        error.status == 404
            ? 'Die Löschfunktion ist im Backend noch nicht eingerichtet.'
            : 'Das Löschen hat nicht geklappt. Versuch es später noch mal.',
        'functions/$_deleteFunction → HTTP ${error.status}: '
        '${error.details ?? error.reasonPhrase ?? ''}',
      );
    } on Exception catch (error, stackTrace) {
      throw _wrap(error, stackTrace, 'functions/$_deleteFunction');
    }
  }

  static Account _toAccount(User user) {
    final username = user.userMetadata?['username'];

    return Account(
      id: user.id,
      username: username is String && username.isNotEmpty
          ? username
          : (user.email ?? '').split('@').first,
      email: user.email ?? '',
    );
  }

  /// Prüft, was sich ohne Netz prüfen lässt – der Server sagt sonst dasselbe,
  /// nur langsamer und auf Englisch.
  static void _checkInput({
    required String username,
    required String email,
    required String password,
  }) {
    if (username.trim().length < 3) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Der Benutzername braucht mindestens 3 Zeichen.',
      );
    }
    if (!email.contains('@')) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Das sieht nicht nach einer E-Mail-Adresse aus.',
      );
    }
    if (password.length < 8) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Das Passwort braucht mindestens 8 Zeichen.',
      );
    }
  }

  static void _checkCode(String code) {
    if (code.trim().length < 6) {
      throw const AccountException(
        AccountFailure.invalidInput,
        'Der Code hat sechs Zeichen.',
      );
    }
  }

  /// Übersetzt die technische Meldung in etwas, das man ruhig lesen kann.
  static AccountException _translate(AuthException error, String where) {
    final message = error.message.toLowerCase();
    final technical =
        '$where → ${error.statusCode ?? '-'} '
        '${error.code ?? ''} ${error.message}';

    if (message.contains('already registered') ||
        message.contains('already exists') ||
        error.code == 'user_already_exists') {
      return AccountException(
        AccountFailure.alreadyTaken,
        'Mit dieser E-Mail gibt es schon ein Konto. Melde dich damit an '
        'oder setz das Passwort zurück.',
        technical,
      );
    }

    if (message.contains('invalid login') ||
        error.code == 'invalid_credentials') {
      return AccountException(
        AccountFailure.invalidCredentials,
        'E-Mail oder Passwort stimmt nicht.',
        technical,
      );
    }

    if (message.contains('not confirmed') ||
        error.code == 'email_not_confirmed') {
      return AccountException(
        AccountFailure.notConfirmed,
        'Die Mail-Adresse ist noch nicht bestätigt. Ich schicke dir den '
        'Code gern noch einmal.',
        technical,
      );
    }

    if (message.contains('expired') ||
        message.contains('invalid token') ||
        message.contains('token has expired') ||
        error.code == 'otp_expired' ||
        error.code == 'otp_disabled') {
      return AccountException(
        AccountFailure.invalidCode,
        'Der Code stimmt nicht oder ist abgelaufen. Lass dir einen neuen '
        'schicken.',
        technical,
      );
    }

    if (message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('network')) {
      return AccountException(
        AccountFailure.unreachable,
        'Ich erreiche den Server gerade nicht. Versuch es später nochmal.',
        technical,
      );
    }

    // Der Mailversand des Backends klemmt – falscher SMTP-Zugang, gesperrter
    // Absender, blockierter Port. Für den User sieht das aus, als hätte er
    // etwas falsch gemacht; hat er nicht, und nachtippen hilft auch nicht.
    if (message.contains('error sending') ||
        message.contains('smtp') ||
        message.contains('mail') && message.contains('failed')) {
      return AccountException(
        AccountFailure.unreachable,
        'Die Mail ließ sich nicht verschicken – das liegt am Mailversand '
        'unseres Backends, nicht an dir. Versuch es später nochmal.',
        technical,
      );
    }

    return AccountException(
      AccountFailure.unknown,
      // Manche Störungen kommen als roher JSON-Block zurück. Der ist für
      // niemanden lesbar und gehört hinter „Details", nicht auf den
      // Bildschirm.
      _isReadable(error.message)
          ? error.message
          : 'Das hat gerade nicht geklappt. Unter „Details" steht, was das '
                'Backend gemeldet hat.',
      technical,
    );
  }

  /// Ob eine Meldung als Satz durchgeht – oder ob sie nach Maschine aussieht.
  static bool _isReadable(String message) {
    final trimmed = message.trim();
    return !trimmed.startsWith('{') &&
        !trimmed.startsWith('[') &&
        !trimmed.contains('"code"');
  }

  /// Alles, was keine [AuthException] ist – meistens fehlendes Netz.
  static AccountException _wrap(
    Object error,
    StackTrace stackTrace,
    String where,
  ) {
    AppLogger.error(
      'Konto-Aktion fehlgeschlagen ($where)',
      scope: 'account',
      error: error,
      stackTrace: stackTrace,
    );

    return AccountException(
      AccountFailure.unreachable,
      'Ich erreiche den Server gerade nicht. Versuch es später nochmal.',
      '$where → $error',
    );
  }
}
