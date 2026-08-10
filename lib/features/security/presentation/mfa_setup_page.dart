import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/account/account_repository.dart';
import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/error_details.dart';

/// Zwei-Faktor-Anmeldung einrichten (Konzept, Abschnitt 13).
///
/// Freiwillig, aber echt: Vorher stand im Onboarding nur ein „Später"-Knopf
/// und sonst nichts – die Zusatzsicherheit war ein leeres Versprechen.
///
/// Der Ablauf ist bewusst kurz: Schlüssel anzeigen, in die Authenticator-App
/// übernehmen, einmal den Sechsstelligen abtippen. Fertig.
class MfaSetupPage extends StatefulWidget {
  const MfaSetupPage({super.key});

  @override
  State<MfaSetupPage> createState() => _MfaSetupPageState();
}

class _MfaSetupPageState extends State<MfaSetupPage> {
  final _code = TextEditingController();

  MfaEnrollment? _enrollment;
  bool _busy = true;
  String? _error;
  String? _technical;

  @override
  void initState() {
    super.initState();
    _code.addListener(_onCodeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enrollment == null && _error == null) unawaited(_start());
  }

  void _onCodeChanged() => setState(() {});

  @override
  void dispose() {
    _code.removeListener(_onCodeChanged);
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final enrollment = await AppScope.of(
        context,
      ).account.startMfaEnrollment();
      if (!mounted) return;
      setState(() {
        _enrollment = enrollment;
        _busy = false;
      });
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
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
      Navigator.of(context).pop(true);
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.details ?? 'Der Code hat nicht gepasst.';
        _technical = error.technical;
      });
    }
  }

  Future<void> _copySecret() async {
    final secret = _enrollment?.secret;
    if (secret == null) return;

    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Schlüssel kopiert.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enrollment = _enrollment;

    return Scaffold(
      appBar: AppBar(title: const Text('Zwei-Faktor einrichten')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: enrollment == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _error ?? 'Ich hole gerade den Schlüssel …',
                      key: const Key('mfa_status'),
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (_technical != null) ...[
                      const SizedBox(height: 12),
                      ErrorDetails(technical: _technical!),
                    ],
                  ],
                )
              : ListView(
                  children: [
                    Text(
                      'Trag diesen Schlüssel in deine Authenticator-App ein '
                      '(zum Beispiel Google Authenticator, Aegis oder den '
                      'Passwort-Manager, den du sowieso nutzt).',
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
                          TextButton.icon(
                            key: const Key('mfa_copy'),
                            onPressed: _copySecret,
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Schlüssel kopieren'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Und jetzt einmal die sechs Ziffern, die deine App '
                      'anzeigt.',
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
                      onPressed: _busy || _code.text.trim().length < 6
                          ? null
                          : _confirm,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
