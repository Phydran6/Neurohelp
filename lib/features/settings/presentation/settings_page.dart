import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../core/settings/app_settings.dart';

/// Die Einstellungen.
///
/// Nur das, was der User laut Konzept selbst entscheidet: Tonfall
/// (Abschnitt 5) und KI-Toggle (Abschnitt 14). Kein Sammelsurium.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) unawaited(_load());
  }

  Future<void> _load() async {
    final settings = await AppScope.of(context).settings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _setAi({required bool enabled}) async {
    final updated = await AppScope.of(
      context,
    ).settings.setAiEnabled(enabled: enabled);
    if (mounted) setState(() => _settings = updated);
  }

  Future<void> _setTone(AiTone tone) async {
    final updated = await AppScope.of(context).settings.setTone(tone);
    if (mounted) setState(() => _settings = updated);
  }

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
                  Text('Ton', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Wie soll ich mit dir reden?',
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
                  const SizedBox(height: 32),
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
                        ? 'Texte, die die KI verarbeiten soll, gehen über '
                              'unser Backend an den Anbieter. Alles andere '
                              'bleibt auf deinem Gerät.'
                        : 'Die App läuft vollständig auf deinem Gerät. Es '
                              'fällt weg, dass ich Texte für dich formuliere '
                              'oder Aufgaben selbst zerlege – alles andere '
                              'bleibt.',
                    key: const Key('settings_ai_note'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
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
