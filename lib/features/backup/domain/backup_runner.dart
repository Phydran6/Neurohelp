import '../../../core/backup/backup_codec.dart';
import '../../../core/backup/backup_document.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/backup/backup_vault.dart';
import '../../../core/di/app_services.dart';
import '../../../core/logging/app_logger.dart';

/// Wie ein Sicherungsvorgang ausgegangen ist.
///
/// Immer ein Satz, der auf den Bildschirm darf, und optional das
/// Kleingedruckte dazu. Kein nackter `bool`: „hat nicht geklappt" ohne Grund
/// ist für den User dasselbe wie eine kaputte App.
class BackupOutcome {
  const BackupOutcome({
    required this.ok,
    required this.message,
    this.technical,
    this.report,
  });

  const BackupOutcome.done(this.message, {this.report})
    : ok = true,
      technical = null;

  const BackupOutcome.failed(this.message, {this.technical})
    : ok = false,
      report = null;

  final bool ok;
  final String message;
  final String? technical;

  /// Was eingespielt wurde – nur beim Wiederherstellen gefüllt.
  final RestoreReport? report;
}

/// Die Sicherungswege an einer Stelle, ohne Oberfläche.
///
/// Dieselben vier Vorgänge tauchen an drei Stellen auf: im Einstieg nach der
/// Neuinstallation, in den Einstellungen für Fortgeschrittene und in den
/// Einstellungen für alle anderen. Sie hier zusammenzuhalten heißt, dass alle
/// drei dieselben Sätze sagen.
class BackupRunner {
  const BackupRunner(this._services);

  final AppServices _services;

  /// Datei erzeugen und dem User zum Ablegen anbieten.
  ///
  /// Wohin sie geht, entscheidet er im System-Blatt: Dateien-App, iCloud
  /// Drive, Google Drive, an sich selbst schicken. Die App kennt dabei keinen
  /// einzigen Cloud-Dienst – und muss auch keinen kennen.
  Future<BackupOutcome> exportToFile() async {
    try {
      final document = await _services.backup.create();
      final bytes = BackupCodec.encode(document);
      final fileName = BackupCodec.fileNameFor(document.createdAt);

      await _services.files.saveBytes(
        fileName: fileName,
        bytes: bytes,
        mimeType: BackupCodec.mimeType,
        subject: 'Neurohelp – Sicherung',
      );
      await _services.settings.setLastBackupAt(document.createdAt);

      return BackupOutcome.done(
        'Die Datei heißt $fileName und enthält ${document.rowCount} '
        'Einträge. Leg sie irgendwohin, wo du sie wiederfindest – eine '
        'Cloud, ein Mailanhang an dich selbst, ein Stick. Beim nächsten Mal '
        'kannst du sie hier wieder einlesen.',
      );
    } on Exception catch (error, stackTrace) {
      return _failure(
        'Die Sicherung ließ sich nicht erzeugen.',
        error,
        stackTrace,
      );
    }
  }

  /// Datei am Standardplatz ablegen – ohne dass der User etwas entscheiden
  /// muss.
  Future<BackupOutcome> backUpToVault() async {
    try {
      final stored = await _services.backUpToVault();
      return BackupOutcome.done(
        'Gesichert. Die Datei liegt an einem Ort, den dein Telefon in seine '
        'eigene Sicherung mitnimmt – ${stored.sizeLabel}. Wenn du die App '
        'neu installierst, frage ich beim ersten Start danach.',
      );
    } on Exception catch (error, stackTrace) {
      return _failure(
        'Die Sicherung ließ sich nicht ablegen. Auf dem Gerät ist '
        'vielleicht kein Platz mehr.',
        error,
        stackTrace,
      );
    }
  }

  /// Was am Standardplatz liegt – oder `null`.
  Future<StoredBackup?> findInVault() => _services.vault.latest();

  /// Die Sicherung vom Standardplatz einspielen.
  Future<BackupOutcome> restoreFromVault({
    RestoreMode mode = RestoreMode.replace,
  }) async {
    final stored = await findInVault();
    if (stored == null) {
      return const BackupOutcome.failed(
        'Am Standardplatz liegt nichts. Wenn du eine Sicherungsdatei hast, '
        'nimm den anderen Weg.',
      );
    }

    try {
      final bytes = await _services.vault.read(stored.path);
      return _restore(BackupCodec.decode(bytes), mode: mode);
    } on BackupFormatException catch (error) {
      return BackupOutcome.failed(error.reason, technical: error.technical);
    } on Exception catch (error, stackTrace) {
      return _failure('Die Datei ließ sich nicht lesen.', error, stackTrace);
    }
  }

  /// Eine Datei vom User auswählen lassen und einspielen.
  ///
  /// `null` heißt: abgebrochen. Kein Fehler, keine Meldung.
  Future<BackupOutcome?> restoreFromPickedFile({
    RestoreMode mode = RestoreMode.replace,
  }) async {
    final picked = await _services.fileOpener.pick(
      extensions: BackupCodec.knownExtensions,
    );
    if (picked == null) return null;

    try {
      return _restore(BackupCodec.decode(picked.bytes), mode: mode);
    } on BackupFormatException catch (error) {
      return BackupOutcome.failed(error.reason, technical: error.technical);
    } on Exception catch (error, stackTrace) {
      return _failure('Die Datei ließ sich nicht lesen.', error, stackTrace);
    }
  }

  Future<BackupOutcome> _restore(
    BackupDocument document, {
    required RestoreMode mode,
  }) async {
    try {
      final report = await _services.backup.restore(document, mode: mode);

      // Die eingespielten Einstellungen müssen sofort ankommen: Ton, Theme
      // und KI-Schalter stehen mit in der Sicherung.
      await _services.settings.load();

      return BackupOutcome.done(_summaryOf(report), report: report);
    } on Exception catch (error, stackTrace) {
      return _failure(
        'Beim Einspielen ist etwas schiefgegangen. Deine bisherigen Sachen '
        'sind dadurch nicht verloren.',
        error,
        stackTrace,
      );
    }
  }

  static String _summaryOf(RestoreReport report) {
    final rows = report.rowCount;
    final base = rows == 0
        ? 'Die Sicherung war leer – es gab nichts einzuspielen.'
        : 'Fertig. $rows Einträge sind wieder da: deine Historie, deine '
              'Vorgänge und deine Einstellungen.';

    if (report.isComplete) {
      return '$base\n\nDie App-Sperre ist bewusst nicht mit dabei. Die '
          'richtest du gleich neu ein – eine Sicherungsdatei, die deine PIN '
          'enthält, wäre keine gute Idee.';
    }

    final missing = [
      if (report.skippedTables.isNotEmpty)
        'Teile aus einer neueren Version der App '
            '(${report.skippedTables.join(', ')})',
      if (report.skippedRows > 0) '${report.skippedRows} einzelne Einträge',
    ].join(' und ');

    return '$base\n\nNicht übernommen wurden: $missing. Wenn dir etwas '
        'Wichtiges fehlt, schreib mir – im Hilfe-Bereich steht, wie.';
  }

  static BackupOutcome _failure(
    String message,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.error(
      message,
      scope: 'backup',
      error: error,
      stackTrace: stackTrace,
    );
    return BackupOutcome.failed(message, technical: error.toString());
  }
}
