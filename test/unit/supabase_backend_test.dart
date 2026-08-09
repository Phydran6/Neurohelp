import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/account/account_repository.dart';
import 'package:neurohelp/core/account/data/supabase_account_repository.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/ai/data/supabase_ai_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Ein Client ohne echtes Projekt. Die hier geprüften Wege gehen nie ins
  // Netz – sie brechen vorher ab.
  final client = SupabaseClient(
    'https://beispiel.supabase.co',
    'sb_publishable_test',
  );

  group('SupabaseAccountRepository', () {
    final repository = SupabaseAccountRepository(client);

    Future<AccountException> failureOf(Future<void> Function() action) async {
      try {
        await action();
      } on AccountException catch (error) {
        return error;
      }
      fail('Es wurde keine AccountException geworfen.');
    }

    test('ohne Anmeldung gibt es kein Konto', () async {
      expect(await repository.currentAccount(), isNull);
    });

    test('meckert ruhig über einen zu kurzen Benutzernamen', () async {
      final error = await failureOf(
        () => repository.signUp(
          username: 'ab',
          email: 'a@b.test',
          password: 'geheim1234',
        ),
      );

      expect(error.failure, AccountFailure.invalidInput);
      expect(error.details, contains('3 Zeichen'));
    });

    test('meckert ruhig über eine kaputte E-Mail', () async {
      final error = await failureOf(
        () => repository.signUp(
          username: 'philipp',
          email: 'keine-mail',
          password: 'geheim1234',
        ),
      );

      expect(error.failure, AccountFailure.invalidInput);
    });

    test('meckert ruhig über ein zu kurzes Passwort', () async {
      final error = await failureOf(
        () => repository.signUp(
          username: 'philipp',
          email: 'a@b.test',
          password: 'kurz',
        ),
      );

      expect(error.failure, AccountFailure.invalidInput);
      expect(error.details, contains('8 Zeichen'));

      // Kein Vorwurf, keine technische Fehlerkette.
      expect(error.details, isNot(contains('Error')));
    });
  });

  group('SupabaseAiClient', () {
    test('ausgeschaltet heißt: kein Aufruf, keine Ausnahme nach außen', () {
      final ai = SupabaseAiClient(client, enabled: false);

      expect(ai.isEnabled, isFalse);
      expect(
        () => ai.run(AiTask.splitTask, input: 'egal'),
        throwsA(isA<AiUnavailableException>()),
      );
    });

    test('eingeschaltet meldet sich als nutzbar', () {
      expect(SupabaseAiClient(client, enabled: true).isEnabled, isTrue);
    });
  });
}
