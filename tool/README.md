# tool/ – Entwicklerwerkzeuge

Läuft nur auf dem Rechner, nie in der App und nie in der CI.

[← Technische Doku](../docs/TECHNIK.md) · [Änderungen](CHANGELOG.md)

---

## make_icons.dart

Bereitet das App-Icon auf. Beide Plattformen verlangen Unterschiedliches:

- **iOS** rundet die Ecken selbst und lehnt Transparenz ab. Ein Icon mit
  eingebackenen runden Ecken wird doppelt gerundet, der Rest bleibt als heller
  Zipfel sichtbar.
- **Android** schneidet aus einem adaptiven Icon je nach Gerät Kreis, Quadrat
  oder Squircle. Dafür braucht es Vordergrund und Hintergrund getrennt, mit
  Luft am Rand.

```bash
dart run tool/make_icons.dart
```

| Aus | Wird zu | Wofür |
|---|---|---|
| `assets/icons/app_icon.png` | `app_icon_square.png` | randlos, deckend – iOS und klassisches Android-Icon |
| | `app_icon_foreground.png` | Motiv freigestellt und eingerückt – adaptives Android-Icon |

Danach die eigentlichen Icons erzeugen:

```bash
dart run flutter_launcher_icons
```

**Beim Austausch des Icons** nur das Original ersetzen und beide Befehle
nacheinander ausführen.

### Wie das Freistellen funktioniert

Über den Abstand zur Hintergrundfarbe: knapp daneben heißt durchsichtig, weit
weg heißt deckend, dazwischen wird weich übergeblendet. So bleibt das Leuchten
der Umlaufbahnen erhalten, statt an einer harten Kante abzureißen.

Die Hintergrundfarbe wird nicht geraten, sondern als häufigste dunkle Farbe
aus dem Bild bestimmt. Ein einzelner Messpunkt reicht nicht – dort kann eine
Umlaufbahn verlaufen.
