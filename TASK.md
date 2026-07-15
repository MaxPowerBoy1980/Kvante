# Task: Expose Kvante publicly for teachers and testers

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
