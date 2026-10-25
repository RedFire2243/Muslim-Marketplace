# Voice search transcription

`POST /functions/v1/transcribe-search` accepts JSON `{ "audio": "<base64 WAV>" }`
and returns `{ "transcript": "..." }`. The recording must be canonical WAV with
16 kHz, mono, 16-bit PCM, between 0.4 and 16 seconds. The extra second allows
native audio buffering around the app's 15-second timer. Transcripts are capped
at 300 characters; errors contain only a stable `error` code.

Set `GEMINI_API_KEY` and optionally `GEMINI_MODEL` in the function environment.
The default model is `gemini-3.8-flash`. Neither setting belongs in the app.
Supabase supplies `SUPABASE_URL` and `SUPABASE_ANON_KEY` to hosted functions.

JWT gateway verification remains enabled. The handler also verifies the bearer
token through Supabase Auth and requires a non-anonymous user. CORS supports
authenticated browser clients without using cookies. Each worker allows six
attempts per user per minute, 60 total attempts per minute and four concurrent
Gemini calls. Apply a shared gateway quota before deploying at scale: in-memory
limits reset on a worker restart and are separate across workers.

For explicitly local development only, `VOICE_ALLOW_LOCAL_DEMO=true` allows a
private-network caller without a user session. This requires an HTTP local or
private `SUPABASE_URL`, no hosted deployment markers, and a private socket peer.
Forwarded headers and request fields cannot enable the bypass. All local demo
clients share the same six-attempt budget; browser origins must be localhost.
When serving with the Supabase CLI, bypassing its JWT gateway also requires the
explicit local `--no-verify-jwt` option. Do not deploy that option.

The handler uses standard web APIs with no dependencies. Run its mocked tests
with Node 24 or later:

```sh
node --test supabase/functions/transcribe-search/handler_test.ts
```
