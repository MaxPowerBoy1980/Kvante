# Kvante web — offentlig landing page

Statisk landing page + tester-tilmelding for [kvante.mintworks.ai](https://kvante.mintworks.ai).
Deployes via Cloudflare Pages (git-integration mod dette repo). Ingen build-step, ingen npm.

## Struktur

```
web/
├── public/            # Statiske filer (Pages "build output directory")
│   ├── index.html     # Hele landing-siden (inline CSS/JS)
│   ├── _headers       # Security headers
│   └── assets/        # Kvante pixelart (nedskaleret fra icons/)
└── functions/         # Cloudflare Pages Functions
    └── api/signup.js  # POST /api/signup → Turnstile-verifikation + KV
```

## Cloudflare Pages-opsætning

| Indstilling | Værdi |
|---|---|
| Root directory | `web` |
| Build command | *(tom)* |
| Build output directory | `public` |
| Production branch | `main` |

**Bindings/variabler (Settings → Functions / Environment variables):**

- KV-binding `SIGNUPS` → et KV-namespace (fx `kvante-signups`). Uden den svarer
  `/api/signup` med 503 frem for at miste tilmeldinger.
- Secret `TURNSTILE_SECRET` → secret key fra Turnstile-widget'en. Sættes den ikke,
  springes bot-verifikation over (honeypot-feltet gælder stadig).

**Turnstile:** Opret widget i Cloudflare-dashboardet (Turnstile → Add site,
hostname `kvante.mintworks.ai`), indsæt site key i `TURNSTILE_SITE_KEY` øverst i
`index.html`s `<script>`-blok, og sæt secret key som `TURNSTILE_SECRET`.

**Husk:** `*.pages.dev`-domænet skal have sin egen Access/WAF-behandling —
wildcards dækker ikke apex'et.

## Læs tilmeldinger

Dashboard: Workers & Pages → KV → `kvante-signups` → View entries.
Hver nøgle er `signup:<ISO-tidsstempel>:<uuid>` med JSON-værdi
(`email`, `name`, `role`, `message`, `submitted_at`, `country`).
