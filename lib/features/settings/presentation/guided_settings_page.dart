import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/account/account_repository.dart';
import '../../../core/ai/openrouter/openrouter_account.dart';
import '../../../core/ai/openrouter/openrouter_exception.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/app_services.dart';
import '../../../core/settings/app_settings.dart';
import '../../../shared/widgets/error_details.dart';
import '../../backup/domain/backup_runner.dart';
import '../../backup/presentation/backup_page.dart';
import '../../help/presentation/help_page.dart';
import '../../history/presentation/history_page.dart';
import '../../security/presentation/mfa_setup_page.dart';
import 'change_password_tile.dart';
import 'delete_account_tile.dart';
import 'settings_page.dart';

/// Die Einstellungen für alle anderen (Konzept, Abschnitt 4 – DAU-Prinzip).
///
/// **Der Unterschied zum Expertenweg ist nicht, was fehlt, sondern was nicht
/// erklärt werden muss.** Hier steht kein API-Schlüssel, keine Basis-URL, kein
/// Wort „OpenRouter". Es stehen Entscheidungen da: Wie soll ich mit dir
/// reden. Hell oder dunkel. Soll ich KI benutzen. Soll ich mitsichern.
///
/// **Auswahl vor Eingabe** (Konzept, Abschnitt 3): Auf dieser Seite gibt es
/// kein einziges freies Textfeld außer der PIN.
class GuidedSettingsPage extends StatefulWidget {
  const GuidedSettingsPage({required this.onSwitchMode, super.key});

  /// Zurück zur Auswahl „Ich weiß, was ich tue" / „Ich hab keinen Plan".
  final VoidCallback onSwitchMode;

  @override
  State<GuidedSettingsPage> createState() => _GuidedSettingsPageState();
}

class _GuidedSettingsPageState extends State<GuidedSettingsPage> {
  AppSettings _settings = const AppSettings();
  Account? _account;
  bool _loading = true;
  bool _busy = false;

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

