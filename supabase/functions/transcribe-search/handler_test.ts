import assert from "node:assert/strict";
import { test } from "node:test";

import { createVoiceSearchHandler, isPrivateAddress, MAX_AUDIO_BYTES } from "./handler.ts";
import type { VoiceServerOptions } from "./handler.ts";

function wav(length = 16_044): string {
  const bytes = new Uint8Array(length);
  const view = new DataView(bytes.buffer);
  function ascii(offset: number, value: string) {
    for (let i = 0; i < value.length; i++) bytes[offset + i] = value.charCodeAt(i);
  }
  ascii(0, "RIFF");
  view.setUint32(4, length - 8, true);
  ascii(8, "WAVEfmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, 16000, true);
  view.setUint32(28, 32000, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  ascii(36, "data");
  view.setUint32(40, length - 44, true);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function post(body: unknown = { audio: wav() }, headers: Record<string, string> = {}): Request {
  return new Request("http://localhost/functions/v1/transcribe-search", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

function gemini(transcript = "a robotics mentor"): Response {
  return Response.json({
    candidates: [{ content: { parts: [{ text: JSON.stringify({ transcript }) }] } }],
  });
}

function local(options: Partial<VoiceServerOptions> = {}) {
  return createVoiceSearchHandler({
    apiKey: "server-only-test-key",
    supabaseUrl: "http://127.0.0.1:54321",
    allowLocalDemo: true,
    fetch: async () => gemini(),
    ...options,
  });
}

test("development bypass requires explicit operator setting, a local backend and a private peer", async () => {
  for (const options of [
    { allowLocalDemo: false },
    { supabaseUrl: "https://project.supabase.co" },
    { hostedRuntime: true },
  ]) {
    const response = await local(options)(post(), "192.168.1.2");
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: "unauthorized" });
  }
  assert.equal((await local()(post(), "8.8.8.8")).status, 401);
  assert.equal((await local()(post())).status, 401);
  assert.equal((await local()(post(), "192.168.1.2")).status, 200);
});

test("caller-controlled bypass fields and forwarding headers never replace authentication", async () => {
  const response = await local({ allowLocalDemo: false })(
    post({ audio: wav(), allowLocalDemo: true }, {
      "x-forwarded-for": "127.0.0.1",
      authorization: "Bearer invented-token",
    }), "127.0.0.1",
  );
  // No Supabase auth configuration is available; it fails closed.
  assert.equal(response.status, 503);
});

test("production validates a real user with Supabase Auth and keeps the Gemini key upstream", async () => {
  const calls: { url: string; init?: RequestInit }[] = [];
  const handler = createVoiceSearchHandler({
    apiKey: "server-only-test-key",
    supabaseUrl: "https://project.supabase.co/",
    supabaseAnonKey: "public-project-key",
    fetch: async (input, init) => {
      const url = String(input);
      calls.push({ url, init });
      if (url.endsWith("/auth/v1/user")) return Response.json({ id: "verified-user", is_anonymous: false });
      return gemini("  a   robotics mentor  ");
    },
  });
  const response = await handler(post(undefined, { authorization: "Bearer user-token" }));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { transcript: "a robotics mentor" });
  assert.equal(calls.length, 2);
  assert.equal(calls[0].url, "https://project.supabase.co/auth/v1/user");
  assert.equal(new Headers(calls[0].init?.headers).get("authorization"), "Bearer user-token");
  assert.equal(new Headers(calls[1].init?.headers).get("x-goog-api-key"), "server-only-test-key");
  assert.equal(calls[1].url.includes("server-only-test-key"), false);
  const body = JSON.parse(String(calls[1].init?.body));
  assert.equal(body.contents[0].parts[0].inlineData.mimeType, "audio/wav");
  assert.equal(body.contents[0].parts[0].inlineData.data, wav());
});

test("a present but invalid or anonymous bearer token is refused", async () => {
  for (const authResponse of [
    Response.json({ message: "bad token" }, { status: 401 }),
    Response.json({ id: "anonymous-user", is_anonymous: true }),
    Response.json({ role: "anon" }),
  ]) {
    let requests = 0;
    const handler = createVoiceSearchHandler({
      apiKey: "server-only-test-key",
      supabaseUrl: "https://project.supabase.co",
      supabaseAnonKey: "public-project-key",
      fetch: async () => { requests++; return authResponse; },
    });
    const response = await handler(post(undefined, { authorization: "Bearer wrong-token" }));
    assert.equal(response.status, 401);
    assert.equal(requests, 1);
  }
});

test("JSON input must contain bounded valid WAV16k mono16-bit audio", async () => {
  let requests = 0;
  const handler = local({ fetch: async () => { requests++; return gemini(); } });
  const wrongFormat = atob(wav()).split("");
  wrongFormat[22] = String.fromCharCode(2); // Stereo is not the app's format.
  for (const body of [null, [], {}, { audio: 1 }, { audio: "aGVsbG8=" }, { audio: btoa(wrongFormat.join("")) }]) {
    const response = await handler(post(body), "127.0.0.1");
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: "invalid_audio" });
  }
  assert.equal(requests, 0);
});

