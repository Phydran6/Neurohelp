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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_triedBiometrics) return;
    _triedBiometrics = true;

    // Nur, wenn der User Biometrie auch will. Wer sie in den Einstellungen
    // abgeschaltet hat, soll nicht bei jedem Start das Systemfenster sehen.
    if (AppScope.of(context).settings.current.usesBiometrics) {
      unawaited(_tryBiometrics());
    }
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

  Future<void> _submitPin() async {
    final result = await AppScope.of(
      context,
    ).lock.unlockWithPin(_pin.text.trim());
    if (!mounted) return;

    switch (result) {
      case UnlockResult.success:
        widget.onUnlocked();
      case UnlockResult.failed:
        setState(() {
          _error = 'Das war nicht die richtige PIN.';
          _pin.clear();
        });
      case UnlockResult.unavailable:
      case UnlockResult.cancelled:
        setState(() => _error = 'Es ist keine PIN hinterlegt.');
    }
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
              TextField(
                key: const Key('lock_pin'),
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submitPin(),
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
                onPressed: _pin.text.trim().isEmpty ? null : _submitPin,
              ),
              const SizedBox(height: 8),
              if (AppScope.of(context).settings.current.usesBiometrics)
                TextButton(
                  key: const Key('lock_biometrics'),
                  onPressed: _tryBiometrics,
                  child: const Text('Fingerabdruck oder Gesicht'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
