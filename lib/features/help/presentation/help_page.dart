import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../domain/about_info.dart';
import '../domain/faq.dart';
import '../domain/help_service.dart';

/// Der Info- und Hilfe-Bereich (Konzept, Abschnitt 15).
///
/// Die festen Antworten stehen sofort da. Gefragt werden kann zusätzlich –
/// aber nur, wenn der Katalog nichts hergibt und der User KI eingeschaltet
/// hat.
class HelpPage extends StatefulWidget {
  const HelpPage({super.key, this.version = '0.1.0', this.buildNumber = '1'});

  final String version;
  final String buildNumber;

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _controller = TextEditingController();
  HelpAnswer? _answer;
  bool _asking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _asking) return;

    setState(() => _asking = true);
    final answer = await AppScope.of(context).help.ask(question);
    if (!mounted) return;
    setState(() {
      _answer = answer;
      _asking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = AboutInfo(
      version: widget.version,
      buildNumber: widget.buildNumber,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Hilfe & Info')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            TextField(
              key: const Key('help_field'),
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Frag mich etwas',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  key: const Key('help_ask'),
                  icon: const Icon(Icons.search),
                  onPressed: _ask,
                ),
              ),
              onSubmitted: (_) => _ask(),
            ),
            if (_answer != null) ...[
              const SizedBox(height: 16),
              Container(
                key: const Key('help_answer'),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(_answer!.text, style: theme.textTheme.bodyLarge),
              ),
            ],
            const SizedBox(height: 32),
            Text('Häufige Fragen', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in FaqCatalog.entries)
              ExpansionTile(
                key: Key('faq_${entry.id}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 16),
                title: Text(entry.question),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      entry.answer,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),
            Text('Über die App', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _InfoLine(label: 'Name', value: AboutInfo.appName),
            _InfoLine(label: 'Version', value: info.versionLabel),
            const _InfoLine(label: 'Entwickler', value: AboutInfo.developer),
            const _InfoLine(label: 'Lizenz', value: AboutInfo.license),
            const SizedBox(height: 16),
            Text(
              AboutInfo.purpose,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AboutInfo.origin,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // Der Datenhinweis gehört sichtbar hierher, nicht nur in eine
            // Datenschutzerklärung.
            Container(
              key: const Key('about_data_notice'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AboutInfo.dataNotice,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            Text('Verwendete Bibliotheken', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final license in AboutInfo.thirdParty)
              _InfoLine(label: license.name, value: license.license),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
