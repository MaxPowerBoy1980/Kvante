// Pages Function: modtager tester-tilmeldinger fra landing-formularen.
// Verificerer Turnstile (når TURNSTILE_SECRET er sat) og gemmer i KV (binding: SIGNUPS).

const MAX_FIELD = 1000;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function onRequestPost(context) {
  const { request, env } = context;

  let form;
  try {
    form = await request.formData();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  // Honeypot: rigtige brugere udfylder aldrig dette felt.
  if ((form.get("website") || "").trim() !== "") {
    return json({ ok: true }); // lad bots tro det lykkedes
  }

  const email = (form.get("email") || "").trim().slice(0, 254);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ error: "invalid_email" }, 400);
  }

  // Turnstile-verifikation — kun håndhævet når secret er konfigureret,
  // så siden virker fra første deploy og hærdes ved at sætte env-variablen.
  if (env.TURNSTILE_SECRET) {
    const token = form.get("cf-turnstile-response") || "";
    const verify = await fetch(
      "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          secret: env.TURNSTILE_SECRET,
          response: token,
          remoteip: request.headers.get("CF-Connecting-IP"),
        }),
      }
    );
    const outcome = await verify.json();
    if (!outcome.success) {
      return json({ error: "turnstile_failed" }, 403);
    }
  }

  if (!env.SIGNUPS) {
    // KV-namespace ikke bundet endnu — fejl tydeligt frem for at miste tilmeldinger.
    return json({ error: "storage_not_configured" }, 503);
  }

  const entry = {
    email,
    name: (form.get("name") || "").trim().slice(0, MAX_FIELD),
    role: (form.get("role") || "").trim().slice(0, 50),
    message: (form.get("message") || "").trim().slice(0, MAX_FIELD),
    submitted_at: new Date().toISOString(),
    country: request.headers.get("CF-IPCountry") || null,
  };

  const key = `signup:${entry.submitted_at}:${crypto.randomUUID()}`;
  await env.SIGNUPS.put(key, JSON.stringify(entry));

  return json({ ok: true });
}
