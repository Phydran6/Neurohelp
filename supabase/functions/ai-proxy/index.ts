// Neurohelp KI-Proxy
//
// Bauvorgabe aus dem Konzept (Abschnitt 17):
//   - Die App redet NIE direkt mit einem KI-Anbieter.
//   - Die App kennt keinen Anbieter, sie kennt nur "die KI".
//   - Ein Anbieterwechsel darf KEINE App-Änderung erfordern.
//
// Die App schickt einen Aufgabentyp (`task`) und Kontext. Welches Modell
// welchen Anbieters das beantwortet, entscheidet ausschließlich diese Funktion.

import Anthropic from 'npm:@anthropic-ai/sdk@0.68.0';
import OpenAI from 'npm:openai@4.104.0';

import { corsHeaders, handlePreflight } from '../_shared/cors.ts';
import { SYSTEM_PROMPTS, type TaskName, isKnownTask } from './prompts.ts';

type Provider = 'anthropic' | 'openai';

interface AiRequest {
  /** Aufgabentyp, z.B. "task.split". Kein Modellname, kein Anbieter. */
  task: string;
  /** Freitext des Users bzw. der zusammengetragene Kontext. */
  input: string;
  /** Tonfall aus den Einstellungen: locker | neutral | sachlich. */
  tone?: 'locker' | 'neutral' | 'sachlich';
}

interface AiResponse {
  text: string;
}

const DEFAULT_PROVIDER = (Deno.env.get('AI_PROVIDER') ?? 'anthropic') as Provider;
const ANTHROPIC_MODEL = Deno.env.get('ANTHROPIC_MODEL') ?? 'claude-opus-5';
const OPENAI_MODEL = Deno.env.get('OPENAI_MODEL') ?? 'gpt-5';
const MAX_TOKENS = 8000;

const TONE_HINTS: Record<NonNullable<AiRequest['tone']>, string> = {
  locker: 'Schreibe locker und kumpelhaft, wie ein Freund bei WhatsApp.',
  neutral: 'Schreibe freundlich und neutral.',
  sachlich: 'Schreibe knapp und sachlich, ohne Ausschmückung.',
};

Deno.serve(async (req: Request): Promise<Response> => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== 'POST') {
    return jsonError(405, 'Nur POST wird unterstützt.');
  }

  // Supabase prüft das JWT bereits vor dem Aufruf (verify_jwt = true).
  // Hier nur noch fachlich validieren.
  let body: AiRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError(400, 'Ungültiges JSON.');
  }

  if (!isKnownTask(body.task)) {
    return jsonError(400, `Unbekannte Aufgabe: ${body.task}`);
  }
  if (typeof body.input !== 'string' || body.input.trim().length === 0) {
    return jsonError(400, 'Feld "input" fehlt oder ist leer.');
  }

  const system = buildSystemPrompt(body.task, body.tone ?? 'locker');

  try {
    const text = DEFAULT_PROVIDER === 'openai'
      ? await callOpenAi(system, body.input)
      : await callAnthropic(system, body.input);

    return jsonOk({ text });
  } catch (error) {
    console.error('ai-proxy fehlgeschlagen', {
      task: body.task,
      provider: DEFAULT_PROVIDER,
      error: error instanceof Error ? error.message : String(error),
    });
    return jsonError(502, 'Die KI ist gerade nicht erreichbar.');
  }
});

function buildSystemPrompt(task: TaskName, tone: NonNullable<AiRequest['tone']>): string {
  return [
    SYSTEM_PROMPTS.base,
    TONE_HINTS[tone],
    SYSTEM_PROMPTS.tasks[task],
  ].join('\n\n');
}

async function callAnthropic(system: string, input: string): Promise<string> {
  const client = new Anthropic({ apiKey: requireEnv('ANTHROPIC_API_KEY') });

  const response = await client.messages.create({
    model: ANTHROPIC_MODEL,
    max_tokens: MAX_TOKENS,
    system,
    messages: [{ role: 'user', content: input }],
  });

  // Sicherheitsklassifizierer können ablehnen – das ist ein HTTP 200 mit
  // leerem bzw. unvollständigem content. Vor dem Auslesen prüfen.
  if (response.stop_reason === 'refusal') {
    throw new Error('Anfrage wurde vom Anbieter abgelehnt.');
  }

  const text = response.content
    .filter((block): block is Anthropic.TextBlock => block.type === 'text')
    .map((block) => block.text)
    .join('')
    .trim();

  if (text.length === 0) {
    throw new Error('Leere Antwort vom Anbieter.');
  }
  return text;
}

async function callOpenAi(system: string, input: string): Promise<string> {
  const client = new OpenAI({ apiKey: requireEnv('OPENAI_API_KEY') });

  const response = await client.chat.completions.create({
    model: OPENAI_MODEL,
    max_completion_tokens: MAX_TOKENS,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: input },
    ],
  });

  const text = response.choices[0]?.message?.content?.trim() ?? '';
  if (text.length === 0) {
    throw new Error('Leere Antwort vom Anbieter.');
  }
  return text;
}

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Umgebungsvariable ${name} ist nicht gesetzt.`);
  }
  return value;
}

function jsonOk(payload: AiResponse): Response {
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
