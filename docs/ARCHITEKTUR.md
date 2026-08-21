# Architektur

Umsetzung von Abschnitt 17 des [Konzepts](KONZEPT.md). Dieses Dokument beschreibt das *Wie*,
das Konzept das *Was* und *Warum*.

---

## Grundentscheidungen

| Entscheidung | Konsequenz |
|---|---|
| **Lokal-first** | Alle Nutzerdaten in SQLite auf dem Gerät. Kein Zwang zur Cloud |
| **Backend nur wo nötig** | KI-Verarbeitung, Reset-Mails, Kontoverwaltung – sonst nichts |
| **Anbieteragnostische KI** | Die App kennt nur „die KI", nie einen konkreten Anbieter |
| **Plattformen nicht zwingen** | Anrufbegleitung ist auf Android und iOS bewusst verschieden |
| **Historie als Rückgrat** | Jede Handlung wird geloggt, jedes Feature startet mit einem Historie-Check |

---

## Schichten

```
┌──────────────────────────────────────────────┐
│ presentation   Screens, Widgets, State       │
├──────────────────────────────────────────────┤
│ domain         Modelle, Use Cases, Regeln    │
├──────────────────────────────────────────────┤
│ data           Repositories                  │
│                ├─ lokal   (SQLite/Drift)     │
│                └─ remote  (Supabase)         │
├──────────────────────────────────────────────┤
│ platform       MethodChannel → Android/iOS   │
└──────────────────────────────────────────────┘
```

Abhängigkeiten zeigen ausschließlich nach unten. `domain` kennt weder Flutter noch Supabase.

## Ordner

```
lib/
├─ app/          App-Wurzel und globales Setup
├─ core/         Querschnitt (config, theme, router, db, logging, ai)
├─ features/     ein Ordner je Feature, intern data/domain/presentation
└─ shared/       feature-übergreifende Widgets
```

Ein Feature darf **nicht** in ein anderes Feature hineingreifen. Gemeinsames wandert nach
`core/` oder `shared/`.

---

## Historie (Abschnitt 12 des Konzepts)

Das zentrale Log ist die tragende Struktur, nicht ein Nebenfeature. Jeder Feature-Einstieg
fragt zuerst die Historie ab, bevor der User etwas eingeben muss.

| Feature | Geloggt wird |
|---|---|
| Anruf | Kontakt, Datum, Thema, Ergebnis |
| Termin | Buchung, Phase der Nachverfolgung |
| Nachricht | Text, Empfänger, Status (übergeben / bestätigt / offen) |
| Aufgabe | Jeder einzelne Schritt + Fortschritt |

Umsetzung: eine gemeinsame Ereignistabelle in SQLite mit Feature-Typ, Zeitstempel, Bezug und
Status. Feature-spezifische Details liegen in eigenen Tabellen und verweisen darauf.

---

## KI-Schicht

Details in [KI-ZUGANG.md](KI-ZUGANG.md), Begründung in Abschnitt 17a des
[Konzepts](KONZEPT.md).

```
App ──▶ AiClient (Interface)
          └─▶ LayeredAiClient
                 ├─▶ OpenRouterAiClient   direkt vom Gerät   [wenn verbunden]
                 │      └─▶ Modell, zur Laufzeit gewählt
                 └─▶ SupabaseAiClient     über das Backend   [Standard]
                        └─▶ Edge Function „ai-proxy" ─▶ Claude / OpenAI
```

- Die App schickt Aufgabentyp + Kontext, nie Anbieter oder Modellnamen. Sie kennt
  **keinen Anbieter**, nur „die KI"
- **Kein Modell ist fest verdrahtet.** Das Verzeichnis wird zur Laufzeit abgefragt, weil es
  rotiert
- Der KI-Toggle aus dem Onboarding schaltet die gesamte Schicht ab – ohne KI läuft die App
  vollständig lokal
- Fällt eine Stufe aus, geht es **stillschweigend** eine Stufe tiefer. Nie eine technische
  Fehlermeldung

### Die Proxy-Regel – bewusst differenziert

| Zugang | Weg | Warum |
|---|---|---|
| Eigene gehostete KI | über das Backend | Schutz der eigenen Infrastruktur und des dort liegenden Schlüssels |
| Nutzereigener Zugang | direkt vom Gerät | Ein Proxy hätte keinen Zweck und wäre nur eine weitere Station, auf der fremde Daten landen |

Der nutzereigene Schlüssel liegt verschlüsselt im Keystore bzw. der Keychain – nie im
Backend, nie in der SQLite-Datenbank.

Jeder KI-abhängige Ablauf braucht trotzdem einen lokalen Weg ohne KI: Es kann sein, dass
gar keine Stufe trägt.

---

## Plattform-Kanäle

Nativer Code nur dort, wo Flutter nicht hinkommt:

| Zweck | Android | iOS |
|---|---|---|
| Anrufbegleitung | Overlay (`SYSTEM_ALERT_WINDOW`) / Split-Screen | Live Activity + Dynamic Island (ActivityKit) |
| Anruf starten | Intent | URL-Scheme |
| Biometrie | BiometricPrompt | LocalAuthentication |
| Kalender | Gerätekalender-API | EventKit |

Die Anrufbegleitung ist die gemeinsame Kernkomponente von Anruf- und Termin-Feature. Dart
sieht **eine** Schnittstelle (`CallCompanion`), die je Plattform verschieden implementiert ist.

Funktionale Folge auf iOS: Live Activities sind nicht frei beschreibbar. Notizen werden dort
erst im Nachbereitungsschritt erfasst.

---

## Konfiguration

Alle Build-Zeit-Werte über `--dart-define`, gebündelt in
[`lib/core/config/app_config.dart`](../lib/core/config/app_config.dart). Keine Schlüssel im
Quelltext, keine `.env`-Datei im Repository.

---

## Teststrategie

| Ebene | Ort | Umfang |
|---|---|---|
| Unit | `test/unit/` | domain und data – hier liegt der Schwerpunkt |
| Widget | `test/widget/` | Screens, Zustände, Barrierefreiheit |
| Integration | `integration_test/` | vollständige Flows auf Gerät/Emulator |

Plattform-Kanäle werden in Tests gemockt; ihr echtes Verhalten wird per Integrationstest auf
dem Gerät geprüft.