test("the full 16-second native-buffer allowance is accepted and longer clips are rejected", async () => {
  assert.equal((await local()(post({ audio: wav(MAX_AUDIO_BYTES) }), "127.0.0.1")).status, 200);
  const response = await local()(post({ audio: wav(MAX_AUDIO_BYTES + 1000) }), "127.0.0.1");
  assert.equal(response.status, 413);
});

test("a missing content-length cannot bypass the streamed request body limit", async () => {
  const response = await local()(post({ audio: "A".repeat(700_000) }), "127.0.0.1");
  assert.equal(response.status, 413);
  assert.deepEqual(await response.json(), { error: "payload_too_large" });
});

test("malformed JSON and incorrect content type never reach Gemini", async () => {
  const handler = local({ fetch: async () => { throw new Error("must not fetch"); } });
  const malformed = new Request("http://localhost", {
    method: "POST", headers: { "content-type": "application/json" }, body: "{",
  });
  assert.equal((await handler(malformed, "127.0.0.1")).status, 400);
  assert.equal((await handler(post(undefined, { "content-type": "text/plain" }), "127.0.0.1")).status, 415);
});

test("local demo browser CORS allows localhost only and never accepts a public origin", async () => {
  const handler = local();
  const allowed = await handler(new Request("http://localhost", {
    method: "OPTIONS", headers: { origin: "http://localhost:8080" },
  }));
  assert.equal(allowed.status, 204);
  assert.equal(allowed.headers.get("Access-Control-Allow-Origin"), "http://localhost:8080");
  const denied = await handler(post(undefined, { origin: "https://unrelated.example" }), "127.0.0.1");
  assert.equal(denied.status, 403);
});

test("all local demo clients share one six-attempt per-minute budget", async () => {
  let time = 0;
  const handler = local({ now: () => time });
  for (let i = 0; i < 6; i++) {
    assert.equal((await handler(post(), `192.168.1.${i + 1}`)).status, 200);
  }
  const limited = await handler(post(), "192.168.1.99");
  assert.equal(limited.status, 429);
  assert.equal(limited.headers.get("Retry-After"), "60");
  time = 60_001;
  assert.equal((await handler(post(), "192.168.1.99")).status, 200);
});

test("concurrency is capped while Gemini requests are in flight", async () => {
  const pending: ((response: Response) => void)[] = [];
  const handler = local({ fetch: async () => await new Promise<Response>((resolve) => pending.push(resolve)) });
  const requests = Array.from({ length: 4 }, () => handler(post(), "127.0.0.1"));
  while (pending.length < 4) await new Promise((resolve) => setTimeout(resolve, 0));
  const response = await handler(post(), "127.0.0.1");
  assert.equal(response.status, 429);
  for (const resolve of pending) resolve(gemini());
  for (const result of await Promise.all(requests)) assert.equal(result.status, 200);
});

test("the global budget bounds unauthenticated requests before Auth calls", async () => {
  const handler = local({ allowLocalDemo: false });
  for (let i = 0; i < 60; i++) assert.equal((await handler(post())).status, 401);
  assert.equal((await handler(post())).status, 429);
});

test("upstream status, timeout and malformed output become stable safe error codes", async () => {
  for (const [upstream, expectedStatus, expectedCode] of [
    [401, 503, "voice_not_configured"],
    [404, 503, "voice_not_configured"],
    [429, 429, "rate_limited"],
    [500, 502, "upstream_error"],
  ] as const) {
    const handler = local({ fetch: async () => new Response("SECRET upstream diagnostic", { status: upstream }) });
    const response = await handler(post(), "127.0.0.1");
    assert.equal(response.status, expectedStatus);
    assert.deepEqual(await response.json(), { error: expectedCode });
  }
  const timeout = await local({ fetch: async () => { throw new DOMException("SECRET", "TimeoutError"); } })(post(), "127.0.0.1");
  assert.equal(timeout.status, 504);
  assert.deepEqual(await timeout.json(), { error: "timeout" });
  const malformed = await local({ fetch: async () => new Response("not JSON") })(post(), "127.0.0.1");
  assert.equal(malformed.status, 502);
  assert.deepEqual(await malformed.json(), { error: "upstream_error" });
});

test("output ignores thought parts, trims whitespace and caps transcript length", async () => {
  const handler = local({ fetch: async () => Response.json({
    candidates: [{ content: { parts: [
      { text: "private reasoning", thought: true },
      { text: JSON.stringify({ transcript: "  " + "word ".repeat(100) }) },
    ] } }],
  }) });
  const response = await handler(post(), "127.0.0.1");
  const result = await response.json();
  assert.equal(result.transcript.length <= 300, true);
  assert.equal(result.transcript.includes("private reasoning"), false);
  assert.equal(result.transcript.startsWith("word word"), true);
});

test("private-peer recognition rejects public and spoofed addresses", () => {
  for (const address of ["127.0.0.1", "10.1.2.3", "192.168.0.2", "172.31.255.1", "::1", "::ffff:192.168.1.2", "fd12::1"]) {
    assert.equal(isPrivateAddress(address), true, address);
  }
  for (const address of ["8.8.8.8", "172.32.0.1", "999.1.1.1", "192.168.1.2.evil.example", "localhost.evil.example"]) {
    assert.equal(isPrivateAddress(address), false, address);
  }
});
