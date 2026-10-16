import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ai/custom/custom_endpoint.dart';
import '../../../core/ai/custom/custom_endpoint_account.dart';
import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/error_details.dart';
import '../../../shared/widgets/support_contact.dart';
import '../../../shared/widgets/text_context_menu.dart';

/// Einen eigenen KI-Server eintragen (Konzept, Abschnitt 17a, Expertenweg).
///
/// **Warum hier Felder stehen dürfen, sonst aber nirgends:** Dieser Weg ist
/// ausdrücklich für Leute, die schon eine KI betreiben. Ein Login-Knopf hülfe
/// ihnen nicht – sie brauchen genau die drei Angaben, die ihr Server
/// verlangt. Für alle anderen ist der Weg unsichtbar; sie kommen über den
/// geführten Weg an ihre KI.
///
/// Vor dem Speichern wird **einmal wirklich gefragt**. Ein Zugang, der erst
/// mitten in einem Ablauf als falsch auffällt, ist schlimmer als gar keiner.
class AiEndpointPage extends StatefulWidget {
  const AiEndpointPage({super.key});

  @override
  State<AiEndpointPage> createState() => _AiEndpointPageState();
}

class _AiEndpointPageState extends State<AiEndpointPage> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();

  CustomEndpointKind _kind = CustomEndpointKind.openAiCompatible;
  String? _presetId;

  bool _busy = false;
  bool _loaded = false;
  String? _message;
  String? _technical;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    // Was schon eingetragen ist, steht im Formular – außer dem Schlüssel.
    // Den wieder anzuzeigen hätte keinen Nutzen und ein Risiko.
    final endpoint = AppScope.of(context).customAi.endpoint;
    if (endpoint != null) {
      _kind = endpoint.kind;
      _baseUrl.text = endpoint.baseUrl;
      _model.text = endpoint.model;
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _applyPreset(CustomEndpointPreset preset) {
    setState(() {
      _presetId = preset.id;
      _kind = preset.kind;
      _baseUrl.text = preset.baseUrl;
      _model.text = preset.model;
      _message = preset.hint;
      _technical = null;
    });
  }

  CustomAiEndpoint get _entered => CustomAiEndpoint(
    kind: _kind,
    baseUrl: _baseUrl.text.trim(),
    model: _model.text.trim(),
    apiKey: _apiKey.text.trim(),
  );

  Future<void> _connect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _technical = null;
    });

    try {
      await AppScope.of(context).customAi.connect(_entered);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message =
            'Verbunden. Ab jetzt beantwortet dieser Server alles, was die '
            'KI machen soll – direkt von diesem Gerät aus.';
      });
    } on CustomEndpointException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.reason;
        _technical = error.technical;
      });
    }
  }

  Future<void> _disconnect() async {
    await AppScope.of(context).customAi.disconnect();
    if (!mounted) return;
    setState(() {
      _apiKey.clear();
      _message =
          'Getrennt. Die KI läuft wieder über die nächste Stufe – es fällt '
          'nichts aus.';
      _technical = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = AppScope.of(context).customAi;

    return Scaffold(
      appBar: AppBar(title: const Text('Eigener KI-Server')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: account,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(
                'Trag ein, was dein Server verlangt. Die Anfragen gehen '
                'danach direkt von diesem Gerät dorthin – ohne Umweg über '
                'uns. Der Schlüssel bleibt im Schlüsselbund des Geräts.',
                key: const Key('endpoint_intro'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (account.isConnected) ...[
                const SizedBox(height: 16),
                Container(
                  key: const Key('endpoint_connected'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Verbunden: ${account.endpoint!.label} '
                    '(${account.endpoint!.keyHint})',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Vorlagen', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in CustomEndpointPreset.all)
                    ChoiceChip(
                      key: Key('endpoint_preset_${preset.id}'),
                      label: Text(preset.label),
                      selected: _presetId == preset.id,
                      onSelected: (_) => _applyPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Schnittstelle', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              RadioGroup<CustomEndpointKind>(
                groupValue: _kind,
                onChanged: (value) {
                  if (value != null) setState(() => _kind = value);
                },
                child: const Column(
                  children: [
                    RadioListTile<CustomEndpointKind>(
                      key: Key('endpoint_kind_openai'),
                      value: CustomEndpointKind.openAiCompatible,
                      title: Text('OpenAI-kompatibel'),
                      subtitle: Text(
                        'OpenAI, OpenWebUI, Ollama, LM Studio, Groq, vLLM …',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<CustomEndpointKind>(
                      key: Key('endpoint_kind_anthropic'),
                      value: CustomEndpointKind.anthropic,
                      title: Text('Anthropic (Claude)'),
                      subtitle: Text('Eigene Schnittstelle, eigener Header.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('endpoint_base_url'),
                contextMenuBuilder: noScanContextMenu,
                controller: _baseUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  helperText:
                      'Ohne /chat/completions am Ende – das hänge ich an.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('endpoint_model'),
                contextMenuBuilder: noScanContextMenu,
                controller: _model,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Modell',
                  helperText: 'Genau so, wie der Server es nennt.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('endpoint_key'),
                contextMenuBuilder: noScanContextMenu,
                controller: _apiKey,
                obscureText: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Schlüssel',
                  helperText: 'Leer lassen, wenn dein Server keinen verlangt.',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 20),
                Container(
                  key: const Key('endpoint_message'),
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
              ],
              const SizedBox(height: 24),
              BigActionButton(
                key: const Key('endpoint_connect'),
                // Kein Ladekringel: Er flackert nur und haengt in Tests.
                label: _busy
                    ? 'Ich frage kurz nach …'
                    : 'Ausprobieren und speichern',
                onPressed: _busy ? null : () => unawaited(_connect()),
              ),
              if (account.isConnected) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('endpoint_disconnect'),
                  onPressed: _busy ? null : () => unawaited(_disconnect()),
                  child: const Text('Trennen'),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                key: const Key('endpoint_privacy'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Was die KI verarbeitet, geht damit an den Server, den du '
                  'hier einträgst – und an niemanden sonst. Alles andere, '
                  'also Historie, Vorgänge und Kontakte, bleibt wie immer '
                  'auf dem Gerät.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SupportContact(
                subject: 'Neurohelp – eigener KI-Server geht nicht',
                context_: 'Ich wollte einen eigenen KI-Server eintragen.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
