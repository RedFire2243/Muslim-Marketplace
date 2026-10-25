// The client sends only audio. Gemini credentials and model selection stay here.
// No external packages are needed, so the handler can also be tested with Node.
export const MAX_AUDIO_BYTES = 44 + 16 * 16000 * 2;
const MAX_BASE64_LENGTH = Math.ceil(MAX_AUDIO_BYTES / 3) * 4;
const MAX_BODY_BYTES = MAX_BASE64_LENGTH + 1024;
const WINDOW_MS = 60_000;
const GLOBAL_REQUESTS_PER_MINUTE = 60;
const USER_REQUESTS_PER_MINUTE = 6;
const MAX_CONCURRENT_REQUESTS = 4;
const MAX_RATE_LIMIT_USERS = 1000;
const DEFAULT_MODEL = "gemini-3.8-flash";

const INSTRUCTIONS = `You transcribe short voice searches for a community marketplace in Central Jersey, where Muslims look for services, jobs, internships, mentors, collaborators, volunteering and local businesses.

Write down what the speaker asks for, in the language they speak, exactly as they say it. Leave out filler words (um, uh) and false starts. Do not answer, summarise, correct or add to the request.

Town names that may come up: New Brunswick, Piscataway, Edison, Highland Park, East Brunswick, North Brunswick, South Brunswick, Somerset, Princeton, Plainsboro, West Windsor, Hamilton, Trenton, Lawrenceville, Metuchen, Woodbridge, Sayreville, Old Bridge, Monroe, Bridgewater.

If the recording is silent, only noise, or you cannot make out the words, return an empty transcript. Never guess.`;

export interface VoiceServerOptions {
  apiKey?: string;
  model?: string;
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  // An operator-controlled local development option, never a request field.
  allowLocalDemo?: boolean;
  hostedRuntime?: boolean;
  fetch?: typeof fetch;
  now?: () => number;
}

class BodyTooLarge extends Error {}

// This only controls explicitly enabled development mode. Production always
// validates the access token with Supabase Auth, even behind its JWT gateway.
export function isPrivateAddress(address: string): boolean {
  const host = address.replace(/^\[|\]$/g, "").toLowerCase();
  if (host === "localhost" || host === "::1") return true;
  if (host.startsWith("::ffff:")) return isPrivateAddress(host.slice(7));
  if (/^(fc|fd)[0-9a-f]{2}:/.test(host) || /^fe[89ab][0-9a-f]:/.test(host)) {
    return true;
  }
  const parts = host.split(".");
  if (parts.length !== 4 || parts.some((p) => !/^\d{1,3}$/.test(p) || Number(p) > 255)) {
    return false;
  }
  const [a, b] = parts.map(Number);
  return a === 127 || a === 10 || (a === 192 && b === 168) ||
    (a === 172 && b >= 16 && b <= 31) || (a === 169 && b === 254);
}

function localBackend(url: string): boolean {
  try {
    const parsed = new URL(url);
    return parsed.protocol === "http:" &&
      (isPrivateAddress(parsed.hostname) || parsed.hostname === "kong");
  } catch {
    return false;
  }
}

