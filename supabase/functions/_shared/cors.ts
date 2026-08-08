// Die App ruft die Funktionen nativ auf, nicht aus dem Browser. CORS ist nur
// für lokale Tests und ein späteres Web-Target nötig.

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

/** Beantwortet einen Preflight-Request, sonst `null`. */
export function handlePreflight(req: Request): Response | null {
  if (req.method !== 'OPTIONS') return null;
  return new Response(null, { status: 204, headers: corsHeaders });
}
