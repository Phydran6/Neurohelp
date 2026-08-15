import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/account/account_repository.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../core/settings/app_settings.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/error_details.dart';
import '../../security/presentation/mfa_setup_page.dart';
import '../domain/intro_slides.dart';
import '../domain/onboarding_flow.dart';
import 'intro_slide_view.dart';

/// Was auf dem Konto-Bildschirm gerade dran ist.
///
/// Alles auf **einem** Bildschirm statt in einem Menü davor: Der Normalfall
/// (neues Konto) steht offen da, die beiden anderen Wege hängen als ruhige
/// Textknöpfe darunter. Wer die App neu installiert, muss nicht suchen.
enum AccountMode {
  /// Neues Konto anlegen – der Normalfall.
  signUp,

  /// Sechsstelliger Code aus der Willkommens-Mail.
  confirmSignUp,

  /// Schon ein Konto vorhanden.
  signIn,

  /// Mail-Adresse für die Reset-Mail.
  forgotPassword,

  /// Code aus der Reset-Mail plus neues Passwort.
  resetPassword,
}

/// Das Onboarding (Konzept, Abschnitt 16).
///
/// Zuerst zwei Erklärbildschirme – was die App kann und wie sie funktioniert.
/// Sie verlangen nichts, kosten zweimal Tippen und ersparen dem User die
/// Frage, worauf er sich hier gerade einlässt.
///
/// Danach fünf Schritte, einer pro Bildschirm. KI-Toggle und App-Sperre sind
/// **Pflichtentscheidungen** – nur die Zusatzsicherheit ist überspringbar,
/// und die sagt beim Überspringen einmal ruhig Bescheid.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  OnboardingFlow _flow = const OnboardingFlow();
  AccountMode _mode = AccountMode.signUp;

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _pin = TextEditingController();

  String? _error;
  String? _technical;
  String? _info;
  bool _busy = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    // Die Knöpfe sind gesperrt, solange zu wenig dasteht. Ohne diese Listener
    // merken sie die Eingabe nicht.
    for (final controller in [_pin, _code, _email, _password, _newPassword]) {
      controller.addListener(_onInputChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_readBiometrics());
  }

  Future<void> _readBiometrics() async {
    final available = await AppScope.of(context).lock.isBiometricAvailable;
    if (mounted && available != _biometricAvailable) {
      setState(() => _biometricAvailable = available);
    }
  }

  void _onInputChanged() => setState(() {});

  @override
  void dispose() {
    for (final controller in [_pin, _code, _email, _password, _newPassword]) {
      controller.removeListener(_onInputChanged);
    }
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _newPassword.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _advance() {
    setState(() {
      _error = null;
      _technical = null;
      _info = null;
      _flow = _flow.advance();
    });
  }

  void _switchTo(AccountMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _technical = null;
      _info = null;
      _code.clear();
    });
  }

  /// Führt eine Konto-Aktion aus und übersetzt Fehler in ruhige Sätze –
  /// samt Details für den Fall, dass jemand sie melden will.
  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _technical = null;
      _info = null;
    });

    try {
      await action();
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.details ?? 'Das hat nicht geklappt.';
        _technical = error.technical;

        // Ein bekanntes Konto ist kein Fehler, sondern der Hinweis auf den
        // richtigen Weg. Also gleich dorthin.
        if (error.failure == AccountFailure.alreadyTaken) {
          _mode = AccountMode.signIn;
        } else if (error.failure == AccountFailure.notConfirmed) {
          _mode = AccountMode.confirmSignUp;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------------- Konto

  Future<void> _createAccount() => _guard(() async {
    final result = await AppScope.of(context).account.signUp(
      username: _username.text,
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;

    if (result.needsConfirmation) {
      setState(() {
        _mode = AccountMode.confirmSignUp;
        _info =
            'Ich habe dir einen sechsstelligen Code an ${_email.text.trim()} '
            'geschickt. Trag ihn hier ein.';
      });
      return;
    }

    setState(() => _flow = _flow.withAccountCreated());
    _advance();
  });

  Future<void> _confirmSignUp() => _guard(() async {
    await AppScope.of(
      context,
    ).account.confirmSignUp(email: _email.text, code: _code.text);
    if (!mounted) return;

    setState(() => _flow = _flow.withAccountCreated());
    _advance();
  });

  Future<void> _resendCode() => _guard(() async {
    await AppScope.of(context).account.resendConfirmation(_email.text);
    if (!mounted) return;
    setState(() => _info = 'Neuer Code ist unterwegs.');
  });

  /// Rückweg für den Fall, dass in der Mail **kein** Code steht.
  ///
  /// Supabase gibt die Mail-Vorlagen erst frei, wenn ein eigener SMTP-Zugang
  /// hinterlegt ist. Bis dahin verschickt es seine Standard-Mail – englisch,
  /// und mit Link statt Code. Ohne diesen Knopf säße der User dann vor einem
  /// Code-Feld, das er nicht füllen kann.
  ///
  /// Der Link öffnet die App über das eingetragene Schema; Supabase legt
  /// dabei die Sitzung an. Hier wird nur nachgesehen, ob sie da ist.
  Future<void> _checkConfirmedByLink() => _guard(() async {
    final account = await AppScope.of(context).account.currentAccount();
    if (!mounted) return;

    if (account == null) {
      setState(
        () => _error =
            'Noch nichts angekommen. Tipp den Link in der Mail an und komm '
            'dann hierher zurück – oder trag den Code ein, falls einer '
            'drinsteht.',
      );
      return;
    }

    setState(() => _flow = _flow.withAccountCreated());
    _advance();
  });

  Future<void> _signIn() => _guard(() async {
    await AppScope.of(
      context,
    ).account.signIn(email: _email.text, password: _password.text);
    if (!mounted) return;

    setState(() => _flow = _flow.withAccountCreated());
    _advance();
  });

  Future<void> _sendReset() => _guard(() async {
    await AppScope.of(context).account.sendPasswordReset(_email.text);
    if (!mounted) return;
    setState(() {
      _mode = AccountMode.resetPassword;
      _info =
          'Falls es zu ${_email.text.trim()} ein Konto gibt, ist der Code '
          'unterwegs. Er gilt eine Stunde.';
    });
  });

  Future<void> _resetPassword() => _guard(() async {
    await AppScope.of(context).account.resetPassword(
      email: _email.text,
      code: _code.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;

    setState(() => _flow = _flow.withAccountCreated());
    _advance();
  });

  // ------------------------------------------------------------------ Sperre

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

  // --------------------------------------------------------------------- MFA

  Future<void> _setUpMfa() async {
    final done = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const MfaSetupPage()));
    if (!mounted) return;

    if (done == true) {
      setState(() => _info = 'Zwei-Faktor steht.');
      _advance();
    }
  }

  /// „Später" – aber einmal mit klarem Hinweis, dass es offen bleibt.
  Future<void> _skipMfa() async {
    final settings = AppScope.of(context).settings;

    if (!settings.current.mfaHintShown) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('onb_mfa_hint'),
          title: const Text('Bleibt offen'),
          content: const Text(
            'Ohne zweiten Faktor hängt dein Konto allein am Passwort. Das '
            'reicht meistens – aber wenn das Passwort irgendwo auftaucht, '
            'reicht es eben nicht mehr.\n\n'
            'Du holst es jederzeit in den Einstellungen nach, unter „Konto". '
            'Ich erinnere nicht noch mal daran.',
          ),
          actions: [
            FilledButton(
              key: const Key('onb_mfa_hint_ok'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Alles klar'),
            ),
          ],
        ),
      );

      await settings.setMfaHintShown(shown: true);
    }

    if (!mounted) return;
    setState(() => _flow = _flow.skip());
  }

  // ------------------------------------------------------------------- Ferti

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

  // -------------------------------------------------------------------- View

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
                _title(),
                key: const Key('onb_title'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                _hint(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (_info != null) ...[
                Text(
                  _info!,
                  key: const Key('onb_info'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_error != null) ...[
                Text(
                  _error!,
                  key: const Key('onb_error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                if (_technical != null) ErrorDetails(technical: _technical!),
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
    OnboardingStep.welcome => const IntroSlideView(
      key: Key('onb_intro_was'),
      slide: IntroSlides.whatItDoes,
    ),
    OnboardingStep.howItWorks => const IntroSlideView(
      key: Key('onb_intro_wie'),
      slide: IntroSlides.howItWorks,
    ),
    OnboardingStep.account => _accountBody(),
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

  Widget _accountBody() {
    final email = TextField(
      key: const Key('onb_email'),
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      decoration: const InputDecoration(labelText: 'E-Mail'),
    );

    final code = TextField(
      key: const Key('onb_code'),
      controller: _code,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: const InputDecoration(
        labelText: 'Code aus der Mail',
        counterText: '',
      ),
    );

    return switch (_mode) {
      AccountMode.signUp => Column(
        children: [
          TextField(
            key: const Key('onb_username'),
            controller: _username,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Benutzername'),
          ),
          const SizedBox(height: 16),
          email,
          const SizedBox(height: 16),
          TextField(
            key: const Key('onb_password'),
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Passwort',
              helperText: 'Mindestens 8 Zeichen',
            ),
          ),
        ],
      ),
      AccountMode.confirmSignUp => Column(
        children: [email, const SizedBox(height: 16), code],
      ),
      AccountMode.signIn => Column(
        children: [
          email,
          const SizedBox(height: 16),
          TextField(
            key: const Key('onb_password'),
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passwort'),
          ),
        ],
      ),
      AccountMode.forgotPassword => email,
      AccountMode.resetPassword => Column(
        children: [
          email,
          const SizedBox(height: 16),
          code,
          const SizedBox(height: 16),
          TextField(
            key: const Key('onb_new_password'),
            controller: _newPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Neues Passwort',
              helperText: 'Mindestens 8 Zeichen',
            ),
          ),
        ],
      ),
    };
  }

  Widget _actions() => switch (_flow.step) {
    OnboardingStep.welcome => BigActionButton(
      key: const Key('onb_intro_next'),
      label: IntroSlides.whatItDoes.action,
      onPressed: _advance,
    ),
    OnboardingStep.howItWorks => Column(
      children: [
        BigActionButton(
          key: const Key('onb_intro_start'),
          label: IntroSlides.howItWorks.action,
          onPressed: _advance,
        ),
        const SizedBox(height: 8),
        // Zurückblättern muss möglich sein: Wer den ersten Bildschirm zu
        // schnell weggetippt hat, soll ihn nicht erst nach dem kompletten
        // Onboarding im Hilfe-Bereich wiederfinden.
        TextButton(
          key: const Key('onb_intro_back'),
          onPressed: () => setState(() => _flow = _flow.back()),
          child: const Text('Nochmal zurück'),
        ),
      ],
    ),
    OnboardingStep.account => _accountActions(),
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
    // Der einzige überspringbare Schritt – aber jetzt mit echtem Inhalt.
    OnboardingStep.extraSecurity => Column(
      children: [
        BigActionButton(
          key: const Key('onb_extra_setup'),
          label: 'Jetzt einrichten',
          onPressed: _busy ? null : _setUpMfa,
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const Key('onb_extra_skip'),
          onPressed: _busy ? null : _skipMfa,
          child: const Text('Später'),
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

  Widget _accountActions() {
    final canConfirm = _code.text.trim().length >= 6;

    return switch (_mode) {
      AccountMode.signUp => Column(
        children: [
          BigActionButton(
            key: const Key('onb_create'),
            label: 'Konto anlegen',
            onPressed: _busy ? null : _createAccount,
          ),
          const SizedBox(height: 8),
          // Die beiden Wege für „ich war schon mal hier". Ruhig, klein,
          // aber vorhanden – vorher gab es sie schlicht nicht.
          TextButton(
            key: const Key('onb_have_account'),
            onPressed: _busy ? null : () => _switchTo(AccountMode.signIn),
            child: const Text('Ich habe schon ein Konto'),
          ),
          TextButton(
            key: const Key('onb_forgot'),
            onPressed: _busy
                ? null
                : () => _switchTo(AccountMode.forgotPassword),
            child: const Text('Passwort vergessen'),
          ),
        ],
      ),
      AccountMode.confirmSignUp => Column(
        children: [
          BigActionButton(
            key: const Key('onb_confirm'),
            label: 'Code prüfen',
            onPressed: _busy || !canConfirm ? null : _confirmSignUp,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('onb_resend'),
            onPressed: _busy ? null : _resendCode,
            child: const Text('Code nochmal schicken'),
          ),
          TextButton(
            key: const Key('onb_confirmed_by_link'),
            onPressed: _busy ? null : _checkConfirmedByLink,
            child: const Text('Kein Code drin? Ich hab den Link angetippt'),
          ),
          TextButton(
            key: const Key('onb_back_to_signup'),
            onPressed: _busy ? null : () => _switchTo(AccountMode.signUp),
            child: const Text('Zurück'),
          ),
        ],
      ),
      AccountMode.signIn => Column(
        children: [
          BigActionButton(
            key: const Key('onb_sign_in'),
            label: 'Anmelden',
            onPressed: _busy ? null : _signIn,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('onb_forgot'),
            onPressed: _busy
                ? null
                : () => _switchTo(AccountMode.forgotPassword),
            child: const Text('Passwort vergessen'),
          ),
          TextButton(
            key: const Key('onb_back_to_signup'),
            onPressed: _busy ? null : () => _switchTo(AccountMode.signUp),
            child: const Text('Doch ein neues Konto'),
          ),
        ],
      ),
      AccountMode.forgotPassword => Column(
        children: [
          BigActionButton(
            key: const Key('onb_send_reset'),
            label: 'Code schicken',
            onPressed: _busy || !_email.text.contains('@') ? null : _sendReset,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('onb_back_to_signup'),
            onPressed: _busy ? null : () => _switchTo(AccountMode.signUp),
            child: const Text('Zurück'),
          ),
        ],
      ),
      AccountMode.resetPassword => Column(
        children: [
          BigActionButton(
            key: const Key('onb_reset'),
            label: 'Neues Passwort setzen',
            onPressed: _busy || !canConfirm || _newPassword.text.length < 8
                ? null
                : _resetPassword,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('onb_send_reset'),
            onPressed: _busy ? null : _sendReset,
            child: const Text('Code nochmal schicken'),
          ),
        ],
      ),
    };
  }

  String _title() => switch (_flow.step) {
    OnboardingStep.welcome => IntroSlides.whatItDoes.title,
    OnboardingStep.howItWorks => IntroSlides.howItWorks.title,
    OnboardingStep.account => switch (_mode) {
      AccountMode.signUp => 'Erst ein Konto',
      AccountMode.confirmSignUp => 'Code aus der Mail',
      AccountMode.signIn => 'Willkommen zurück',
      AccountMode.forgotPassword => 'Passwort vergessen',
      AccountMode.resetPassword => 'Neues Passwort',
    },
    OnboardingStep.aiChoice => 'Willst du KI nutzen?',
    OnboardingStep.security => 'Eine PIN für die App',
    OnboardingStep.extraSecurity => 'Noch mehr Sicherheit?',
    OnboardingStep.tone => 'Wie soll ich mit dir reden?',
  };

  String _hint() => switch (_flow.step) {
    OnboardingStep.welcome => IntroSlides.whatItDoes.lead,
    OnboardingStep.howItWorks => IntroSlides.howItWorks.lead,
    OnboardingStep.account => switch (_mode) {
      AccountMode.signUp =>
        'Damit du dich wieder anmelden kannst, wenn du das Gerät wechselst. '
            'Deine Inhalte bleiben trotzdem auf dem Gerät.',
      AccountMode.confirmSignUp =>
        'Ich schicke einen sechsstelligen Code statt eines Links – der '
            'landet sonst im Browser und findet nicht zurück. Der Code gilt '
            'eine Stunde.\n\n'
            'Steht in der Mail nur ein Link und kein Code? Dann tipp den '
            'Link an und komm hierher zurück.',
      AccountMode.signIn =>
        'Melde dich mit deinen Zugangsdaten an. Deine alten Vorgänge lagen '
            'auf dem alten Gerät und kommen nicht mit – die waren nie auf '
            'einem Server.',
      AccountMode.forgotPassword =>
        'Trag deine E-Mail-Adresse ein. Du bekommst einen Code, mit dem du '
            'dir ein neues Passwort setzt.',
      AccountMode.resetPassword =>
        'Code aus der Mail, dann das neue Passwort. Fertig.',
    },
    OnboardingStep.aiChoice =>
      'Mit KI formuliere ich Texte für dich und zerlege Aufgaben. Dafür '
          'gehen diese Texte über unser Backend zum Anbieter.\n\n'
          'Ohne KI läuft alles auf deinem Gerät. Der Rest der App bleibt '
          'gleich. Du kannst das jederzeit ändern.',
    OnboardingStep.security =>
      _biometricAvailable
          ? 'Einmal beim Öffnen, danach ist alles frei nutzbar. Dein Gerät kann '
                'Fingerabdruck oder Gesichtsscan – das nehme ich, die PIN ist '
                'die Rückfallebene. Abschalten kannst du das in den '
                'Einstellungen.'
          : 'Einmal beim Öffnen, danach ist alles frei nutzbar. Dieses Gerät '
                'bietet gerade keine Biometrie an, also bleibt es bei der PIN.',
    OnboardingStep.extraSecurity =>
      'Zwei-Faktor heißt: Beim Anmelden auf einem neuen Gerät kommt '
          'zusätzlich ein Code aus deiner Authenticator-App dazu. Dauert eine '
          'Minute – oder du machst es später in den Einstellungen.',
    OnboardingStep.tone =>
      'Das ändert die Begrüßung, die Knöpfe und den Stil der KI-Vorschläge. '
          'Änderbar, wann immer du willst.',
  };

  static String _toneLabel(AiTone tone) => switch (tone) {
    AiTone.locker => 'Locker – „Hey, was steht an?"',
    AiTone.neutral => 'Neutral – „Hallo. Womit kann ich helfen?"',
    AiTone.sachlich => 'Sachlich – „Auswahl treffen."',
  };
}
