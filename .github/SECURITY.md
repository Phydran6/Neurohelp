# Sicherheit

## Schwachstelle melden

Sicherheitsprobleme **nicht** als öffentliches Issue melden.

- Bevorzugt: GitHub → Security → *Report a vulnerability* (Private Vulnerability Reporting)
- Alternativ: E-Mail an it@phytech.de

Bitte mit Beschreibung, Schritten zum Nachstellen und betroffener Version. Rückmeldung
erfolgt in der Regel innerhalb von 7 Tagen.

## Unterstützte Versionen

Solange das Projekt vor 1.0 ist, wird ausschließlich die jeweils neueste Version gepflegt.

## Sicherheitsmodell der App

Siehe [docs/KONZEPT.md](../docs/KONZEPT.md), Abschnitte 13 und 14.

- **Lokal-first:** Nutzerdaten (Historie, Kontakte, Notizen, Termine, Aufgaben) liegen auf dem Gerät
- **App-Sperre** beim Start: Biometrie, Rückfallebene PIN/Passwort
- **MFA** per TOTP (RFC 6238) nur bei Einrichtung und sensiblen Aktionen
- **Security Keys** (FIDO2 / WebAuthn) optional
- Über das Backend laufen ausschließlich: KI-Verarbeitung, Reset-Mails, Kontoverwaltung
- Die App spricht **nie** direkt mit KI-Anbietern – alle Aufrufe gehen über die Backend-Schicht

## Secrets

Es gehören keinerlei Zugangsdaten ins Repository. Signaturschlüssel, Store-Zugänge und
API-Schlüssel liegen ausschließlich in GitHub-Secrets. Die [.gitignore](.gitignore) blockt die
üblichen Dateitypen zusätzlich ab.

Falls doch einmal ein Secret eingecheckt wurde: sofort beim jeweiligen Anbieter widerrufen und
neu ausstellen. Ein Entfernen aus der Git-Historie allein reicht nicht.
