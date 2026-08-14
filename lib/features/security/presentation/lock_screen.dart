import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../core/security/app_lock.dart';
import '../../../shared/widgets/big_action_button.dart';

/// Der Bildschirm beim Öffnen der App (Konzept, Abschnitt 13).
///
/// **Eine Hürde, nicht sieben.** Es wird einmal authentifiziert; danach ist
/// alles frei nutzbar. Biometrie wird von selbst versucht, die PIN ist die
/// Rückfallebene.
class LockScreen extends StatefulWidget {
  const LockScreen({required this.onUnlocked, super.key});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _triedBiometrics = false;

  /// Ob gerade der Wiederherstellungs-Code gefragt wird statt der PIN.
  bool _recovery = false;

  /// Ob überhaupt Codes hinterlegt sind – sonst wäre der Weg ein leeres
  /// Versprechen und der Knopf bleibt weg.
  bool _hasRecovery = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_triedBiometrics) return;
    _triedBiometrics = true;

    unawaited(_readRecovery());

    // Nur, wenn der User Biometrie auch will. Wer sie in den Einstellungen
    // abgeschaltet hat, soll nicht bei jedem Start das Systemfenster sehen.
    if (AppScope.of(context).settings.current.usesBiometrics) {
      unawaited(_tryBiometrics());
    }
  }

  Future<void> _readRecovery() async {
    final remaining = await AppScope.of(context).lock.remainingRecoveryCodes;
    if (mounted) setState(() => _hasRecovery = remaining > 0);
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _tryBiometrics() async {
    final result = await AppScope.of(context).lock.unlockWithBiometrics();
    if (!mounted) return;

    if (result == UnlockResult.success) {
      widget.onUnlocked();
    }
    // Alles andere führt still auf die PIN. Kein Fehlertext – der User hat
    // nichts falsch gemacht.
  }

  Future<void> _submit() async {
    final lock = AppScope.of(context).lock;
    final input = _pin.text.trim();

    final result = _recovery
        ? await lock.unlockWithRecoveryCode(input)
        : await lock.unlockWithPin(input);
    if (!mounted) return;

    switch (result) {
      case UnlockResult.success:
        widget.onUnlocked();
      case UnlockResult.failed:
        setState(() {
          _error = _recovery
              ? 'Dieser Code passt nicht – oder er ist schon verbraucht.'
              : 'Das war nicht die richtige PIN.';
          _pin.clear();
        });
      case UnlockResult.unavailable:
      case UnlockResult.cancelled:
        setState(
          () => _error = _recovery
              ? 'Es sind keine Wiederherstellungs-Codes hinterlegt.'
              : 'Es ist keine PIN hinterlegt.',
        );
    }
  }

  void _toggleRecovery() {
    setState(() {
      _recovery = !_recovery;
      _error = null;
      _pin.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Text(
                'Neurohelp',
                key: const Key('lock_logo'),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              if (_recovery) ...[
                Text(
                  'Trag einen deiner Wiederherstellungs-Codes ein. Jeder '
                  'funktioniert genau einmal.',
                  key: const Key('lock_recovery_hint'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('lock_pin'),
                controller: _pin,
                // Der Code wird vom Zettel abgetippt – verdeckt wäre er nicht
                // zu kontrollieren, und geheim halten muss man ihn beim
                // Eintippen ohnehin selbst.
                obscureText: !_recovery,
                keyboardType: _recovery
                    ? TextInputType.text
                    : TextInputType.number,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: _recovery ? 'Wiederherstellungs-Code' : 'PIN',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() => _error = null),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('lock_error'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const Spacer(flex: 3),
              BigActionButton(
                key: const Key('lock_submit'),
                label: 'Entsperren',
                onPressed: _pin.text.trim().isEmpty ? null : _submit,
              ),
              const SizedBox(height: 8),
              if (!_recovery &&
                  AppScope.of(context).settings.current.usesBiometrics)
                TextButton(
                  key: const Key('lock_biometrics'),
                  onPressed: _tryBiometrics,
                  child: const Text('Fingerabdruck oder Gesicht'),
                ),
              // Der Weg zurück, wenn nichts mehr geht. Er steht nur da, wenn
              // es ihn wirklich gibt.
              if (_hasRecovery)
                TextButton(
                  key: const Key('lock_recovery'),
                  onPressed: _toggleRecovery,
                  child: Text(
                    _recovery
                        ? 'Doch die PIN eingeben'
                        : 'PIN vergessen? Wiederherstellungs-Code nutzen',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