async function boundedText(body: ReadableStream<Uint8Array> | null, limit: number): Promise<string> {
  if (!body) return "";
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > limit) {
        await reader.cancel();
        throw new BodyTooLarge();
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

function validWav(audio: string): boolean {
  if (audio.length < 60 || audio.length > MAX_BASE64_LENGTH || audio.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(audio)) return false;
  let binary: string;
  try {
    binary = atob(audio);
  } catch {
    return false;
  }
  // The app emits a canonical PCM WAV header. Reject other formats and extra
  // chunks instead of guessing their duration or asking Gemini to decode them.
  if (binary.length < 44 + 12_800 || binary.length > MAX_AUDIO_BYTES || binary.length % 2 !== 0) {
    return false;
  }
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  const view = new DataView(bytes.buffer);
  return binary.slice(0, 4) === "RIFF" &&
    view.getUint32(4, true) === bytes.length - 8 &&
    binary.slice(8, 16) === "WAVEfmt " &&
    view.getUint32(16, true) === 16 &&
    view.getUint16(20, true) === 1 &&
    view.getUint16(22, true) === 1 &&
    view.getUint32(24, true) === 16000 &&
    view.getUint32(28, true) === 32000 &&
    view.getUint16(32, true) === 2 &&
    view.getUint16(34, true) === 16 &&
    binary.slice(36, 40) === "data" &&
    view.getUint32(40, true) === bytes.length - 44;
}

function transcriptFrom(response: unknown): string {
  if (typeof response !== "object" || response === null) throw new Error("invalid_output");
  const candidates = (response as { candidates?: unknown }).candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return "";
  const parts = candidates[0]?.content?.parts;
  if (!Array.isArray(parts)) throw new Error("invalid_output");
  const text = parts.filter((p) => p && typeof p.text === "string" && p.thought !== true)
    .map((p) => p.text).join("").trim();
  if (!text) return "";
  const parsed = JSON.parse(text);
  if (typeof parsed?.transcript !== "string") throw new Error("invalid_output");
  return parsed.transcript.replace(/\s+/g, " ").trim().slice(0, 300).trim();
}

export function createVoiceSearchHandler(options: VoiceServerOptions) {
  const request = options.fetch ?? fetch;
  const now = options.now ?? Date.now;
  const apiKey = options.apiKey?.trim();
  const supabaseUrl = (options.supabaseUrl ?? "").replace(/\/$/, "");
  const localDemo = options.allowLocalDemo === true && options.hostedRuntime !== true &&
    localBackend(supabaseUrl);
  let globalWindow = { startedAt: now(), count: 0 };
  const users = new Map<string, { startedAt: number; count: number }>();
  let inFlight = 0;

  // In-memory limits bound an individual worker. Production deployments should
  // also enforce a shared quota at the gateway across instances and restarts.
  function takeRequest(key: string): boolean {
    const time = now();
    for (const [user, window] of users) {
      if (time - window.startedAt >= WINDOW_MS) users.delete(user);
    }
    const window = users.get(key);
    if (!window) {
      if (users.size >= MAX_RATE_LIMIT_USERS) return false;
      users.set(key, { startedAt: time, count: 1 });
      return true;
    }
    if (window.count >= USER_REQUESTS_PER_MINUTE) return false;
    window.count++;
    return true;
  }

  return async (req: Request, remoteAddress?: string): Promise<Response> => {
    const origin = req.headers.get("origin");
    const localOrigin = origin !== null && /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/.test(origin);
    const cors = {
      "Access-Control-Allow-Origin": localDemo ? (localOrigin ? origin : "null") : "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Cache-Control": "no-store",
      "Vary": "Origin",
    };
    function json(body: unknown, status = 200, extra: Record<string, string> = {}): Response {
      return new Response(JSON.stringify(body), {
        status,
        headers: { ...cors, "Content-Type": "application/json", ...extra },
      });
    }
    if (localDemo && origin !== null && !localOrigin) return json({ error: "origin_not_allowed" }, 403);
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

    const time = now();
    if (time - globalWindow.startedAt >= WINDOW_MS) globalWindow = { startedAt: time, count: 0 };
    if (++globalWindow.count > GLOBAL_REQUESTS_PER_MINUTE) {
      return json({ error: "rate_limited" }, 429, { "Retry-After": "60" });
    }
    if (req.headers.get("content-type")?.split(";", 1)[0].trim().toLowerCase() !== "application/json") {
      return json({ error: "unsupported_media_type" }, 415);
    }
    if (Number(req.headers.get("content-length")) > MAX_BODY_BYTES) {
      return json({ error: "payload_too_large" }, 413);
    }
    if (!apiKey) return json({ error: "voice_not_configured" }, 503);

    let userId: string;
    if (localDemo && remoteAddress !== undefined && isPrivateAddress(remoteAddress)) {
      // All local demo clients share one budget; caller-controlled IDs and
      // forwarded IP headers cannot obtain another bucket or bypass auth.
      userId = "local-demo";
    } else {
      const authorization = req.headers.get("authorization");
      if (!authorization || !/^Bearer \S+$/.test(authorization)) {
        return json({ error: "unauthorized" }, 401);
      }
      if (!supabaseUrl || !options.supabaseAnonKey) return json({ error: "voice_not_configured" }, 503);
      try {
        const auth = await request(`${supabaseUrl}/auth/v1/user`, {
          headers: { authorization, apikey: options.supabaseAnonKey },
          signal: AbortSignal.timeout(5000),
        });
        if (!auth.ok) return json({ error: "unauthorized" }, 401);
        const user = JSON.parse(await boundedText(auth.body, 16_384));
        if (typeof user?.id !== "string" || user.id.length === 0 || user.is_anonymous === true) {
          return json({ error: "unauthorized" }, 401);
        }
        userId = user.id;
      } catch {
        return json({ error: "authentication_unavailable" }, 503);
      }
    }
    if (!takeRequest(userId) || inFlight >= MAX_CONCURRENT_REQUESTS) {
      return json({ error: "rate_limited" }, 429, { "Retry-After": "60" });
    }

    let audio: string;
    try {
      const body = JSON.parse(await boundedText(req.body, MAX_BODY_BYTES));
      if (typeof body !== "object" || body === null || Array.isArray(body) ||
        typeof body.audio !== "string") return json({ error: "invalid_audio" }, 400);
      audio = body.audio;
      if (audio.length > MAX_BASE64_LENGTH) return json({ error: "audio_too_long" }, 413);
      if (!validWav(audio)) return json({ error: "invalid_audio" }, 400);
    } catch (error) {
      return json({ error: error instanceof BodyTooLarge ? "payload_too_large" : "invalid_json" },
        error instanceof BodyTooLarge ? 413 : 400);
    }

    inFlight++;
    try {
      const response = await request(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(options.model?.trim() || DEFAULT_MODEL)}:generateContent`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
          signal: AbortSignal.timeout(20_000),
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: INSTRUCTIONS }] },
            contents: [{ role: "user", parts: [{ inlineData: { mimeType: "audio/wav", data: audio } }] }],
            generationConfig: {
              responseMimeType: "application/json",
              responseSchema: {
                type: "OBJECT",
                properties: { transcript: { type: "STRING" } },
                required: ["transcript"],
              },
              maxOutputTokens: 512,
            },
          }),
        },
      );
      if (!response.ok) {
        await response.body?.cancel();
        if (response.status === 429) return json({ error: "rate_limited" }, 429);
        if ([401, 403, 404].includes(response.status)) return json({ error: "voice_not_configured" }, 503);
        return json({ error: "upstream_error" }, 502);
      }
      const result = JSON.parse(await boundedText(response.body, 65_536));
      return json({ transcript: transcriptFrom(result) });
    } catch (error) {
      if (error instanceof Error && ["TimeoutError", "AbortError"].includes(error.name)) {
        return json({ error: "timeout" }, 504);
      }
      return json({ error: "upstream_error" }, 502);
    } finally {
      inFlight--;
    }
  };
}
