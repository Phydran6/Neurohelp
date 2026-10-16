import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/backup/backup_codec.dart';
import 'package:neurohelp/core/backup/backup_document.dart';

/// Prüft das Dateiformat der Sicherung.
///
/// Der Punkt dieser Tests: Eine Sicherungsdatei ist das Einzige, was eine
/// Neuinstallation überlebt. Wenn sie sich nicht mehr lesen lässt, sind die
/// Daten weg – und zwar genau in dem Moment, in dem jemand sie braucht.
void main() {
  BackupDocument sample({DateTime? createdAt}) => BackupDocument(
    schemaVersion: 6,
    appVersion: '0.1.0-alpha.10',
    createdAt: createdAt ?? DateTime(2026, 9, 22, 14, 30),
    tables: {
      'history_entries': [
        {'id': 'a', 'title': 'Brief an die Kasse', 'follow_up_count': 0},
      ],
      'settings': [
        {'key': 'tone', 'value': 'locker', 'updated_at': 17},
      ],
    },
  );

  group('BackupDocument', () {
    test('kommt durch JSON unverändert wieder heraus', () {
      final original = sample();
      final back = BackupDocument.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      );

      expect(back.schemaVersion, original.schemaVersion);
      expect(back.appVersion, original.appVersion);
      expect(back.createdAt, original.createdAt);
      expect(
        back.tables['history_entries']!.single['title'],
        'Brief an die Kasse',
      );
      expect(back.rowCount, 2);
    });

    test('zählt Zeilen je Tabelle, leere Tabellen weggelassen', () {
      final document = BackupDocument(
        schemaVersion: 6,
        appVersion: 'x',
        createdAt: DateTime(2026),
        tables: {
          'history_entries': [
            {'id': 'a'},
          ],
          'calls': const [],
        },
      );

      expect(document.rowCounts, {'history_entries': 1});
    });

    test('erkennt eine fremde Datei', () {
      expect(
        () => BackupDocument.fromJson({'format': 'irgendwas'}),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.problem,
            'problem',
            BackupProblem.notABackup,
          ),
        ),
      );
    });

    test('erkennt eine beschädigte Datei an der Prüfsumme', () {
      final json = sample().toJson();
      // Eine Zeile verschwindet unterwegs – genau der Fall, den ein nackter
      // Vergleich „ist es JSON?" nicht bemerkt.
      (json['tables']! as Map<String, Object?>)['settings'] = const [];

      expect(
        () => BackupDocument.fromJson(json),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.problem,
            'problem',
            BackupProblem.damaged,
          ),
        ),
      );
    });

    test('sagt Bescheid, wenn die Datei aus einer neueren App stammt', () {
      final json = sample().toJson()..['formatVersion'] = 99;

      expect(
        () => BackupDocument.fromJson(json),
        throwsA(
          isA<BackupFormatException>()
              .having((error) => error.problem, 'problem', BackupProblem.tooNew)
              .having(
                (error) => error.reason,
                'reason',
                contains('Aktualisiere die App'),
              ),
        ),
      );
    });

    test('übersteht fehlende Kopfangaben, statt aufzugeben', () {
      // Eine von Hand zusammengebaute Datei ohne Versionsangaben soll sich
      // trotzdem einspielen lassen – die Daten sind ja da.
      final document = BackupDocument.fromJson({
        'format': BackupDocument.format,
        'tables': {
          'history_entries': [
            {'id': 'a'},
          ],
        },
      });

      expect(document.rowCount, 1);
      expect(document.appVersion, 'unbekannt');
    });
  });

  group('BackupCodec', () {
    test('packt und entpackt wieder', () {
      final bytes = BackupCodec.encode(sample());
      final back = BackupCodec.decode(bytes);

      expect(back.rowCount, 2);
      expect(back.appVersion, '0.1.0-alpha.10');
    });

    test('packt spürbar kleiner als reines JSON', () {
      final document = BackupDocument(
        schemaVersion: 6,
        appVersion: 'x',
        createdAt: DateTime(2026),
        tables: {
          'history_entries': [
            for (var i = 0; i < 200; i++)
              {'id': 'eintrag-$i', 'title': 'Immer derselbe lange Titel'},
          ],
        },
      );

      final packed = BackupCodec.encode(document).length;
      final plain = utf8.encode(jsonEncode(document.toJson())).length;
      expect(packed, lessThan(plain ~/ 2));
    });

    test('nimmt auch ungepacktes JSON an', () {
      // Manche Mail- und Cloud-Programme packen Anhänge unterwegs selbst aus.
      final plain = utf8.encode(jsonEncode(sample().toJson()));
      expect(BackupCodec.decode(plain).rowCount, 2);
    });

    test('meldet eine leere Datei als beschädigt', () {
      expect(
        () => BackupCodec.decode(Uint8List(0)),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('meldet abgeschnittene gepackte Daten, statt stumm zu scheitern', () {
      final bytes = BackupCodec.encode(sample());
      final cut = bytes.sublist(0, bytes.length ~/ 2);

      expect(
        () => BackupCodec.decode(cut),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.problem,
            'problem',
            BackupProblem.damaged,
          ),
        ),
      );
    });

    test('der Dateiname trägt das Datum, damit nichts überschrieben wird', () {
      final name = BackupCodec.fileNameFor(DateTime(2026, 9, 22, 8, 5));
      expect(name, 'neurohelp-sicherung-2026-09-22-0805.nhbackup');
    });
  });
}
