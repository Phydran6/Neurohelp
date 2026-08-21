/// Ein Modell aus dem Verzeichnis von OpenRouter.
///
/// Bewusst nur die Felder, nach denen die App auswählt. Alles Weitere ist
/// Anbieterdetail und hat in der App nichts verloren.
class OpenRouterModel {
  const OpenRouterModel({
    required this.id,
    required this.name,
    required this.contextLength,
    required this.promptPrice,
    required this.completionPrice,
    this.inputModalities = const ['text'],
    this.outputModalities = const ['text'],
  });

  factory OpenRouterModel.fromJson(Map<String, Object?> json) {
    final pricing = json['pricing'];
    final architecture = json['architecture'];

    return OpenRouterModel(
      id: json['id']! as String,
      name: json['name'] as String? ?? json['id']! as String,
      contextLength: _readInt(json['context_length']),
      promptPrice: pricing is Map
          ? _readPrice(pricing['prompt'])
          : double.infinity,
      completionPrice: pricing is Map
          ? _readPrice(pricing['completion'])
          : double.infinity,
      inputModalities: architecture is Map
          ? _readStrings(architecture['input_modalities'])
          : const ['text'],
      outputModalities: architecture is Map
          ? _readStrings(architecture['output_modalities'])
          : const ['text'],
    );
  }

  final String id;
  final String name;
  final int contextLength;

  /// Preis je Token in US-Dollar. `0` heißt kostenlos.
  final double promptPrice;
  final double completionPrice;

  final List<String> inputModalities;
  final List<String> outputModalities;

  /// Ob das Modell nichts kostet.
  ///
  /// Der Namenszusatz `:free` allein wäre zu wenig: Es gibt auch Modelle
  /// ohne Zusatz, die nichts kosten. Der Preis ist die verlässliche Angabe.
  bool get isFree => promptPrice == 0 && completionPrice == 0;

  /// Ob das Modell Text hereinnimmt und Text herausgibt.
  ///
  /// Bild-, Sprach- und Einbettungsmodelle stehen in derselben Liste und
  /// würden sonst mitausgewählt.
  bool get isTextChat =>
      inputModalities.contains('text') && outputModalities.contains('text');

  static int _readInt(Object? raw) => switch (raw) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };

  static double _readPrice(Object? raw) => switch (raw) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value) ?? double.infinity,
    // Keine Preisangabe heißt: nicht anfassen. Lieber ein Modell auslassen
    // als dem User unbemerkt Guthaben abziehen.
    _ => double.infinity,
  };

  static List<String> _readStrings(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is String) entry,
    ];
  }
}