    Account? account;
    if (services.account.isConfigured) {
      account = await services.account.currentAccount();
    }

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _account = account;
      _loading = false;
    });
  }

  void _say(String message, {String? technical}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _technical = technical;
    });
  }

  Future<void> _setTone(AiTone tone) async {
    final updated = await AppScope.of(context).settings.setTone(tone);
    if (mounted) setState(() => _settings = updated);
  }

  Future<void> _setTheme(AppThemeChoice choice) async {
    final updated = await AppScope.of(context).settings.setThemeChoice(choice);
    if (mounted) setState(() => _settings = updated);
  }

  // ---------------------------------------------------------------------- KI

  /// KI an- oder ausschalten – und danach sagen, ob sie auch antwortet.
  ///
  /// Der eigentliche Unterschied zum Expertenweg: Hier gibt es keinen Zugang
  /// einzurichten. Steckt ein fertiger Schlüssel in der App, ist der Schalter
  /// alles, was es braucht. Steckt keiner drin, wird genau das gesagt – und
  /// dann steht der Login-Knopf da, ohne dass das Wort Schlüssel fällt.
  Future<void> _setAi({required bool enabled}) async {
    final services = AppScope.of(context);
    final updated = await services.settings.setAiEnabled(enabled: enabled);
    if (!mounted) return;
    setState(() => _settings = updated);

    if (!enabled) {
      _say('KI ist aus. Ab jetzt bleibt alles auf deinem Gerät.');
      return;
    }

    _say('Ich frage kurz nach, ob sie antwortet …');
    try {
      await services.ai.probe();
      _say('Passt. Die KI ist an und antwortet.');
    } on AiUnavailableException catch (error) {
      _say(
        'Die KI ist eingeschaltet, antwortet aber gerade nicht: '
        '${error.reason}\n\nDas ist halb so wild – alles in der App '
        'funktioniert auch ohne sie. Du kannst es später nochmal versuchen '
        'oder unten ein eigenes Konto verbinden.',
      );
    }
  }

  /// Ein Tap im Browser, und der User ist zurück. Er sieht nie einen
  /// Schlüssel – genau deshalb darf dieser Weg auf dieser Seite stehen.
  Future<void> _connectOwnAi() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final result = await AppScope.of(context).openRouter.connect();
      if (!mounted) return;
      setState(() => _busy = false);

      // Abbrechen ist eine gültige Antwort und keine Meldung wert.
      if (result == OpenRouterConnectResult.connected) {
        _say(
          'Verbunden. Ab jetzt läuft die KI über dein eigenes Konto – die '
          'Antworten werden dadurch meist besser.',
        );
      }
    } on OpenRouterException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _say(
        '${error.reason}\n\nEs läuft weiter wie bisher, es fällt nichts aus.',
        technical: error.technical,
      );
    }
  }

  Future<void> _disconnectOwnAi() async {
    await AppScope.of(context).openRouter.disconnect();
    _say('Getrennt. Die KI läuft wieder über den normalen Weg der App.');
  }

  // --------------------------------------------------------------- Sicherung

  Future<void> _backUpNow() async {
    if (_busy) return;
    setState(() => _busy = true);

    final outcome = await BackupRunner(AppScope.of(context)).backUpToVault();
    if (!mounted) return;
    setState(() => _busy = false);
    _say(outcome.message, technical: outcome.technical);
    await _load();
  }

  // ------------------------------------------------------------------ Sperre

  Future<void> _changePin() async {
    final controller = TextEditingController();

    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Neue PIN'),
        content: TextField(
          key: const Key('guided_pin_field'),
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
            key: const Key('guided_pin_save'),
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
      _say('PIN geändert.');
    } on ArgumentError catch (error) {
      _say(error.message.toString());
    }
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
      final described = describeAccountError(error);
      _say(described.message, technical: described.technical);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------------------------------------------------------------------- View

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Kein Ladekringel: Der Zugriff dauert Millisekunden und flackert nur.
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Einstellungen')),
        body: const SizedBox.shrink(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [SwitchModeButton(onPressed: widget.onSwitchMode)],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            if (_message != null) ...[
              Container(
                key: const Key('guided_message'),
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
            ..._backupSection(theme),
            const SizedBox(height: 32),
            ..._safetySection(theme),
            const SizedBox(height: 32),
            ListTile(
              key: const Key('guided_history'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: const Text('Deine Historie'),
              subtitle: const Text('Alles, was du mit mir angegangen bist.'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
              ),
            ),
            ListTile(
              key: const Key('guided_help'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: const Text('Hilfe – und wie du mich erreichst'),
              subtitle: const Text(
                'Häufige Fragen. Und wenn gar nichts geht: eine Mail an mich.',
              ),
              isThreeLine: true,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const HelpPage())),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _toneSection(ThemeData theme) => [
    Text('Wie soll ich mit dir reden?', style: theme.textTheme.titleMedium),
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
              key: Key('guided_tone_${tone.name}'),
              value: tone,
              title: Text(switch (tone) {
                AiTone.locker => 'Locker – wie ein Kumpel',
                AiTone.neutral => 'Normal – freundlich und ruhig',
                AiTone.sachlich => 'Knapp – nur das Nötigste',
              }),
              subtitle: Text(switch (tone) {
                AiTone.locker => '„Hey, was steht an?"',
                AiTone.neutral => '„Hallo. Womit kann ich helfen?"',
                AiTone.sachlich => '„Auswahl treffen."',
              }),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    ),
  ];

  List<Widget> _themeSection(ThemeData theme) => [
    Text('Hell oder dunkel?', style: theme.textTheme.titleMedium),
    const SizedBox(height: 12),
    RadioGroup<AppThemeChoice>(
      groupValue: _settings.themeChoice,
      onChanged: (value) {
        if (value != null) unawaited(_setTheme(value));
      },
      child: const Column(
        children: [
          RadioListTile<AppThemeChoice>(
            key: Key('guided_theme_system'),
            value: AppThemeChoice.system,
            title: Text('So wie der Rest vom Handy'),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<AppThemeChoice>(
            key: Key('guided_theme_light'),
            value: AppThemeChoice.light,
            title: Text('Immer hell'),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<AppThemeChoice>(
            key: Key('guided_theme_dark'),
            value: AppThemeChoice.dark,
            title: Text('Immer dunkel'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    ),
  ];

  List<Widget> _aiSection(ThemeData theme) {
    final openRouter = AppScope.of(context).openRouter;
    final hasShared = AppConfig.instanceOrNull?.hasSharedAiKey ?? false;

    return [
      Text('Soll ich KI benutzen?', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        'Mit KI formuliere ich Texte für dich und zerlege Aufgaben in '
        'kleine Schritte. Dafür geht genau der Text, um den es geht, kurz '
        'ins Internet – sonst nichts. Ohne KI funktioniert die App '
        'vollständig, sie nimmt dir nur das Schreiben nicht ab.',
        key: const Key('guided_ai_note'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        key: const Key('guided_ai'),
        value: _settings.aiEnabled,
        onChanged: _busy ? null : (value) => _setAi(enabled: value),
        title: const Text('KI benutzen'),
        subtitle: Text(
          hasShared
              ? 'Kostet dich nichts und du musst nichts einrichten.'
              : 'Läuft über den Zugang, den die App mitbringt.',
        ),
        contentPadding: EdgeInsets.zero,
      ),
      if (_settings.aiEnabled) ...[
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: openRouter,
          builder: (context, _) => _ownAiCard(theme, openRouter),
        ),
      ],
    ];
  }

  /// Das Angebot aus Abschnitt 17a, in der Sprache dieses Wegs.
  ///
  /// Kein „OpenRouter", kein „API-Schlüssel", kein „BYOK". Nur: Du kannst dir
  /// ein eigenes, kostenloses Konto holen, dann wird es besser – und das
  /// geht mit einem Tap im Browser.
  Widget _ownAiCard(ThemeData theme, OpenRouterAccount account) => Material(
    key: const Key('guided_own_ai'),
    color: theme.colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.isConnected ? 'Dein eigenes Konto' : 'Geht es besser?',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            account.isConnected
                ? 'Die KI läuft über dein eigenes Konto. Deine Texte gehen '
                      'dabei direkt von deinem Handy zum Anbieter, ohne '
                      'Umweg über uns.'
                : 'Du kannst dir in einer Minute ein eigenes, kostenloses '
                      'KI-Konto holen. Die Antworten werden dadurch meist '
                      'besser. Du tippst auf den Knopf, meldest dich an und '
                      'bist zurück – mehr ist es nicht, und danach ist es nie '
                      'wieder ein Thema.',
            key: const Key('guided_own_ai_note'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (account.isConnected)
            OutlinedButton(
              key: const Key('guided_own_ai_disconnect'),
              onPressed: _busy ? null : () => unawaited(_disconnectOwnAi()),
              child: const Text('Wieder trennen'),
            )
          else
            FilledButton(
              key: const Key('guided_own_ai_connect'),
              onPressed: _busy ? null : () => unawaited(_connectOwnAi()),
              child: const Text('Eigenes Konto holen'),
            ),
          const SizedBox(height: 12),
          // Der ehrliche Teil gehört auch in diesen Weg – gerade in diesen.
          // In Neurohelp geht es oft um Arzt- und Kassenthemen.
          Text(
            'Was die KI verarbeitet, sieht der Anbieter der KI. Bei '
            'kostenlosen Angeboten wird damit oft weitertrainiert. Alles '
            'andere – deine Historie, deine Vorgänge, deine Kontakte – '
            'bleibt auf deinem Handy.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _backupSection(ThemeData theme) => [
    Text('Deine Sachen behalten', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    Text(
      _settings.lastBackupAt == null
          ? 'Damit nichts weg ist, wenn das Handy kaputtgeht oder du die App '
                'neu installierst, lege ich ab und zu eine Sicherung an. Du '
                'musst dich um nichts kümmern.'
          : 'Ich sichere für dich mit. Wenn du die App neu installierst, '
                'frage ich beim ersten Start, ob ich alles zurückholen soll.',
      key: const Key('guided_backup_note'),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 8),
    SwitchListTile(
      key: const Key('guided_backup_auto'),
      value: _settings.autoBackup,
      onChanged: _busy
          ? null
          : (value) async {
              final updated = await AppScope.of(
                context,
              ).settings.setAutoBackup(enabled: value);
              if (!mounted) return;
              setState(() => _settings = updated);
              _say(
                value
                    ? 'Gut. Ich sichere ab jetzt von selbst mit.'
                    : 'In Ordnung. Ich sichere nur noch, wenn du es sagst.',
              );
            },
      title: const Text('Von selbst sichern'),
      contentPadding: EdgeInsets.zero,
    ),
    ListTile(
      key: const Key('guided_backup_now'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.save_outlined),
      title: const Text('Jetzt sichern'),
      subtitle: const Text('Dauert einen Wimpernschlag.'),
      onTap: _busy ? null : () => unawaited(_backUpNow()),
    ),
    ListTile(
      key: const Key('guided_backup_more'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.restore),
      title: const Text('Sicherung zurückholen'),
      subtitle: const Text(
        'Falls doch mal etwas fehlt – oder du auf ein neues Handy '
        'umgezogen bist.',
      ),
      isThreeLine: true,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const BackupPage(simple: true),
          ),
        );
        // Einspielen ändert alles – auch Ton, Theme und KI-Schalter.
        if (mounted) unawaited(_load());
      },
    ),
  ];

  List<Widget> _safetySection(ThemeData theme) {
    final account = _account;

    return [
      Text('Sicherheit', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        _settings.isLocked
            ? 'Beim Öffnen fragt die App einmal nach dir. Danach ist alles '
                  'frei benutzbar.'
            : 'Die App fragt beim Öffnen nichts. Das ist in Ordnung, wenn '
                  'nur du an dieses Handy gehst.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      if (_settings.isLocked)
        ListTile(
          key: const Key('guided_change_pin'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.pin_outlined),
          title: const Text('PIN ändern'),
          onTap: _busy ? null : () => unawaited(_changePin()),
        ),
      if (account != null) ...[
        // Der Assistent, nicht die Erklärung: Wer hier ist, soll nicht
        // wissen müssen, was TOTP ist – er soll durchgeführt werden.
        ListTile(
          key: const Key('guided_mfa'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Konto zusätzlich absichern'),
          subtitle: const Text(
            'Freiwillig. Ich führe dich Schritt für Schritt durch – du '
            'brauchst nur dein Handy.',
          ),
          isThreeLine: true,
          onTap: _busy
              ? null
              : () async {
                  final done = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => const MfaSetupPage(),
                    ),
                  );
                  if (done == true) {
                    _say('Erledigt. Dein Konto ist abgesichert.');
                  }
                },
        ),
        ChangePasswordTile(
          enabled: !_busy,
          onRun: _run,
          subtitle:
              'Du bist angemeldet, deshalb brauchst du keine Mail und keinen '
              'Code dafür – nur ein neues Passwort.',
          onChanged: () => _say('Passwort geändert.'),
        ),
        DeleteAccountTile(
          enabled: !_busy,
          onRun: _run,
          subtitle:
              'Das ist der große rote Knopf: Danach ist nichts mehr da – '
              'nicht auf dem Handy und nicht bei uns. Es gibt kein Zurück.',
          onDeleted: ({required bool emailed}) {
            if (!mounted) return;
            setState(() {
              _account = null;
              _settings = AppScope.of(context).settings.current;
            });
            _say(
              emailed
                  ? 'Alles gelöscht. Eine Bestätigung kommt per Mail.'
                  : 'Alles gelöscht.',
            );
          },
        ),
      ],
    ];
  }
}
