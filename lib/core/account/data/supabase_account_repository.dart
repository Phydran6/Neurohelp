import 'package:supabase_flutter/supabase_flutter.dart';

import '../account_repository.dart';

/// Kontoverwaltung über Supabase Auth.
///
/// Serverseitig entsteht dabei nur ein Eintrag in `auth.users` und das
/// zugehörige Profil – Nutzerinhalte bleiben auf dem Gerät.
class SupabaseAccountRepository implements AccountRepository {
  const SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Account?> currentAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _toAccount(user);
  }

  @override
  Future<Account> signUp({
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
      return _toAccount(user);
    } on AuthException catch (error) {
      throw _translate(error);
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
      throw _translate(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      throw _translate(error);
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

  /// Übersetzt die technische Meldung in etwas, das man ruhig lesen kann.
  static AccountException _translate(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('already registered') ||
        message.contains('already exists') ||
        error.code == 'user_already_exists') {
      return const AccountException(
        AccountFailure.alreadyTaken,
        'Mit dieser E-Mail gibt es schon ein Konto.',
      );
    }

    if (message.contains('invalid login') ||
        error.code == 'invalid_credentials') {
      return const AccountException(
        AccountFailure.invalidCredentials,
        'E-Mail oder Passwort stimmt nicht.',
      );
    }

    if (message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('network')) {
      return const AccountException(
        AccountFailure.unreachable,
        'Ich erreiche den Server gerade nicht. Versuch es später nochmal.',
      );
    }

    return AccountException(AccountFailure.unknown, error.message);
  }
}
