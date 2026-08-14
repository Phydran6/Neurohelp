import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/account/account_repository.dart';
import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../core/settings/app_settings.dart';
import '../../../shared/widgets/error_details.dart';
import '../../help/presentation/help_page.dart';
import '../../history/presentation/history_page.dart';
import '../../security/presentation/mfa_setup_page.dart';
import '../../security/presentation/recovery_codes_page.dart';

/// Die Einstellungen (Konzept, Abschnitte 5, 13, 14, 15).
///
/// Alles, was der User selbst entscheidet, an einer Stelle: Ton, KI, die
/// App-Sperre und sein Konto. Kein Sammelsurium – aber auch keine Lücken,
/// hinter denen sich „geht nur beim Neuinstallieren" versteckt.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konto wirklich löschen?'),
        content: const Text(
          'Dein Konto und alles, was serverseitig dazugehört, wird '
          'gelöscht – Profil, Zwei-Faktor, Wiederherstellungs-Codes. Das '
          'lässt sich nicht rückgängig machen.\n\n'
          'Deine Vorgänge auf diesem Gerät bleiben erhalten. Die wirst du '
          'los, indem du die App deinstallierst.',
        ),
        actions: [
          TextButton(
            key: const Key('settings_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Doch nicht'),
          ),
          FilledButton(
            key: const Key('settings_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ja, löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _run(() async {
      final emailed = await AppScope.of(context).account.deleteAccount();
      if (!mounted) return;
      setState(() {
        _account = null;
        _hasMfa = false;
        _message = emailed
            ? 'Konto gelöscht. Die Bestätigung liegt gleich in deinem '
                  'Postfach.'
            : 'Konto gelöscht.';
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
      appBar: AppBar(title: const Text('Einstellungen')),
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
                  ..._aiSection(theme),
                  const SizedBox(height: 32),
                  ..._lockSection(theme),
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
          ? 'Texte, die die KI verarbeiten soll, gehen über unser Backend an '
                'den Anbieter. Alles andere bleibt auf deinem Gerät. In den '
                'Abläufen taucht dann ein Knopf für Vorschläge auf – '
                'übernommen wird nur, was du antippst.'
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
        _aiChecking ? 'Ich frage kurz beim Backend nach …' : _aiStatus!,
        key: const Key('settings_ai_status'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    ],
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
        ListTile(
          key: const Key('settings_sign_out'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: const Text('Abmelden'),
          onTap: _busy ? null : _signOut,
        ),
        ListTile(
          key: const Key('settings_delete_account'),
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          title: Text(
            'Konto löschen',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          subtitle: const Text(
            'Löscht restlos alles, was serverseitig zu dir gehört. Du '
            'bekommst eine Bestätigung per Mail.',
          ),
          onTap: _busy ? null : _deleteAccount,
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
