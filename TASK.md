# Task: Expose Kvante publicly for teachers and testers

> ## STATUS 2026-07-16 — Fase 1 næsten færdig
>
> **Besluttet arkitektur:** Fase 1 = landing + venteliste (DONE, live). Fase 2 = mobil web-demo
> mod nyt `/public/*` API-subset gennem Cloudflare Tunnel (ikke påbegyndt).
>
> **Live og verificeret end-to-end:**
> - https://kvante.mintworks.ai — landing page (Cloudflare Pages, projekt `kvante`,
>   git-connected til dette repo, root dir `web`, output `public`, ingen build command)
> - Tilmeldingsformular → Pages Function `web/functions/api/signup.js` → KV-namespace
>   `kvante-signups` (binding `SIGNUPS`, kun Production-environment). Rigtige tilmeldinger
>   bekræftet fra iPhone. Tilmeldinger læses i dashboard: Workers KV → kvante-signups → KV Pairs.
>
> **ENESTE udestående i fase 1 — Turnstile (bot-værn), aftalt flow:**
> 1. Bruger opretter widget: Turnstile → Add site → hostname `kvante.mintworks.ai`, mode Managed
> 2. Bruger sender SITE KEY i chatten → Claude erstatter `REPLACE_WITH_TURNSTILE_SITE_KEY`
>    i `web/public/index.html`, committer, pusher
> 3. Bruger sætter SECRET KEY selv: Workers & Pages → kvante → Settings → Variables and
>    secrets → Add → type Secret, navn `TURNSTILE_SECRET` (gælder fra næste deployment;
>    Claudes push i trin 2 udløser den)
> 4. Claude verificerer: POST uden token → 403; siden loader med widget; bruger tester fra telefon
>
> **Småting:** (a) Preview-environment mangler `SIGNUPS`-bindingen (503 på previews — valgfrit
> fix i Settings → Bindings med Preview valgt). (b) Testposter i KV fra verifikation kan slettes
> (`claude-test@example.com`). (c) Branch `feature/public-landing` er merget men ikke slettet.
>
> **Fase 2-forudsætninger (SKAL før backend eksponeres):** gate `/dev/*` + `/test/ocr`-routere,
> stram CORS (`allow_origins=["*"]` i `backend/app/main.py`), anonyme demo-sessions med kvoter.
> Bemærk: backend kører live med Claude Sonnet 4 (`.env` på macmini4) — kvoter beskytter API-regningen.

---

## Goal
Take my AI math assistant "Kvante" from a private backend on my Mac mini
to something I can share publicly: a link teachers can try, and that I
can post on social media to recruit testers.

## Context — existing infrastructure (all working, don't rebuild)
- Kvante backend: FastAPI/uvicorn on macmini4 (my Mac mini home server),
  port 8000, launchd service `com.kvante.backend`, code at
  /Users/oleserver/Kvante/backend. Local dev copy: ~/code/Kvante on this
  MacBook. Serves /docs and /openapi.json — inspect those for the API.
- macmini4 access: SSH oleserver@100.106.111.111 (Tailscale). Works
  non-interactively but with a bare PATH (use absolute paths) and NO
  sudo — I run sudo commands myself when given them.
- Port map on macmini4: 8000 Kvante, 8001 sundhed-mcp, 8002 finans-mcp.
- Cloudflare: I own the mintworks.ai zone. A Cloudflare Tunnel
  (`dashboard-tunnel`, config /etc/cloudflared/config.yml, LaunchDaemon
  with hand-written plist — `cloudflared service install` writes a broken
  one) already exposes finans-mcp.mintworks.ai and sundhed-mcp.mintworks.ai
  behind Access Service Auth. The same tunnel can take more hostnames.
- Existing sites: mintworks.ai (shared with a co-owner — do NOT touch that
  repo) and dash.mintworks.ai (my private ops dashboard, repo
  MaxPowerBoy1980/dashboard — reference for the Pages + tunnel pattern).
- Hard-won gotchas: Universal SSL covers single-level subdomains only
  (kvante.mintworks.ai fine, x.y.mintworks.ai not); Cloudflare Pages runs
  `npm ci` so package-lock.json must be complete; the *.pages.dev bare
  domain needs its own Access/protection entry (wildcards don't match the
  apex).

## Key difference from my previous project
The dashboard was private (locked to my email). Kvante is the opposite:
**strangers must reach it without a login wall**. That changes the threat
model — the backend runs on my home Mac mini, so the design must cover:
- rate limiting / abuse protection at the Cloudflare edge (WAF rules,
  maybe Turnstile) so my home server and any LLM API costs survive a
  social media post
- what happens when the Mac mini is down or overloaded (graceful failure)
- audience: teachers, possibly minors — think about what data is
  collected, terms/privacy basics for Denmark/EU, and content safety
- I want a simple feedback channel from testers

## Requirements
1. Public URL (suggest one — kvante.mintworks.ai or argue for something
   else) with a landing page that explains what Kvante is and lets a
   tester start using it immediately
2. Backend stays on macmini4, reached only through the Cloudflare Tunnel
   — never exposed directly
3. Mobile-first; teachers will open this from a phone in a classroom
4. Cheap/free tier only (Cloudflare free plan, no new paid services
   without asking me)

## First steps — do these before writing any code
- Inspect ~/code/Kvante and the backend on macmini4 (API surface, what
  frontend exists if any, how the assistant is invoked, what LLM/API keys
  it depends on)
- Then brainstorm with me: audience flow, abuse protection, hosting
  shape. Propose 2-3 architectures with trade-offs. Wait for my approval
  before building.
- I run all sudo and Cloudflare-dashboard steps myself — give me exact
  commands/clicks and explain them as we go; I want to learn.
