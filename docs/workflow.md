# Kvante — Dagligt workflow

Widget-reference til daglig brug. Åbn den når du er i tvivl. Kopiér direkte fra kodeblokkene.

---

## Hvor er jeg?

| Maskine | Hvad kører der | Hvordan tilgår jeg |
|---|---|---|
| **MacBook** (`macair`) | iOS udvikling, Xcode, planning med Claude | Du sidder her |
| **Mac Mini** (`macmini4`) | Backend (FastAPI, SQLite, logs) | `ssh oleserver@macmini4` |

---

## Daglig rutine

```
edit → commit → ./scripts/deploy.sh → test fra iOS
```

Det er hele loopet. Backenden auto-reloader på Mac Mini via uvicorn `--reload`.

---

## Hvornår branch — hvornår direkte på main?

| Situation | Gør |
|---|---|
| Typo / lille doc-rettelse | **main direkte** |
| Lille sikker feature (1-3 commits) | **main direkte** |
| Flertrins-feature | **branch** |
| Risikabelt refactor | **branch** |
| Eksperimentelt | **branch** |

**Regel:** En branch må max leve 2-5 dage og indeholde ÉN feature. Ellers splitter vi den op.

---

## Start en ny feature-branch

```bash
git checkout main && git pull
git checkout -b feature/kort-beskrivelse
```

Navngivning: `feature/`, `fix/`, `refactor/`, `experiment/`, `docs/`

---

## Commit undervejs

```bash
git add <specifikke filer>        # ikke 'git add -A' som standard
git commit -m "feat: kort beskrivelse"
```

| Præfiks | Bruges til |
|---|---|
| `feat:` | Ny funktionalitet |
| `fix:` | Bugfix |
| `refactor:` | Omstrukturering uden ny funktionalitet |
| `chore:` | Vedligeholdelse (gitignore, configs) |
| `docs:` | Kun dokumentation |
| `test:` | Kun tests |

**Regler:**
- Imperativform: "add X", ikke "added X"
- Første linje under 70 tegn
- Body forklarer *hvorfor*, ikke *hvad*
- Én logisk ændring per commit

---

## Deploy til Mac Mini

```bash
./scripts/deploy.sh
```

Scriptet:
1. Fejler hvis du har uncommittede ændringer (så commit først!)
2. Pusher current branch til origin
3. SSH'er til Mac Mini og pull'er
4. Venter på uvicorn auto-reload
5. Verificerer backend health

---

## Afslut en feature — merge tilbage

```bash
git checkout main && git pull
git merge --no-ff feature/kort-beskrivelse
git push origin main
git branch -d feature/kort-beskrivelse
git push origin --delete feature/kort-beskrivelse
```

`--no-ff` bevarer at det var en feature-branch i historikken.

---

## SSH-kommandoer til Mac Mini

```bash
# Log ind
ssh oleserver@macmini4

# Følg backend logs live
ssh oleserver@macmini4 'tail -f ~/Library/Logs/Kvante/kvante.log'

# Health check
ssh oleserver@macmini4 'curl -sf http://localhost:8000/health'

# Kør tests
ssh oleserver@macmini4 'cd ~/Kvante/backend && .venv/bin/pytest'

# Genstart daemon (kun hvis plist selv ændres — ikke normal kode)
ssh oleserver@macmini4 'launchctl kickstart -k gui/$(id -u)/com.kvante.backend'
```

---

## Screenshot fra iPad til Claude

1. Åbn Kvante-appen på iPad
2. Tryk **den orange kamera-knap** nederst til højre
3. (Valgfrit) Skriv en kort note
4. Tryk **Send**
5. Sig til mig i chatten: **"kig på sidste screenshot"**

Fungerer kun i Debug builds. Shake-gesture virker også som backup.

---

## Fælles gotchas

- **Claude spørger altid før push og før destruktive git-operationer** — bekræft med "ja"
- **Force-push til main** er undtagelsen, ikke reglen. Spørg altid hvorfor
- **Uncommittede ændringer** på Mac Mini = commit først, aldrig smid væk uden at kigge
- **Xcode `xcuserstate`** er ignoreret — ignorér larm fra den
- **`*.db.backup`** er gitignoreret — SQLite-backups hører ikke i repo
- **Ved tvivl:** sig til Claude "er det her sikkert?" før du trykker enter

---

## Filer der styrer workflowet

| Fil | Formål |
|---|---|
| `CLAUDE.md` | Projekt-instruks der altid læses af Claude |
| `TODO.md` | Prioriteret feature-roadmap |
| `.gitignore` | Hvad der IKKE skal i repo |
| `scripts/deploy.sh` | Det eneste deploy-script du behøver |
| `backend/com.kvante.backend.plist` | Launchd daemon-config på Mac Mini |
| `docs/workflow.md` | Denne fil |

---

## Hurtig adgang til denne fil

```bash
# Åbn i din foretrukne markdown-viewer
open docs/workflow.md

# Eller i terminal
cat docs/workflow.md | less

# Tilføj denne linje til ~/.zshrc for en alias
alias kv='cat ~/code/Kvante/docs/workflow.md | less'
```

Efter alias: skriv bare `kv` hvor som helst for at se workflowet.
