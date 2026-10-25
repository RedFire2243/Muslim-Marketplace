import { createVoiceSearchHandler } from "./handler.ts";

const handler = createVoiceSearchHandler({
  apiKey: Deno.env.get("GEMINI_API_KEY"),
  model: Deno.env.get("GEMINI_MODEL"),
  supabaseUrl: Deno.env.get("SUPABASE_URL"),
  supabaseAnonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY"),
  allowLocalDemo: Deno.env.get("VOICE_ALLOW_LOCAL_DEMO") === "true",
  hostedRuntime: Boolean(Deno.env.get("DENO_DEPLOYMENT_ID") || Deno.env.get("SB_REGION")),
});

Deno.serve((req, info) => handler(req, info.remoteAddr.hostname));
