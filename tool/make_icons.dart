// Bereitet das Quell-Icon für die Icon-Erzeugung auf.
//
// Das gelieferte Bild hat runde Ecken und einen weißen Rand eingebacken.
// Beides ist für App-Icons falsch:
//
//   - iOS rundet selbst. Eingebackene Ecken werden doppelt gerundet, der
//     weiße Rest bleibt als heller Zipfel sichtbar.
//   - Android schneidet aus einem adaptiven Icon je nach Gerät Kreis,
//     Quadrat oder Squircle. Dafür braucht es Vordergrund und Hintergrund
//     getrennt, mit Luft am Rand.
//
// Erzeugt zwei Dateien:
//   app_icon_square.png      randlos, deckend - Quelle für iOS und das
//                            klassische Android-Icon
//   app_icon_foreground.png  nur das Motiv, freigestellt und eingerückt -
//                            Vordergrund des adaptiven Android-Icons
//
// Aufruf: dart run tool/make_icons.dart

import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';

/// Ab welcher Helligkeit ein Pixel nicht mehr als Hintergrund zählt.
///
/// Der Hintergrund ist sehr dunkel, Motiv und Umlaufbahnen sind deutlich
/// heller. Ein einzelner Messpunkt reicht nicht – eine Umlaufbahn kann genau
/// dort verlaufen.
const int _backgroundMaxChannel = 90;

/// Wie weit vom Rand nach innen nach weißen Resten gesucht wird.
const double _borderBand = 0.14;

/// Ein Pixel gilt als "weißer Rand", wenn alle Kanäle darüber liegen.
const int _whiteThreshold = 232;

/// Wie unbunt ein Pixel sein muss, um als Schattenkante zu gelten.
const int _greySpread = 26;

/// Ab welcher Helligkeit eine unbunte Stelle als Schattenkante gilt.
const int _greyBrightness = 105;

int _max(int a, int b) => a > b ? a : b;

int _min(int a, int b) => a < b ? a : b;

/// Anteil der Fläche, den das Motiv im adaptiven Icon einnimmt. Android
/// beschneidet bis zu 25% je Seite - 70% ist der sichere Bereich.
const double _foregroundScale = 0.78;

/// Bis zu diesem Abstand zur Hintergrundfarbe gilt ein Pixel als Hintergrund.
const double _keyLow = 30;

/// Ab diesem Abstand gilt ein Pixel als Motiv.
const double _keyHigh = 62;

void main() {
  final source = File('assets/icons/app_icon.png');
  if (!source.existsSync()) {
    stderr.writeln('assets/icons/app_icon.png fehlt.');
    exit(1);
  }

  final original = decodePng(source.readAsBytesSync());
  if (original == null) {
    stderr.writeln('Das Bild konnte nicht gelesen werden.');
    exit(1);
  }

  final image = original.numChannels == 4
      ? original
      : original.convert(numChannels: 4);

  final background = _sampleBackground(image);
  stdout.writeln(
    'Hintergrundfarbe: '
    'rgb(${background.r}, ${background.g}, '
    '${background.b})',
  );

  final square = _writeSquare(image, background);
  _writeForeground(square, background);

  stdout.writeln('Fertig.');
}

/// Bestimmt die Hintergrundfarbe als häufigste dunkle Farbe im Bild.
///
/// Robuster als ein Messpunkt: Die dunkle Fläche ist mit Abstand die
/// größte, das Motiv fällt nicht ins Gewicht.
_Rgb _sampleBackground(Image image) {
  final counts = <int, int>{};

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (pixel.a < 250) continue;

      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      if (r > _backgroundMaxChannel ||
          g > _backgroundMaxChannel ||
          b > _backgroundMaxChannel) {
        continue;
      }

      final key = (r << 16) | (g << 8) | b;
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }

  if (counts.isEmpty) return const _Rgb(11, 16, 36);

  var best = counts.keys.first;
  var bestCount = 0;
  counts.forEach((key, count) {
    if (count > bestCount) {
      best = key;
      bestCount = count;
    }
  });

  return _Rgb((best >> 16) & 0xFF, (best >> 8) & 0xFF, best & 0xFF);
}

/// Eine schlichte Farbe – reicht hier und erspart die Umwege über [Color].
class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;
}

