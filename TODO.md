# Kvante TODO

## Aktive fejl

- [ ] **Timeout ved scan fra iPhone** — Bonjour finder server (grønt ikon), men upload/scan request timer ud. Debug: tjek APIClient timeout, server-logs, og billedstørrelse
- [ ] **launchd plist paths** — `com.kvante.backend.plist` har hardcoded `/Users/oleserver/` — skal matche Mac Mini's faktiske bruger

## Oprydning

- [ ] Slet overflødige Info.plist-hjælpefiler fra `ios/Kvante/Kvante/`:
  - `add_infoplist.py`
  - `add_infoplist.sh`
  - `validate_infoplist.py`
  - `CHECKLIST_INFOPLIST.md`
  - `INFO_PLIST_SETUP.md`
  - `README_INFOPLIST.md`

## Konfiguration

- [ ] `.env` mangler på serveren (kun `.env.example` findes) — opret med Gemini API key

## Næste features

- [ ] Test fuld workflow: scan side → vælg opgave → vis eksempel → scan svar → feedback
- [ ] Billedpreprocessering: test med rigtige blyant-på-papir fotos (CLAHE + sharpening)
- [ ] Prompt-iteration med rigtige tekstbogsider

## Løste problemer

- [x] Bonjour mDNS browse virkede ikke — fix: AsyncZeroconf + bind til LAN-IP (ikke alle interfaces inkl. Tailscale)
- [x] Xcode projekt opsat med korrekt mappestruktur
- [x] Kamera-tilladelse tilføjet i Info.plist
- [x] Bonjour service discovery virker fra iPhone
- [x] `%en0` interface-suffix fjernet fra resolved URL
