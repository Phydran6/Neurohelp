import 'package:flutter/material.dart';

import '../../../core/account/account_repository.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../core/settings/app_settings.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../domain/onboarding_flow.dart';

/// Das Onboarding (Konzept, Abschnitt 16).
///
/// Fünf Schritte, einer pro Bildschirm. KI-Toggle und App-Sperre sind
/// **Pflichtentscheidungen** – nur die Zusatzsicherheit ist überspringbar.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  OnboardingFlow _flow = const OnboardingFlow();

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _pin = TextEditingController();

  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Der PIN-Knopf ist gesperrt, solange die PIN zu kurz ist. Ohne diesen
    // Listener merkt der Knopf die Eingabe nicht.
    _pin.addListener(_onPinChanged);
  }

  void _onPinChanged() => setState(() {});

  @override
  void dispose() {
    _pin.removeListener(_onPinChanged);
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _advance() {
    setState(() {
      _error = null;
      _flow = _flow.advance();
    });
  }

  Future<void> _createAccount() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AppScope.of(context).account.signUp(
        username: _username.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _flow = _flow.withAccountCreated();
        _busy = false;
      });
      _advance();
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.details ?? 'Das hat nicht geklappt.';
      });
    }
  }

  Future<void> _setPin() async {
    final lock = AppScope.of(context).lock;
    try {
      await lock.setPin(_pin.text);
    } on ArgumentError catch (error) {
      setState(() => _error = error.message.toString());
      return;
    }

    final biometric = await lock.isBiometricAvailable;
    if (!mounted) return;

    setState(() {
      _error = null;
      _flow = _flow.withLockMethod(
        biometric ? LockMethod.biometric : LockMethod.pin,
      );
    });
    _advance();
  }

  Future<void> _finish(AiTone tone) async {
    final flow = _flow.withTone(tone);
    if (!flow.isComplete) return;

    final settings = AppScope.of(context).settings;
    final chosen = flow.toSettings();

    await settings.setAiEnabled(enabled: chosen.aiEnabled);
    await settings.setTone(chosen.tone);
    await settings.setLockMethod(chosen.lockMethod);
    await settings.setOnboardingCompleted(completed: true);

    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _title(_flow.step),
                key: const Key('onb_title'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                _hint(_flow.step),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  key: const Key('onb_error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(child: SingleChildScrollView(child: _body())),
              const SizedBox(height: 16),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (_flow.step) {
    OnboardingStep.account => Column(
      children: [
        TextField(
          key: const Key('onb_username'),
          controller: _username,
          decoration: const InputDecoration(labelText: 'Benutzername'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('onb_email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-Mail'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('onb_password'),
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Passwort'),
        ),
      ],
    ),
    OnboardingStep.aiChoice => const SizedBox.shrink(),
    OnboardingStep.security => TextField(
      key: const Key('onb_pin'),
      controller: _pin,
      obscureText: true,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'PIN'),
    ),
    OnboardingStep.extraSecurity => const SizedBox.shrink(),
    OnboardingStep.tone => const SizedBox.shrink(),
  };

  Widget _actions() => switch (_flow.step) {
    OnboardingStep.account => BigActionButton(
      key: const Key('onb_create'),
      label: 'Konto anlegen',
      onPressed: _busy ? null : _createAccount,
    ),
    // Pflichtentscheidung: zwei gleichwertige Knöpfe, keine Voreinstellung.
    OnboardingStep.aiChoice => Column(
      children: [
        BigActionButton(
          key: const Key('onb_ai_yes'),
          label: 'Ja, KI nutzen',
          onPressed: () {
            setState(() => _flow = _flow.withAiChoice(enabled: true));
            _advance();
          },
        ),
        const SizedBox(height: 12),
        BigActionButton(
          key: const Key('onb_ai_no'),
          label: 'Nein, alles lokal',
          onPressed: () {
            setState(() => _flow = _flow.withAiChoice(enabled: false));
            _advance();
          },
        ),
      ],
    ),
    OnboardingStep.security => BigActionButton(
      key: const Key('onb_pin_save'),
      label: 'PIN setzen',
      onPressed: _pin.text.trim().length < 4 ? null : _setPin,
    ),
    // Der einzige überspringbare Schritt.
    OnboardingStep.extraSecurity => Column(
      children: [
        BigActionButton(
          key: const Key('onb_extra_skip'),
          label: 'Später',
          onPressed: () => setState(() => _flow = _flow.skip()),
        ),
      ],
    ),
    OnboardingStep.tone => Column(
      children: [
        for (final tone in AiTone.values) ...[
          BigActionButton(
            key: Key('onb_tone_${tone.name}'),
            label: _toneLabel(tone),
            onPressed: () => _finish(tone),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  };

  static String _title(OnboardingStep step) => switch (step) {
    OnboardingStep.account => 'Erst ein Konto',
    OnboardingStep.aiChoice => 'Willst du KI nutzen?',
    OnboardingStep.security => 'Eine PIN für die App',
    OnboardingStep.extraSecurity => 'Noch mehr Sicherheit?',
    OnboardingStep.tone => 'Wie soll ich mit dir reden?',
  };

  static String _hint(OnboardingStep step) => switch (step) {
    OnboardingStep.account =>
      'Damit du dich wieder anmelden kannst, wenn du das Gerät wechselst. '
          'Deine Inhalte bleiben trotzdem auf dem Gerät.',
    OnboardingStep.aiChoice =>
      'Mit KI formuliere ich Texte für dich und zerlege Aufgaben. Dafür '
          'gehen diese Texte über unser Backend zum Anbieter.\n\n'
          'Ohne KI läuft alles auf deinem Gerät. Der Rest der App bleibt '
          'gleich. Du kannst das jederzeit ändern.',
    OnboardingStep.security =>
      'Einmal beim Öffnen, danach ist alles frei nutzbar. Wenn dein Gerät '
          'Fingerabdruck oder Gesichtsscan kann, nehme ich das – die PIN ist '
          'die Rückfallebene.',
    OnboardingStep.extraSecurity =>
      'Zwei-Faktor und Wiederherstellungs-Code kannst du später in den '
          'Einstellungen einrichten. Jetzt ist nichts davon nötig.',
    OnboardingStep.tone => 'Änderbar, wann immer du willst.',
  };

  static String _toneLabel(AiTone tone) => switch (tone) {
    AiTone.locker => 'Locker – „Hey, was steht an?"',
    AiTone.neutral => 'Neutral – „Hallo. Womit kann ich helfen?"',
    AiTone.sachlich => 'Sachlich – „Auswahl treffen."',
  };
}
