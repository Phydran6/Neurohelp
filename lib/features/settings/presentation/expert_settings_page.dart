import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/account/account_repository.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/ai/openrouter/openrouter_account.dart';
import '../../../core/ai/openrouter/openrouter_exception.dart';
import '../../../core/ai/openrouter/openrouter_key.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/app_services.dart';
import '../../../core/settings/app_settings.dart';
import '../../../shared/widgets/error_details.dart';
import '../../backup/presentation/backup_page.dart';
import '../../help/presentation/help_page.dart';
import '../../history/presentation/history_page.dart';
import '../../security/presentation/mfa_setup_page.dart';
import '../../security/presentation/recovery_codes_page.dart';
import 'ai_endpoint_page.dart';
import 'change_password_tile.dart';
import 'delete_account_tile.dart';
import 'settings_page.dart';

/// Die Einstellungen für alle, die wissen, was sie tun (Konzept,
/// Abschnitte 5, 13, 14, 15).
///
/// Hier steht alles roh: Ton, Theme, KI samt eigenem Endpunkt und eigenem
/// Schlüssel, die App-Sperre, Zwei-Faktor, die Sicherungsdatei und das
/// Löschen des Kontos. Kein Sammelsurium – aber auch keine Lücken, hinter
/// denen sich „geht nur beim Neuinstallieren" versteckt.
///
/// Der andere Weg steht in [GuidedSettingsPage]. Beide können dasselbe; sie
/// erklären nur unterschiedlich viel.
class ExpertSettingsPage extends StatefulWidget {
  const ExpertSettingsPage({required this.onSwitchMode, super.key});

  /// Zurück zur Auswahl "Ich weiß, was ich tue" / "Ich hab keinen Plan".
  final VoidCallback onSwitchMode;

  @override
  State<ExpertSettingsPage> createState() => _ExpertSettingsPageState();
}

