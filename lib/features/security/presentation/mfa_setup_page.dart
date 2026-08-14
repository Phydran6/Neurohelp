import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/account/account_repository.dart';
import '../../../core/di/app_services.dart';
import '../../../core/security/recovery_codes.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/error_details.dart';
import '../domain/security_backup.dart';

/// Wo die Einrichtung gerade steht.
enum _Phase {
  /// Der Schlüssel wird beim Backend geholt.
  loading,

  /// Schlüssel anzeigen, Code abtippen.
  enroll,

  /// Geschafft – jetzt kommt das, was der User wegsichern muss.
  backup,
}

/// Zwei-Faktor-Anmeldung einrichten (Konzept, Abschnitt 13).
///
/// Der Ablauf ist bewusst kurz: Schlüssel anzeigen, in die Authenticator-App
/// übernehmen, einmal den Sechsstelligen abtippen. Danach – und das ist der
/// Teil, der vorher fehlte – bekommt der User seine Sicherung: den Schlüssel
/// und einen Satz Wiederherstellungs-Codes, **als Datei zum Mitnehmen**.
///
/// Ohne das war die Zusatzsicherheit eine Einbahnstraße: Wer sein Handy
/// verlor, verlor den zweiten Faktor und hatte keinen Weg zurück. Genau davor
/// warnt das Konzept mit dem Wiederherstellungs-Code.
class MfaSetupPage extends StatefulWidget {
  const MfaSetupPage({super.key});

  @override
  State<MfaSetupPage> createState() => _MfaSetupPageState();
}

class _MfaSetupPageState extends State<MfaSetupPage> {
  final _code = TextEditingController();

  _Phase _phase = _Phase.loading;
  MfaEnrollment? _enrollment;
  List<String> _recoveryCodes = const [];
  Account? _account;

  bool _busy = false;
  bool _started = false;
  String? _error;
  String? _technical;
  String? _note;

