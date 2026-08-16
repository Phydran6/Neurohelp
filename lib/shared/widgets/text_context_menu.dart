import 'package:flutter/material.dart';

/// Das Auswahlmenü über einem Textfeld – ohne „Text scannen".
///
/// Flutter setzt in dieses Menü von sich aus einen Punkt, der die Kamera
/// öffnet und Text abfotografiert. Beim wiederholten Antippen eines
/// Eingabefelds stand er plötzlich da und führte aus dem Ablauf heraus –
/// mitten im Schreiben ist das eine Falle, kein Angebot.
///
/// Ausschneiden, Kopieren, **Einfügen** und Alles auswählen bleiben. Text aus
/// der Zwischenablage zu übernehmen ist genau das, was man an dieser Stelle
/// will. Das Abfotografieren bekommt später einen eigenen Platz, an dem es
/// hingehört (etwa: auf einen Brief antworten).
Widget noScanContextMenu(
  BuildContext context,
  EditableTextState editableTextState,
) {
  final items = editableTextState.contextMenuButtonItems
      .where((item) => item.type != ContextMenuButtonType.liveTextInput)
      .toList();

  if (items.isEmpty) return const SizedBox.shrink();

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: items,
  );
}
