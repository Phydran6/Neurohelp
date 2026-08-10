// Neurohelp – Konto löschen
//
// Umsetzung von Abschnitt 14 des Konzepts: Der User muss alles wieder
// loswerden können, ohne jemanden zu fragen.
//
// Was hier passiert:
//   1. Das Nutzer-Token prüfen (wer bin ich?).
//   2. Alles serverseitige zu diesem Konto löschen: Profil,
//      Wiederherstellungs-Codes, MFA-Faktoren und zuletzt den Auth-Eintrag.
//   3. Eine Bestätigung an die hinterlegte Adresse schicken – **danach**,
//      denn vorher steht nicht fest, dass es geklappt hat.
//
// Der Service-Role-Schlüssel liegt ausschließlich hier. Die App kennt ihn
// nicht und darf ihn nie kennen.

import { createClient } from 'npm:@supabase/supabase-js@2.58.0';
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts';

import { corsHeaders, handlePreflight } from '../_shared/cors.ts';

interface DeleteResponse {
  deleted: boolean;
  /** Ob zusätzlich eine Bestätigungs-Mail rausging. */
  emailed: boolean;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== 'POST') {
    return jsonError(405, 'Nur POST wird unterstützt.');
  }

  const authorization = req.headers.get('Authorization');
  if (!authorization) {
    return jsonError(401, 'Ohne Anmeldung geht das nicht.');
  }

  const url = requireEnv('SUPABASE_URL');
  const admin = createClient(url, requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Wer ruft? Das Token entscheidet – niemals eine Id aus dem Body.
  const asUser = createClient(url, requireEnv('SUPABASE_ANON_KEY'), {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await asUser.auth.getUser();
  const user = userData?.user;
  if (userError || !user) {
    return jsonError(401, 'Die Anmeldung ist abgelaufen.');
  }

  const email = user.email ?? null;

  try {
    // Die Fremdschlüssel stehen auf `on delete cascade`; explizit zu löschen
    // ist trotzdem richtig: So bleibt nichts liegen, wenn jemand später eine
    // Tabelle ohne Kaskade ergänzt.
    await admin.from('recovery_codes').delete().eq('user_id', user.id);
    await admin.from('profiles').delete().eq('id', user.id);

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError) throw deleteError;
  } catch (error) {
    console.error('Konto konnte nicht gelöscht werden', {
      error: error instanceof Error ? error.message : String(error),
    });
    return jsonError(500, 'Das Löschen ist fehlgeschlagen.');
  }

  const emailed = email ? await sendConfirmation(email) : false;

  return jsonOk({ deleted: true, emailed });
});

/// Schickt die Bestätigung – und scheitert nicht laut, wenn kein Mailversand
/// eingerichtet ist. Das Konto ist an dieser Stelle schon weg; eine fehlende
/// Mail darf das nicht in einen Fehler verwandeln.
async function sendConfirmation(to: string): Promise<boolean> {
  const host = Deno.env.get('SMTP_HOST');
  const user = Deno.env.get('SMTP_USER');
  const password = Deno.env.get('SMTP_PASS');
  const from = Deno.env.get('SMTP_FROM') ?? user;

  if (!host || !user || !password || !from) {
    console.warn('Kein SMTP eingerichtet – keine Bestätigungs-Mail versandt.');
    return false;
  }

  const client = new SMTPClient({
    connection: {
      hostname: host,
      port: Number(Deno.env.get('SMTP_PORT') ?? '465'),
      tls: Deno.env.get('SMTP_TLS') !== 'false',
      auth: { username: user, password },
    },
  });

  try {
    await client.send({
      from,
      to,
      subject: 'Dein Neurohelp-Konto ist gelöscht',
      content: [
        'Hallo,',
        '',
        'dein Neurohelp-Konto wurde gelöscht. Damit ist alles weg, was bei',
        'uns zu dir gespeichert war: dein Profil, deine',
        'Wiederherstellungs-Codes und deine Zwei-Faktor-Einstellung.',
        '',
        'Was auf deinem Gerät liegt – deine Vorgänge, Notizen und Termine –',
        'lag nie bei uns. Das wirst du los, indem du die App deinstallierst.',
        '',
        'Du musst nichts weiter tun. Falls du das nicht selbst ausgelöst',
        'hast, melde dich bitte bei uns.',
        '',
        'Neurohelp',
      ].join('\n'),
    });
    return true;
  } catch (error) {
    console.error('Bestätigungs-Mail nicht versandt', {
      error: error instanceof Error ? error.message : String(error),
    });
    return false;
  } finally {
    await client.close();
  }
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Umgebungsvariable ${name} ist nicht gesetzt.`);
  }
  return value;
}

function jsonOk(payload: DeleteResponse): Response {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function jsonError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