  @override
  void initState() {
    super.initState();
    _code.addListener(_onCodeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Genau einmal: `didChangeDependencies` läuft auch bei jedem Themenwechsel
    // und jeder Größenänderung erneut. Vorher hing der Schutz allein daran,
    // dass noch kein Schlüssel da war – während des Ladens war das nicht der
    // Fall, und das Backend legte stillschweigend einen zweiten Faktor an.
    if (_started) return;
    _started = true;
    unawaited(_start());
  }

  void _onCodeChanged() => setState(() {});

  @override
  void dispose() {
    _code.removeListener(_onCodeChanged);
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final services = AppScope.of(context);
    try {
      final enrollment = await services.account.startMfaEnrollment();
      final account = await services.account.currentAccount();
      if (!mounted) return;

      setState(() {
        _enrollment = enrollment;
        _account = account;
        _phase = _Phase.enroll;
      });
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.details ?? 'Das hat gerade nicht geklappt.';
        _technical = error.technical;
      });
    }
  }

  Future<void> _confirm() async {
    final enrollment = _enrollment;
    if (enrollment == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
      _technical = null;
    });

    try {
      await AppScope.of(context).account.confirmMfaEnrollment(
        factorId: enrollment.factorId,
        code: _code.text,
      );
      if (!mounted) return;

      // Erst jetzt Codes erzeugen: Vor der Bestätigung wäre nicht sicher, ob
      // der zweite Faktor überhaupt steht.
      final generated = RecoveryCodes.generate();
      await AppScope.of(context).lock.setRecoveryCodes(generated.stored);
      if (!mounted) return;

      setState(() {
        _busy = false;
        _recoveryCodes = generated.plain;
        _phase = _Phase.backup;
      });
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.details ?? 'Der Code hat nicht gepasst.';
        _technical = error.technical;
      });
    }
  }

  SecurityBackup _backup() => SecurityBackup(
    createdAt: DateTime.now(),
    accountEmail: _account?.email,
    totpSecret: _enrollment?.secret,
    totpUri: _enrollment?.uri,
    recoveryCodes: _recoveryCodes,
  );

  /// Die Datei herausgeben. Das ist der eigentliche Weg – Abschreiben vom
  /// Bildschirm passiert in der Praxis nicht.
  Future<void> _saveFile() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    try {
      final backup = _backup();
      await AppScope.of(context).files.save(
        fileName: backup.fileName,
        content: backup.toText(),
        subject: 'Neurohelp – Sicherung für deinen Zugang',
        origin: origin,
      );
      if (!mounted) return;
      setState(
        () => _note =
            'Sicherung ist raus. Leg sie irgendwo hin, wo du '
            'sie wiederfindest.',
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _note =
            'Das Speichern hat nicht geklappt. Du kannst den Text stattdessen '
            'kopieren.';
        _technical = '$error';
      });
    }
  }

  Future<void> _copy(String text, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _note = confirmation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _phase == _Phase.backup
              ? 'Deine Sicherung'
              : 'Zwei-Faktor einrichten',
        ),
        // Auf dem Sicherungs-Bildschirm gibt es kein stilles Zurück: Die Codes
        // sind hier zum einzigen Mal zu sehen.
        automaticallyImplyLeading: _phase != _Phase.backup,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: switch (_phase) {
            _Phase.loading => _loadingBody(),
            _Phase.enroll => _enrollBody(),
            _Phase.backup => _backupBody(),
          },
        ),
      ),
    );
  }

  Widget _loadingBody() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          // Kein Ladekringel: Der flackert nur und hängt in Widget-Tests.
          _error ?? 'Ich hole gerade den Schlüssel …',
          key: const Key('mfa_status'),
          style: theme.textTheme.bodyLarge,
        ),
        if (_technical != null) ...[
          const SizedBox(height: 12),
          ErrorDetails(technical: _technical!),
        ],
      ],
    );
  }

  Widget _enrollBody() {
    final theme = Theme.of(context);
    final enrollment = _enrollment!;

    return ListView(
      children: [
        Text(
          'Trag diesen Schlüssel in deine Authenticator-App ein (zum Beispiel '
          'Google Authenticator, Aegis oder den Passwort-Manager, den du '
          'sowieso nutzt).',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                enrollment.secret,
                key: const Key('mfa_secret'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: const Key('mfa_copy'),
                    onPressed: () =>
                        _copy(enrollment.secret, 'Schlüssel kopiert.'),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Kopieren'),
                  ),
                  // Der Schlüssel muss aus der App herauskommen können, bevor
                  // die Einrichtung durch ist – wer hier abbricht, hätte ihn
                  // sonst gesehen und verloren.
                  TextButton.icon(
                    key: const Key('mfa_save_key'),
                    onPressed: _saveFile,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Als Datei sichern'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_note != null) ...[
          const SizedBox(height: 12),
          Text(
            _note!,
            key: const Key('mfa_note'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Und jetzt einmal die sechs Ziffern, die deine App anzeigt.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('mfa_code'),
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Code',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          onSubmitted: (_) => _confirm(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const Key('mfa_error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (_technical != null) ...[
            const SizedBox(height: 8),
            ErrorDetails(technical: _technical!),
          ],
        ],
        const SizedBox(height: 24),
        BigActionButton(
          key: const Key('mfa_confirm'),
          label: 'Fertig',
          onPressed: _busy || _code.text.trim().length < 6 ? null : _confirm,
        ),
      ],
    );
  }

  Widget _backupBody() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              Text(
                'Zwei-Faktor steht.',
                key: const Key('mfa_done'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Sicher jetzt die Datei weg. Sie enthält deinen Schlüssel und '
                'zehn Wiederherstellungs-Codes. Damit kommst du zurück, wenn '
                'dein Handy weg ist – ohne sie ist der Zugang dann zu.\n\n'
                'Diese Codes siehst du nur dieses eine Mal.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final code in _recoveryCodes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SelectableText(
                          code,
                          key: Key('mfa_recovery_$code'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Jeder Code funktioniert genau einmal.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_note != null) ...[
                const SizedBox(height: 16),
                Text(
                  _note!,
                  key: const Key('mfa_note'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (_technical != null) ...[
                  const SizedBox(height: 8),
                  ErrorDetails(technical: _technical!),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        BigActionButton(
          key: const Key('mfa_save_backup'),
          label: 'Sicherung speichern',
          icon: Icons.download_outlined,
          onPressed: _saveFile,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const Key('mfa_copy_backup'),
          onPressed: () =>
              _copy(_backup().toText(), 'Sicherung in die Zwischenablage.'),
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Stattdessen kopieren'),
        ),
        TextButton(
          key: const Key('mfa_backup_done'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Hab ich – weiter'),
        ),
      ],
    );
  }
}
