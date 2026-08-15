import 'package:flutter/material.dart';

import '../domain/intro_slides.dart';

/// Die Punkte eines Erklärbildschirms.
///
/// Überschrift und Einleitungssatz bleiben außen vor: Im Onboarding stellt
/// die Seite selbst beides schon oben hin, im Hilfe-Bereich sitzt es im
/// dortigen Aufbau. Hier steht nur die Liste – einmal gebaut, zweimal
/// benutzt.
class IntroSlideView extends StatelessWidget {
  const IntroSlideView({required this.slide, super.key});

  final IntroSlide slide;

  /// Symbole gehören in die Oberfläche, nicht zu den Texten. Deshalb hängen
  /// sie hier am Schlüssel des Punktes statt im Datenmodell.
  static IconData _iconFor(String id) => switch (id) {
    'anruf' => Icons.call_outlined,
    'termin' => Icons.event_outlined,
    'nachricht' => Icons.mail_outlined,
    'aufgabe' => Icons.checklist_outlined,
    'schritte' => Icons.arrow_forward,
    'historie' => Icons.history,
    'lokal' => Icons.lock_outline,
    'kein-druck' => Icons.spa_outlined,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in slide.points)
          Padding(
            key: Key('intro_point_${point.id}'),
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _iconFor(point.id),
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        point.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