class _ExpertSettingsPageState extends State<ExpertSettingsPage> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  /// Rückmeldung zum KI-Schalter. Ein Schalter, der nichts sagt, fühlt sich
  /// kaputt an – auch wenn er funktioniert.
  String? _aiStatus;
  bool _aiChecking = false;

  Account? _account;
  bool _hasMfa = false;
  bool _biometricAvailable = false;
  bool _busy = false;

  /// Wie viele Wiederherstellungs-Codes noch offen sind.
  int _recoveryLeft = 0;

  String? _message;
  String? _technical;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) unawaited(_load());
  }

  Future<void> _load() async {
    final services = AppScope.of(context);
    final settings = await services.settings.load();
    final biometric = await services.lock.isBiometricAvailable;
    final recoveryLeft = await services.lock.remainingRecoveryCodes;

    Account? account;
    var hasMfa = false;
    if (services.account.isConfigured) {
      account = await services.account.currentAccount();
      if (account != null) hasMfa = await services.account.hasMfa();
    }

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _biometricAvailable = biometric;
      _recoveryLeft = recoveryLeft;
      _account = account;
      _hasMfa = hasMfa;
      _loading = false;
    });
  }

  // ---------------------------------------------------------------- Ton & KI

  Future<void> _setTone(AiTone tone) async {
    final updated = await AppScope.of(context).settings.setTone(tone);
    if (mounted) setState(() => _settings = updated);
  }

  Future<void> _setTheme(AppThemeChoice choice) async {
    final updated = await AppScope.of(context).settings.setThemeChoice(choice);
    if (mounted) setState(() => _settings = updated);
  }

  Future<void> _setAi({required bool enabled}) async {
    final services = AppScope.of(context);
    final updated = await services.settings.setAiEnabled(enabled: enabled);
    if (!mounted) return;

    setState(() {
      _settings = updated;
      _aiStatus = enabled ? null : 'KI ist aus. Alles bleibt auf dem Gerät.';
      _aiChecking = enabled;
    });

    if (!enabled) return;

    // Beim Einschalten einmal wirklich nachfragen: Sonst merkt der User erst
    // mitten in einem Ablauf, dass die KI gar nicht antwortet.
    try {
      await services.ai.probe();
      if (!mounted) return;
      setState(() {
        _aiChecking = false;
        _aiStatus = 'KI ist an und antwortet.';
      });
    } on AiUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiChecking = false;
        _aiStatus =
            'KI ist an, aber sie antwortet gerade nicht: ${error.reason} '
            'Die Abläufe funktionieren weiter ohne sie.';
      });
    }
  }

  // ------------------------------------------------- Eigener KI-Zugang (17a)

  /// Ein Tap – mehr soll es für den User nicht sein.
  ///
  /// Er meldet sich im Browser an und ist zurück. Einen Schlüssel bekommt er
  /// nie zu sehen; genau das unterscheidet diesen Weg vom Selbst-eintragen
  /// und hält das DAU-Prinzip (Konzept, Abschnitt 4).
  Future<void> _connectOpenRouter() async {
    if (_aiChecking) return;
    setState(() {
      _aiChecking = true;
      _aiStatus = null;
    });

    final services = AppScope.of(context);

    try {
      final result = await services.openRouter.connect();
      if (!mounted) return;

      setState(() {
        _aiChecking = false;
        // Abbrechen ist eine gültige Antwort und keine Meldung wert.
        _aiStatus = result == OpenRouterConnectResult.connected
            ? 'Verbunden. Ab jetzt antwortet dein eigener Zugang.'
            : null;
      });
    } on OpenRouterException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiChecking = false;
        _aiStatus =
            '${error.reason} Es läuft weiter wie bisher – es fällt nichts aus.';
        _technical = error.technical;
      });
    }
  }

  Future<void> _disconnectOpenRouter() async {
    await AppScope.of(context).openRouter.disconnect();
    if (!mounted) return;
    setState(
      () => _aiStatus =
          'Getrennt. Die KI läuft wieder über den Standardweg der App.',
    );
  }

  /// Die versteckte Option für die drei Bastler: eigener Schlüssel.
  Future<void> _enterOwnKey() async {
    // Bewusst ohne TextEditingController: Der müsste weggeräumt werden, und
    // der Dialog baut sich während des Ausblendens noch einmal auf – ein
    // schon weggeräumter Controller fliegt einem dann um die Ohren.
    var typed = '';

    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eigener Schlüssel'),
        content: TextField(
          key: const Key('settings_openrouter_byok_field'),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'OpenRouter-API-Schlüssel',
            helperText: 'Beginnt mit sk-or-',
          ),
          onChanged: (value) => typed = value,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('settings_openrouter_byok_save'),
            onPressed: () => Navigator.of(dialogContext).pop(typed),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (raw == null || !mounted) return;

    setState(() {
      _aiChecking = true;
      _aiStatus = null;
    });

    try {
      await AppScope.of(context).openRouter.connectWithKey(raw);
      if (!mounted) return;
      setState(() {
        _aiChecking = false;
        _aiStatus = 'Schlüssel übernommen. Er bleibt auf diesem Gerät.';
        _technical = null;
      });
    } on OpenRouterException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiChecking = false;
        _aiStatus = error.reason;
        _technical = error.technical;
      });
    }
  }

  // ------------------------------------------------------------------ Sperre

  Future<void> _setBiometrics({required bool enabled}) async {
    final services = AppScope.of(context);

    if (enabled && !_biometricAvailable) {
      setState(() {
        _message =
            'Dieses Gerät bietet gerade keine Biometrie an. Prüf in den '
            'Systemeinstellungen, ob Fingerabdruck oder Gesicht eingerichtet '
            'ist.';
      });
      return;
    }

    final updated = await services.settings.setLockMethod(
      enabled ? LockMethod.biometric : LockMethod.pin,
    );
    if (!mounted) return;
    setState(() {
      _settings = updated;
      _message = enabled
          ? 'Beim Öffnen wird zuerst Fingerabdruck oder Gesicht versucht.'
          : 'Beim Öffnen wird nur noch die PIN gefragt.';
      _technical = null;
    });
  }

  Future<void> _changePin() async {
    final controller = TextEditingController();

    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Neue PIN'),
        content: TextField(
          key: const Key('settings_pin_field'),
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Mindestens 4 Ziffern'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('settings_pin_save'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (pin == null || !mounted) return;

    try {
      await AppScope.of(context).lock.setPin(pin);
      if (!mounted) return;
      setState(() {
        _message = 'PIN geändert.';
        _technical = null;
      });
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message.toString());
    }
  }

  Future<void> _openRecoveryCodes() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RecoveryCodesPage(remaining: _recoveryLeft),
      ),
    );
    if (!mounted) return;

    final left = await AppScope.of(context).lock.remainingRecoveryCodes;
    if (mounted) setState(() => _recoveryLeft = left);
  }

  // ------------------------------------------------------------------- Konto

  Future<void> _setUpMfa() async {
    final done = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const MfaSetupPage()));
    if (done != true || !mounted) return;

    setState(() {
      _hasMfa = true;
      _message = 'Zwei-Faktor ist eingerichtet.';
      _technical = null;
    });
  }

  Future<void> _removeMfa() async {
    await _run(() async {
      await AppScope.of(context).account.removeMfa();
      if (!mounted) return;
      setState(() {
        _hasMfa = false;
        _message = 'Zwei-Faktor ist entfernt.';
      });
    });
  }

  Future<void> _signOut() async {
    await _run(() async {
      await AppScope.of(context).account.signOut();
      if (!mounted) return;
      setState(() {
        _account = null;
        _hasMfa = false;
        _message = 'Du bist abgemeldet. Deine Sachen bleiben auf dem Gerät.';
      });
    });
  }

  /// Führt eine Konto-Aktion aus und übersetzt Fehler in ruhige Sätze.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _technical = null;
    });

    try {
      await action();
    } on AccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.details ?? 'Das hat gerade nicht geklappt.';
        _technical = error.technical;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------------------------------------------------- View

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [SwitchModeButton(onPressed: widget.onSwitchMode)],
      ),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  if (_message != null) ...[
                    Container(
                      key: const Key('settings_message'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_message!, style: theme.textTheme.bodyMedium),
                          if (_technical != null) ...[
                            const SizedBox(height: 4),
                            ErrorDetails(technical: _technical!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  ..._toneSection(theme),
                  const SizedBox(height: 32),
                  ..._themeSection(theme),
                  const SizedBox(height: 32),
                  ..._aiSection(theme),
                  const SizedBox(height: 32),
                  ..._lockSection(theme),
                  const SizedBox(height: 32),
                  ..._backupSection(theme),
                  const SizedBox(height: 32),
                  ..._accountSection(theme),
                  const SizedBox(height: 32),
                  ListTile(
                    key: const Key('settings_history'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: const Text('Deine Historie'),
                    subtitle: const Text(
                      'Alles, was du mit mir angegangen bist – offen und '
                      'erledigt',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HistoryPage(),
                      ),
                    ),
                  ),
                  ListTile(
                    key: const Key('settings_help'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Hilfe, Info und Links'),
                    subtitle: const Text(
                      'Häufige Fragen, Version, Quelltext, Datenschutz',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const HelpPage()),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _toneSection(ThemeData theme) => [
    Text('Ton', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    Text(
      'Wie soll ich mit dir reden? Das ändert die Begrüßung, die Knöpfe und '
      'den Stil der KI-Vorschläge.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 12),
    RadioGroup<AiTone>(
      groupValue: _settings.tone,
      onChanged: (value) {
        if (value != null) unawaited(_setTone(value));
      },
      child: Column(
        children: [
          for (final tone in AiTone.values)
            RadioListTile<AiTone>(
              key: Key('tone_${tone.name}'),
              value: tone,
              title: Text(_toneLabel(tone)),
              subtitle: Text(_toneExample(tone)),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    ),
  ];

  List<Widget> _aiSection(ThemeData theme) => [
    Text('KI', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    SwitchListTile(
      key: const Key('settings_ai'),
      value: _settings.aiEnabled,
      onChanged: (value) => _setAi(enabled: value),
      title: const Text('KI nutzen'),
      contentPadding: EdgeInsets.zero,
    ),
    const SizedBox(height: 8),
    Text(
      _settings.aiEnabled
          ? 'Texte, die die KI verarbeiten soll, verlassen dein Gerät – '
                'sonst nichts. In den Abläufen taucht dann ein Knopf für '
                'Vorschläge auf; übernommen wird nur, was du antippst.'
          : 'Die App läuft vollständig auf deinem Gerät. Es fällt weg, dass '
                'ich Texte für dich formuliere oder Aufgaben selbst zerlege – '
                'alles andere bleibt.',
      key: const Key('settings_ai_note'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    if (_aiChecking || _aiStatus != null) ...[
      const SizedBox(height: 12),
      Text(
        // Kein Ladekringel: Der flackert nur und hängt in Widget-Tests.
        _aiChecking ? 'Ich frage kurz nach …' : _aiStatus!,
        key: const Key('settings_ai_status'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    ],
    // Das Angebot aus Abschnitt 17a. Es kommt erst hier, nie im Onboarding:
    // Die Standard-KI läuft sofort, ein eigener Zugang ist ein späteres
    // Angebot und kein Einstiegshindernis.
    if (_settings.aiEnabled) ...[
      const SizedBox(height: 24),
      ListenableBuilder(
        listenable: AppScope.of(context).openRouter,
        builder: (context, _) => _openRouterCard(theme),
      ),
      const SizedBox(height: 16),
      ListenableBuilder(
        listenable: AppScope.of(context).customAi,
        builder: (context, _) => _customEndpointTile(theme),
      ),
      const SizedBox(height: 16),
      _aiOrderNote(theme),
    ],
  ];

  /// Der eigene Server – der Weg, den nur Experten gehen (Konzept,
  /// Abschnitt 17a).
  ///
  /// Steht bewusst **unter** dem Login-Angebot: Wer hier landet, sucht ihn
  /// ohnehin. Wer ihn nicht sucht, soll nicht darüber stolpern.
  Widget _customEndpointTile(ThemeData theme) {
    final account = AppScope.of(context).customAi;
    final endpoint = account.endpoint;

    return ListTile(
      key: const Key('settings_custom_ai'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.dns_outlined),
      title: const Text('Eigenen KI-Server eintragen'),
      subtitle: Text(
        endpoint == null
            ? 'OpenWebUI, Ollama, LM Studio – oder ein Schlüssel von OpenAI '
                  'bzw. Anthropic. Die Anfragen gehen dann direkt dorthin.'
            : 'Verbunden: ${endpoint.label} (${endpoint.keyHint})',
      ),
      isThreeLine: true,
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AiEndpointPage()));
        if (mounted) setState(() {});
      },
    );
  }

  /// Welche Stufe wann dran ist.
  ///
  /// Für Experten gehört das hin: Wer drei Zugänge eintragen kann, will
  /// wissen, welcher gefragt wird – und warum trotzdem nie eine
  /// Fehlermeldung kommt.
  Widget _aiOrderNote(ThemeData theme) => Text(
    'Reihenfolge: eigener Server, dann dein OpenRouter-Zugang'
    '${(AppConfig.instanceOrNull?.hasSharedAiKey ?? false) ? ', dann der fertige Zugang der App' : ''}'
    ', dann unsere gehostete KI. Fällt eine Stufe aus, geht es still eine '
    'tiefer – es fällt nie etwas aus, es wird höchstens einfacher.',
    key: const Key('settings_ai_order'),
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );

  Widget _openRouterCard(ThemeData theme) {
    final account = AppScope.of(context).openRouter;

    // Material, nicht Container: Die aufklappbare Zeile darunter malt ihren
    // Tipp-Effekt auf das nächste Material. Läge dazwischen nur eine
    // eingefärbte Box, verschluckt sie ihn – Flutter meldet das im Test.
    return Material(
      key: const Key('settings_openrouter'),
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: account.isConnected
              ? _openRouterConnected(theme, account)
              : _openRouterOffer(theme),
        ),
      ),
    );
  }

  List<Widget> _openRouterOffer(ThemeData theme) => [
    Text('Bessere Antworten?', style: theme.textTheme.titleSmall),
    const SizedBox(height: 8),
    Text(
      'Verbinde ein eigenes KI-Konto – kostenlos möglich. Ein Tap, du musst '
      'nichts kopieren und nichts einrichten. Danach ist es nie wieder ein '
      'Thema.',
      key: const Key('settings_openrouter_offer'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 12),
    FilledButton(
      key: const Key('settings_openrouter_connect'),
      onPressed: _aiChecking ? null : _connectOpenRouter,
      child: const Text('Konto verbinden'),
    ),
    const SizedBox(height: 12),
    _openRouterPrivacyNote(theme),
    _openRouterExpertOption(theme),
  ];

  List<Widget> _openRouterConnected(
    ThemeData theme,
    OpenRouterAccount account,
  ) => [
    Text(
      account.needsReconnect ? 'Zugang abgelaufen' : 'Eigenes KI-Konto',
      style: theme.textTheme.titleSmall,
    ),
    const SizedBox(height: 8),
    Text(
      account.needsReconnect
          // Kein Drama daraus machen: Es fällt nichts aus, es wird nur
          // wieder einfacher.
          ? 'Dein Zugang wird nicht mehr angenommen – abgelaufen oder '
                'zurückgezogen. Solange läuft alles über den Standardweg '
                'weiter, es fehlt dir nichts.'
          : 'Verbunden${account.key!.origin == OpenRouterKeyOrigin.manual ? ' (eigener Schlüssel ${account.key!.hint})' : ''}. '
                'Deine Anfragen gehen direkt von diesem Gerät zum Anbieter – '
                'ohne Umweg über uns.',
      key: const Key('settings_openrouter_status'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      children: [
        if (account.needsReconnect)
          FilledButton(
            key: const Key('settings_openrouter_reconnect'),
            onPressed: _aiChecking ? null : _connectOpenRouter,
            child: const Text('Neu verbinden'),
          ),
        OutlinedButton(
          key: const Key('settings_openrouter_disconnect'),
          onPressed: _aiChecking ? null : _disconnectOpenRouter,
          child: const Text('Trennen'),
        ),
      ],
    ),
    const SizedBox(height: 12),
    _openRouterPrivacyNote(theme),
  ];

  /// Der ehrliche Teil. Er gehört hierher, nicht ins Kleingedruckte:
  /// In Neurohelp geht es oft um Arzt- und Kassenthemen.
  Widget _openRouterPrivacyNote(ThemeData theme) => Text(
    'Was die KI verarbeitet, läuft dann über OpenRouter und den Anbieter des '
    'Modells. Bei kostenlosen Modellen darf mit diesen Texten häufig '
    'trainiert werden. Alles andere – Historie, Vorgänge, Kontakte – bleibt '
    'wie immer auf deinem Gerät.',
    key: const Key('settings_openrouter_privacy'),
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );

  /// BYOK liegt bewusst darunter, aufklappbar – für die drei Bastler, die
  /// das wollen. Im Standardweg taucht kein Schlüssel auf.
  Widget _openRouterExpertOption(ThemeData theme) => Theme(
    // Ohne das zieht die Aufklapp-Zeile die Trennlinien des Standardthemas
    // mit und der ruhige Block bekommt Kanten, die er nicht braucht.
    data: theme.copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: const Key('settings_openrouter_byok'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(
        'Ich habe schon einen eigenen Schlüssel',
        style: theme.textTheme.bodySmall,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('settings_openrouter_byok_open'),
            onPressed: _aiChecking ? null : _enterOwnKey,
            child: const Text('Schlüssel eintragen'),
          ),
        ),
      ],
    ),
  );

  List<Widget> _themeSection(ThemeData theme) => [
    Text('Darstellung', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    Text(
      'Standard ist, was dein Gerät gerade macht. Fest einzustellen lohnt '
      'sich, wenn Helligkeit für dich ein Thema ist.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 12),
    RadioGroup<AppThemeChoice>(
      groupValue: _settings.themeChoice,
      onChanged: (value) {
        if (value != null) unawaited(_setTheme(value));
      },
      child: const Column(
        children: [
          RadioListTile<AppThemeChoice>(
            key: Key('theme_system'),
            value: AppThemeChoice.system,
            title: Text('Wie das Gerät'),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<AppThemeChoice>(
            key: Key('theme_light'),
            value: AppThemeChoice.light,
            title: Text('Hell'),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<AppThemeChoice>(
            key: Key('theme_dark'),
            value: AppThemeChoice.dark,
            title: Text('Dunkel'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    ),
  ];

  List<Widget> _backupSection(ThemeData theme) => [
    Text('Sicherung', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    Text(
      'Alles vom Gerät in eine Datei – und aus jeder Version wieder zurück. '
      'Ohne PIN und ohne KI-Schlüssel: Die liegen im Schlüsselbund, nicht in '
      'der Datenbank.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 8),
    ListTile(
      key: const Key('settings_backup'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.save_outlined),
      title: const Text('Sichern und zurückholen'),
      subtitle: Text(
        _settings.lastBackupAt == null
            ? 'Noch nichts gesichert.'
            : 'Zuletzt gesichert am '
                  '${_settings.lastBackupAt!.day}.'
                  '${_settings.lastBackupAt!.month}.'
                  '${_settings.lastBackupAt!.year}.',
      ),
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const BackupPage()));
        // Einspielen ändert alles – auch Ton, Theme und KI-Schalter.
        if (mounted) unawaited(_load());
      },
    ),
  ];

  List<Widget> _lockSection(ThemeData theme) => [
    Text('App-Sperre', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    Text(
      'Einmal beim Öffnen, danach ist alles frei nutzbar. Eine Hürde, nicht '
      'sieben.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 8),
    SwitchListTile(
      key: const Key('settings_biometric'),
      value: _settings.usesBiometrics,
      // Abschaltbar sein muss es: Nicht jedes Gerät erkennt jeden Finger, und
      // nicht jeder will sein Gesicht hergeben. Die PIN trägt allein.
      onChanged: _settings.isLocked
          ? (value) => _setBiometrics(enabled: value)
          : null,
      title: const Text('Fingerabdruck oder Gesicht'),
      subtitle: Text(
        _biometricAvailable
            ? 'Sonst wird direkt nach der PIN gefragt.'
            : 'Auf diesem Gerät gerade nicht verfügbar.',
      ),
      contentPadding: EdgeInsets.zero,
    ),
    ListTile(
      key: const Key('settings_change_pin'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.pin_outlined),
      title: const Text('PIN ändern'),
      onTap: _changePin,
    ),
    // Der Notausgang aus Abschnitt 13. Er gehört hierher, zur Sperre, an der
    // er vorbeiführt – nicht zum Konto.
    ListTile(
      key: const Key('settings_recovery_codes'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.key_outlined),
      title: const Text('Wiederherstellungs-Codes'),
      subtitle: Text(
        _recoveryLeft > 0
            ? 'Noch $_recoveryLeft offen. Damit kommst du rein, wenn PIN und '
                  'Fingerabdruck nicht mehr gehen.'
            : 'Noch keine da. Ohne sie ist ein vergessener Zugang eine '
                  'Sackgasse.',
      ),
      isThreeLine: true,
      onTap: _openRecoveryCodes,
    ),
  ];

  List<Widget> _accountSection(ThemeData theme) {
    final services = AppScope.of(context);
    final account = _account;

    return [
      Text('Konto', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      if (!services.account.isConfigured)
        Text(
          'Für diese App ist kein Backend hinterlegt. Konto, Reset-Mails und '
          'KI sind deshalb aus – der Rest funktioniert.',
          key: const Key('settings_account_unconfigured'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else if (account == null)
        Text(
          'Du bist gerade nicht angemeldet. Deine Vorgänge auf dem Gerät sind '
          'davon nicht betroffen.',
          key: const Key('settings_account_signed_out'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        )
      else ...[
        Text(
          '${account.username} · ${account.email}',
          key: const Key('settings_account_email'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          key: const Key('settings_mfa'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _hasMfa ? Icons.verified_user_outlined : Icons.shield_outlined,
          ),
          title: Text(
            _hasMfa ? 'Zwei-Faktor entfernen' : 'Zwei-Faktor einrichten',
          ),
          subtitle: Text(
            _hasMfa
                ? 'Eingerichtet. Beim Anmelden auf einem neuen Gerät wird '
                      'zusätzlich der Code aus deiner App gefragt.'
                : 'Freiwillig. Schützt dein Konto, falls dein Passwort '
                      'irgendwo auftaucht.',
          ),
          isThreeLine: true,
          onTap: _busy ? null : (_hasMfa ? _removeMfa : _setUpMfa),
        ),
        ChangePasswordTile(
          enabled: !_busy,
          onRun: _run,
          onChanged: () {
            if (mounted) setState(() => _message = 'Passwort geändert.');
          },
        ),
        ListTile(
          key: const Key('settings_sign_out'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: const Text('Abmelden'),
          onTap: _busy ? null : _signOut,
        ),
        DeleteAccountTile(
          enabled: !_busy,
          onRun: _run,
          onDeleted: ({required bool emailed}) {
            if (!mounted) return;
            setState(() {
              _account = null;
              _hasMfa = false;
              _recoveryLeft = 0;
              _settings = AppScope.of(context).settings.current;
              _message = emailed
                  ? 'Konto gelöscht, dieses Gerät ist leergeräumt. Die '
                        'Bestätigung liegt gleich in deinem Postfach.'
                  : 'Konto gelöscht, dieses Gerät ist leergeräumt.';
            });
          },
        ),
      ],
    ];
  }

  static String _toneLabel(AiTone tone) => switch (tone) {
    AiTone.locker => 'Locker',
    AiTone.neutral => 'Neutral',
    AiTone.sachlich => 'Sachlich',
  };

  static String _toneExample(AiTone tone) => switch (tone) {
    AiTone.locker => 'Hey, was steht an?',
    AiTone.neutral => 'Hallo. Womit kann ich helfen?',
    AiTone.sachlich => 'Auswahl treffen.',
  };
}
