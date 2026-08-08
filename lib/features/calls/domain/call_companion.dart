import '../../../core/companion/companion_style.dart';
import 'call_plan.dart';

export '../../../core/companion/companion_style.dart' show CompanionStyle;

/// Die Begleitung während des Telefonats.
///
/// Das ist die **geteilte Kernkomponente** von Anruf- und Termin-Feature.
/// Dart sieht eine Schnittstelle; Android und iOS setzen sie unterschiedlich
/// um – bewusst, statt einen schlechten Kompromiss für beide zu bauen.
abstract interface class CallCompanion {
  /// Welche Darstellungen diese Plattform anbietet.
  ///
  /// Android liefert [CompanionStyle.overlay] und
  /// [CompanionStyle.splitScreen], iOS ausschließlich
  /// [CompanionStyle.liveActivity].
  List<CompanionStyle> get availableStyles;

  /// Ob während des Gesprächs Notizen getippt werden können.
  ///
  /// Auf iOS ist das `false`: eine Live Activity ist nicht frei
  /// beschreibbar. Die Notizen werden dort erst in der Nachbereitung
  /// erfasst – eine bewusste funktionale Konsequenz, kein Bug.
  bool get supportsLiveNotes;

  /// Ob der User der App die nötige Berechtigung gegeben hat
  /// (Android: Overlay-Berechtigung, iOS: Live Activities erlaubt).
  Future<bool> get isPermissionGranted;

  /// Fragt die Berechtigung an. Liefert, ob sie danach vorliegt.
  Future<bool> requestPermission();

  /// Zeigt die Begleitung mit den Stichpunkten an.
  Future<void> show(CallPlan plan, {required CompanionStyle style});

  /// Aktualisiert die angezeigten Stichpunkte, etwa nach einer Korrektur.
  Future<void> update(CallPlan plan);

  /// Blendet die Begleitung wieder aus.
  Future<void> hide();
}

/// Ersatz für Umgebungen ohne Begleitung – Tests und der Fall, dass der User
/// die Berechtigung verweigert.
///
/// Der Anruf funktioniert auch ohne Begleitung: die Stichpunkte stehen dann
/// eben nur vorher auf dem Bildschirm.
class NoCallCompanion implements CallCompanion {
  const NoCallCompanion();

  @override
  List<CompanionStyle> get availableStyles => const [];

  @override
  bool get supportsLiveNotes => false;

  @override
  Future<bool> get isPermissionGranted async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(CallPlan plan, {required CompanionStyle style}) async {}

  @override
  Future<void> update(CallPlan plan) async {}

  @override
  Future<void> hide() async {}
}
