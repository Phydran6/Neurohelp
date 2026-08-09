import 'message_draft.dart';

/// Übergibt eine fertige Nachricht an die zuständige System-App.
///
/// Konzept, Abschnitt 10, Schritt 6: Die Mail-App des Geräts wird
/// **vorausgefüllt** geöffnet. Eine eigene Mail-Integration ist bewusst
/// verworfen – zu aufwendig, Wartungsalbtraum.
///
/// Danach endet die Sicht der App: Es gibt keinen Rückkanal, weder auf
/// Android noch auf iOS.
abstract interface class MessageSender {
  /// Öffnet die System-App mit vorausgefüllten Feldern.
  ///
  /// Liefert `false`, wenn keine passende App gefunden wurde. Dann bleibt
  /// der Text stehen und der User kann ihn von Hand kopieren – kein
  /// Datenverlust, keine Sackgasse.
  Future<bool> handOver(MessageDraft draft, {String? senderName});
}

/// Ersatz für Tests und Umgebungen ohne Mail-App.
class NoMessageSender implements MessageSender {
  const NoMessageSender();

  @override
  Future<bool> handOver(MessageDraft draft, {String? senderName}) async =>
      false;
}
