import 'package:flutter/material.dart';

import '../../core/ai/ai_client.dart';
import '../../core/companion/tone_texts.dart';
import '../../core/di/app_services.dart';

/// Der Moment, in dem die KI hilft – überall gleich (Konzept, Abschnitt 17).
///
/// Vorher gab es den Schalter, aber keinen Ort, an dem die KI etwas tat. Hier
/// ist er: ein Knopf, ein erzeugter Text, und der landet als **Vorschlag in
/// der Auswahlliste**. Übernommen wird nur, was der User antippt.
///
/// Ist die KI aus oder nicht erreichbar, verschwindet der Block ersatzlos –
/// jeder Ablauf trägt ohne ihn (harte Regel: jeder KI-Pfad braucht einen Weg
/// ohne KI).
class AiSuggestionBox extends StatefulWidget {
  const AiSuggestionBox({
    required this.task,
    required this.inputBuilder,
    required this.onAccept,
    this.onAcceptAll,
    this.singleLine = false,
    this.acceptLabel = 'Übernehmen',
    super.key,
  });

  final AiTask task;

  /// Wird erst beim Antippen ausgewertet – bis dahin tippt der User noch.
  /// Liefert `null`, wenn noch zu wenig dasteht, um etwas vorzuschlagen.
  final String? Function() inputBuilder;

  /// Ein angetippter Vorschlag.
  final void Function(String suggestion) onAccept;

  /// Alle Vorschläge auf einmal. Fehlt der Rückruf, gibt es den Knopf nicht.
  final void Function(List<String> suggestions)? onAcceptAll;

  /// Ob die Antwort **ein** Text ist (Nachricht) statt einer Liste
  /// (Schritte, Stichpunkte).
  final bool singleLine;

  final String acceptLabel;

  @override
  State<AiSuggestionBox> createState() => _AiSuggestionBoxState();
}

class _AiSuggestionBoxState extends State<AiSuggestionBox> {
  List<String> _suggestions = const [];

  /// Was der User schon angetippt hat.
  ///
  /// Der Tipp landete bisher stumm in einer Liste weiter unten – auf dem
  /// Telefon oft außerhalb des Sichtbaren. Für den User „passiert nichts".
  /// Der übernommene Vorschlag sagt es jetzt selbst.
  final Set<String> _taken = {};

  bool _busy = false;
  String? _error;

  /// Ein Vorschlag geht an die Seite – und bleibt sichtbar als übernommen
  /// stehen. Nichts verschwindet unter der Hand; wer zweimal tippt, richtet
  /// keinen Schaden an (die Seiten filtern Doppelte weg).
  void _accept(String suggestion) {
    setState(() => _taken.add(suggestion));
    widget.onAccept(suggestion);
  }

  Future<void> _ask() async {
    if (_busy) return;

    final input = widget.inputBuilder();
    if (input == null || input.trim().isEmpty) {
      setState(() {
        _error = 'Schreib kurz hin, worum es geht – dann leg ich los.';
        _suggestions = const [];
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _taken.clear();
    });

    final services = AppScope.of(context);

    try {
      final answer = await services.ai.run(
        widget.task,
        input: input,
        tone: services.settings.current.tone,
      );
      if (!mounted) return;

      setState(() {
        _suggestions = widget.singleLine
            ? [answer.trim()]
            : AiSuggestions.linesOf(answer);
        _busy = false;
        if (_suggestions.isEmpty) {
          _error =
              'Da kam nichts Brauchbares zurück. Mach ruhig selbst weiter.';
        }
      });

      if (_suggestions.isNotEmpty) _revealSuggestions();
    } on AiUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _suggestions = const [];
        // Kein Fehler des Users – und kein Grund, den Ablauf zu stoppen.
        _error = error.reason;
      });
    }
  }

  /// Holt die frischen Vorschläge zuverlässig in den sichtbaren Bereich.
  ///
  /// Ohne das lag der eigentliche Fehler: Auf kleinen Screens erscheinen die
  /// Vorschläge unter dem Textfeld – und weil beim Fragen oft noch die Tastatur
  /// oben steht, rutschten die Kacheln darunter oder unter den Blattrand. Ein
  /// Tipp auf „Übernehmen" landete dann im Nichts; für den User „passiert
  /// nichts". Also erst die Tastatur schließen, dann den Block in den Blick
  /// scrollen.
  ///
  /// Angefasst wird der **Anfang** des Blocks, nicht sein Ende. Vorher zog
  /// `alignment: 1` die Unterkante an den Blattrand – bei sechs Vorschlägen
  /// ist der Block höher als das Sichtfeld, und dann standen genau die ersten
  /// Kacheln oben außerhalb. Der User sah die Mitte einer Liste, deren Anfang
  /// er nie zu Gesicht bekam.
  void _revealSuggestions() {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || Scrollable.maybeOf(context) == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    if (!services.ai.isEnabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final texts = ToneTexts(services.settings.current.tone);

    return Container(
      key: const Key('ai_box'),
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _suggestions.isEmpty ? texts.aiOffer : texts.aiResultTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_busy)
            // Bewusst Text statt Ladekringel: Der flackert nur und hängt in
            // Widget-Tests.
            Text(
              texts.aiWorking,
              key: const Key('ai_busy'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else if (_suggestions.isEmpty)
            OutlinedButton.icon(
              key: const Key('ai_ask'),
              onPressed: _ask,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(texts.askAi),
            )
          else ...[
            for (var i = 0; i < _suggestions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SuggestionTile(
                  index: i,
                  text: _suggestions[i],
                  label: widget.acceptLabel,
                  taken: _taken.contains(_suggestions[i]),
                  onTap: () => _accept(_suggestions[i]),
                ),
              ),
            const SizedBox(height: 4),
            // Umbruch statt starrer Reihe: Nebeneinander passten die drei
            // Knöpfe nur auf dem Tablet. Auf dem Telefon lief die Reihe
            // rechts aus dem Bild – „Alle übernehmen" war da, aber halb
            // abgeschnitten und in keinem Fall vollständig zu treffen.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.onAcceptAll != null && _suggestions.length > 1)
                  FilledButton(
                    key: const Key('ai_accept_all'),
                    // Alles übernommen heißt: hier ist nichts mehr zu holen.
                    // Der Block macht Platz für die Liste, in der die
                    // Vorschläge jetzt stehen.
                    onPressed: () {
                      final all = _suggestions;
                      setState(() {
                        _suggestions = const [];
                        _taken.clear();
                      });
                      widget.onAcceptAll!(all);
                    },
                    child: const Text('Alle übernehmen'),
                  ),
                TextButton(
                  key: const Key('ai_again'),
                  onPressed: _ask,
                  child: const Text('Nochmal'),
                ),
                TextButton(
                  key: const Key('ai_dismiss'),
                  onPressed: () => setState(() {
                    _suggestions = const [];
                    _taken.clear();
                  }),
                  child: const Text('Danke, reicht'),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('ai_error'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.index,
    required this.text,
    required this.label,
    required this.taken,
    required this.onTap,
  });

  final int index;
  final String text;
  final String label;

  /// Schon angetippt. Die Kachel bleibt trotzdem bedienbar – wer sie noch
  /// einmal braucht, kommt heran, und doppelt wird nichts.
  final bool taken;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('ai_suggestion_$index'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
              const SizedBox(width: 8),
              if (taken)
                Row(
                  key: Key('ai_suggestion_taken_$index'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Übernommen',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
