# Bilder für den Play-Store-Eintrag

Hier hinein, bevor `fastlane metadata_only` oder `fastlane production` läuft.
Google verlangt diese Dateien; ohne sie bleibt der Eintrag unvollständig und
lässt sich nicht veröffentlichen.

| Datei bzw. Ordner | Größe | Pflicht |
|:--|:--|:--|
| `icon.png` | 512 × 512, PNG, keine Transparenz | ja |
| `featureGraphic.png` | 1024 × 500 | ja |
| `phoneScreenshots/` | 2 bis 8 Bilder, mindestens 320 px Kante | ja |
| `sevenInchScreenshots/`, `tenInchScreenshots/` | Tablets | nur wenn die App dort angeboten wird |

Die Bildschirmfotos entstehen im Arbeitsablauf
[store-screenshots.yml](../../../../../../.github/workflows/store-screenshots.yml).
Er erzeugt bisher nur die iOS-Größe 1320 × 2868 – die lässt sich für Play
unverändert verwenden, Google schreibt kein festes Seitenverhältnis vor.

Das Icon liegt als Quelle unter
[assets/icons/app_icon_square.png](../../../../../../assets/icons/app_icon_square.png)
und ist bereits 1024 × 1024; es muss nur auf 512 × 512 herunterskaliert werden.

Der Ordner ist absichtlich leer eingecheckt: Bildschirmfotos ändern sich mit
jedem Oberflächen-Umbau, und veraltete Bilder im Repository sind schlimmer als
keine.