/// Randlose Fassung: Der weiße Rand und die runden Ecken werden durch die
/// Hintergrundfarbe ersetzt.
///
/// Ersetzt wird nur im äußeren Band. So bleiben helle Stellen im Motiv –
/// etwa die Leuchtpunkte der Umlaufbahnen – unangetastet.
Image _writeSquare(Image image, _Rgb background) {
  final result = image.clone();
  final bandX = (image.width * _borderBand).round();
  final bandY = (image.height * _borderBand).round();
  var replaced = 0;

  for (var y = 0; y < result.height; y++) {
    for (var x = 0; x < result.width; x++) {
      final inBand =
          x < bandX ||
          y < bandY ||
          x >= result.width - bandX ||
          y >= result.height - bandY;
      if (!inBand) continue;

      final pixel = result.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      final isWhitish =
          r >= _whiteThreshold && g >= _whiteThreshold && b >= _whiteThreshold;

      // Zwischen weißem Rand und dunklem Icon liegt eine graue Schattenkante.
      // Sie ist unbunt – daran lässt sie sich von den farbigen Umlaufbahnen
      // unterscheiden, die stellenweise bis dicht an den Rand reichen.
      final brightness = (r + g + b) ~/ 3;
      final spread = [r, g, b].reduce(_max) - [r, g, b].reduce(_min);
      final isGreyEdge = spread <= _greySpread && brightness >= _greyBrightness;

      if (isWhitish || isGreyEdge || pixel.a < 250) {
        result.setPixelRgba(
          x,
          y,
          background.r,
          background.g,
          background.b,
          255,
        );
        replaced++;
      }
    }
  }

  // Sicherheitsnetz: Ein App-Icon darf keine Transparenz enthalten, sonst
  // lehnt App Store Connect es ab.
  for (var y = 0; y < result.height; y++) {
    for (var x = 0; x < result.width; x++) {
      final pixel = result.getPixel(x, y);
      if (pixel.a < 255) {
        result.setPixelRgba(
          x,
          y,
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          255,
        );
      }
    }
  }

  final square = copyResize(
    result,
    width: 1024,
    height: 1024,
    interpolation: Interpolation.cubic,
  );

  File('assets/icons/app_icon_square.png').writeAsBytesSync(encodePng(square));
  stdout.writeln(
    'app_icon_square.png geschrieben ($replaced Randpixel ersetzt)',
  );
  return square;
}

/// Vordergrund für das adaptive Android-Icon: nur das Motiv, freigestellt,
/// eingerückt und auf durchsichtigem Grund.
///
/// Die dunkle Karte darf hier **nicht** mit hinein – Android legt seinen
/// eigenen Hintergrund darunter und beschneidet die Form. Läge die Karte im
/// Vordergrund, sähe man eine Kachel in der Kachel.
///
/// Freigestellt wird über den Abstand zur Hintergrundfarbe: knapp daneben
/// heißt durchsichtig, weit weg heißt deckend, dazwischen wird weich
/// übergeblendet. Dadurch bleibt das Leuchten der Umlaufbahnen erhalten.
void _writeForeground(Image squared, _Rgb background) {
  final keyed = squared.clone();

  for (var y = 0; y < keyed.height; y++) {
    for (var x = 0; x < keyed.width; x++) {
      final pixel = keyed.getPixel(x, y);
      final distance = _distance(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        background,
      );

      final int alpha;
      if (distance <= _keyLow) {
        alpha = 0;
      } else if (distance >= _keyHigh) {
        alpha = 255;
      } else {
        alpha = ((distance - _keyLow) / (_keyHigh - _keyLow) * 255).round();
      }

      keyed.setPixelRgba(
        x,
        y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        alpha,
      );
    }
  }

  const size = 1024;
  final inner = (size * _foregroundScale).round();
  final offset = (size - inner) ~/ 2;

  final canvas = Image(width: size, height: size, numChannels: 4);
  fill(canvas, color: ColorRgba8(0, 0, 0, 0));

  final motif = copyResize(
    keyed,
    width: inner,
    height: inner,
    interpolation: Interpolation.cubic,
  );

  compositeImage(canvas, motif, dstX: offset, dstY: offset);

  File(
    'assets/icons/app_icon_foreground.png',
  ).writeAsBytesSync(encodePng(canvas));
  stdout.writeln('app_icon_foreground.png geschrieben');
}

/// Abstand einer Farbe zur Hintergrundfarbe.
double _distance(int r, int g, int b, _Rgb background) {
  final dr = (r - background.r).toDouble();
  final dg = (g - background.g).toDouble();
  final db = (b - background.b).toDouble();
  return sqrt(dr * dr + dg * dg + db * db);
}
