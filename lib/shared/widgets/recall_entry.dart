import 'package:flutter/material.dart';

import '../../core/history/domain/history_entry.dart';
import 'big_action_button.dart';
import 'history_check.dart';

/// Wie der User in den ersten Schritt eines Ablaufs hineingeht.
///
/// Vorher gab es überall nur [typing]: eine Frage, ein leeres Feld, ein
/// Weiter-Knopf, der aus blieb, bis etwas dastand. Wer nur wusste, *dass* da
/// was war, kam keinen Schritt weit – genau die Situation, für die es diese
/// App gibt.
enum RecallMode {
  /// „Weißt du es noch, oder soll ich nachschauen?"
  asking,

  /// Der User weiß es und schreibt es hin.
  typing,

  /// Die App gräbt in der Historie und führt anders heran.
  helping,
}

/// Die Eingangsfrage vor dem ersten Feld (Konzept, Abschnitt 10, Schritt 2).
///
/// Zwei Wege, beide gleichwertig. Kein Weg führt in eine Sackgasse.
class RecallChoice extends StatelessWidget {
  const RecallChoice({
    required this.prefix,
    required this.onKnow,
    required this.onHelp,
    this.question = 'Weißt du noch, worum es geht?',
    this.knowLabel = 'Ich weiß es',
    this.recallLabel = 'Ich weiß nur, dass da was war – hilf mir',
    super.key,
  });

  /// Vorsilbe der Widget-Schlüssel, z.B. `msg` ergibt `msg_know`.
  final String prefix;

  final String question;
  final String knowLabel;
  final String recallLabel;
  final VoidCallback onKnow;
  final VoidCallback onHelp;

  /// Der Hinweis unter der Frage – überall derselbe.
  static const String hint =
      'Beides ist in Ordnung. Wenn du es nicht mehr weißt, schaue ich zuerst '
      'in deiner Historie nach.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          key: Key('${prefix}_question'),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          hint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        BigActionButton(
          key: Key('${prefix}_know'),
          label: knowLabel,
          icon: Icons.edit_outlined,
          onPressed: onKnow,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: Key('${prefix}_recall'),
          onPressed: onHelp,
          icon: const Icon(Icons.search),
          label: Text(recallLabel),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ],
    );
  }
}

/// Was die App beim Graben gefunden hat – oder eben nicht.
///
/// **Reihenfolge aus dem Konzept:** Zuerst gräbt die App. Erst wenn sie nichts
/// findet, kommen sanfte Rückfragen als Gedächtnisstütze. Gedächtnis
/// anstupsen kann überfordern; die Denkarbeit macht die App, der User ist
/// letzte Instanz.
class RecallPanel extends StatelessWidget {
  const RecallPanel({
    required this.prefix,
    required this.state,
    required this.hits,
    required this.onPick,
    required this.nudges,
    this.subtitleOf,
    super.key,
  });

  final String prefix;
  final HistoryCheckState state;
  final List<HistoryEntry> hits;
  final void Function(HistoryEntry entry) onPick;

  /// Die Rückfragen für dieses Feature. Bewusst ohne KI: Der Weg muss auch
  /// mit abgeschaltetem Schalter tragen.
  final List<String> nudges;

  final String? Function(HistoryEntry entry)? subtitleOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HistoryCheckHeader(state: state),
        for (final entry in hits) ...[
          HistoryEntryTile(
            entry: entry,
            subtitle: subtitleOf?.call(entry) ?? entry.contact,
            onTap: () => onPick(entry),
          ),
          const SizedBox(height: 10),
        ],
        if (state == HistoryCheckState.empty)
          MemoryNudges(prefix: prefix, nudges: nudges),
      ],
    );
  }
}

/// Sanfte Rückfragen als Gedächtnisstütze.
///
/// Bewusst ohne Antwortfelder: Es sind Anstupser zum Nachdenken, keine
/// Pflichtfragen. Und immer mit dem Satz, der den Druck herausnimmt – wer
/// nichts weiß, kommt trotzdem weiter.
class MemoryNudges extends StatelessWidget {
  const MemoryNudges({required this.prefix, required this.nudges, super.key});

  final String prefix;
  final List<String> nudges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: Key('${prefix}_nudges'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vielleicht hilft eine dieser Fragen:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          for (final nudge in nudges)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '· $nudge',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Und wenn nichts kommt: einfach weiter. Das klärt sich unterwegs.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Rückfragen je Feature. An einer Stelle, damit sie im Ton zusammenpassen.
abstract final class RecallNudges {
  static const List<String> message = [
    'Kam Post, eine Mail oder ein Anruf?',
    'Ging es um Geld – Rechnung, Beitrag, Rückzahlung?',
    'War eine Frist dabei?',
    'Amt, Versicherung, Vermieter, Arzt, Vertrag?',
  ];

  static const List<String> call = [
    'Ging es um einen Termin?',
    'Wollte jemand einen Rückruf?',
    'Musstest du nachfragen oder widersprechen?',
    'Ging es um Geld oder eine Frist?',
  ];

  static const List<String> appointment = [
    'Gesundheit – Arzt, Zahnarzt, Physio?',
    'Musst du irgendwo persönlich hin?',
    'Liegt ein Brief mit einem Datum herum?',
    'Hat jemand einen Termin von dir erwartet?',
  ];

  static const List<String> task = [
    'Was liegt seit Tagen herum?',
    'Wovor drückst du dich gerade?',
    'Ist irgendwo eine Frist?',
    'Was hat jemand von dir erwartet?',
  ];
}

/// Der Titel für einen Vorgang, zu dem noch kein Thema feststeht.
///
/// Ein leerer Titel wäre in der Historie eine leere Zeile. Dieser Platzhalter
/// sagt, was Sache ist, und wird überschrieben, sobald das Thema da ist.
const String kUnknownTopic = 'Noch ohne Thema';
