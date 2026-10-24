// Suggests structured profile fields from onboarding answers using Claude.
//
// The Anthropic API key lives only in this function's environment
// (`supabase secrets set ANTHROPIC_API_KEY=...`). The app treats the response
// as untrusted: it drops anything not grounded in the member's own words and
// falls back to its rule-based parser on any error, timeout or refusal.
import Anthropic from "npm:@anthropic-ai/sdk@1.3.0";

const MODEL = Deno.env.get("EXTRACTION_MODEL") ?? "claude-opus-5-5";
const MAX_ANSWER_LENGTH = 1000;

const LISTING_TYPES = [
  "service",
  "job",
  "internship",
  "mentorship",
  "collaboration",
  "volunteer",
  "business",
];

const AREAS = [
  "New Brunswick", "Piscataway", "Edison", "Highland Park", "East Brunswick",
  "North Brunswick", "South Brunswick", "Somerset", "Princeton", "Plainsboro",
  "West Windsor", "Hamilton", "Trenton", "Lawrenceville", "Metuchen",
  "Woodbridge", "Sayreville", "Old Bridge", "Monroe", "Bridgewater",
];

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["skills", "interests", "goals", "area"],
  properties: {
    skills: { type: "array", items: { type: "string" } },
    interests: { type: "array", items: { type: "string" } },
    goals: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["type", "role", "subjects"],
        properties: {
          type: { type: "string", enum: LISTING_TYPES },
          role: { type: "string", enum: ["seeking", "offering"] },
          subjects: { type: "array", items: { type: "string" } },
        },
      },
    },
    area: { type: "string" },
  },
};

const SYSTEM = `You turn a community member's onboarding answers into structured profile suggestions for a local marketplace. The member will review and edit everything you return.

Only record what the member explicitly wrote. Never infer skills, qualifications, interests, budgets or locations. Studying a subject is not a skill. Attending a university does not set a location. When something is not stated, leave the list empty or the area as an empty string.

skills: things the member says they can do, in short noun phrases using their words.
interests: topics the member says they enjoy or are interested in.
goals: one entry per distinct intent.
- type is the kind of opportunity: service, job, internship, mentorship, collaboration, volunteer, or business.
- role is "seeking" when the member wants to receive or find it, and "offering" when they provide it.
  Looking for a mentor = mentorship/seeking. Able to mentor others = mentorship/offering.
  Looking for an internship = internship/seeking. Hiring an intern = internship/offering.
  Looking for a job = job/seeking. Hiring staff = job/offering.
  Needing a tutor or other help = service/seeking. Offering tutoring or another service = service/offering.
  Wanting to volunteer = volunteer/seeking. Recruiting volunteers = volunteer/offering.
  Wanting teammates or co-founders = collaboration/seeking. Available to join a project = collaboration/offering.
  Running a business = business/offering. Looking for local businesses = business/seeking.
- subjects: the topics of that goal, copied from the member's words (for example "robotics").
area: exactly one of these names if the member named it, otherwise an empty string: ${AREAS.join(", ")}.`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function readAnswer(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  return typeof value === "string" ? value.trim() : "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // The Supabase gateway verifies the member's JWT before this runs
  // (verify_jwt is on for this function); require the header regardless.
  if (!req.headers.get("Authorization")) return json({ error: "unauthorized" }, 401);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "ai_not_configured" }, 503);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const answers = {
    offer: readAnswer(body, "offer"),
    seek: readAnswer(body, "seek"),
    interests: readAnswer(body, "interests"),
    area: readAnswer(body, "area"),
  };
  if (Object.values(answers).some((a) => a.length > MAX_ANSWER_LENGTH)) {
    return json({ error: "answer_too_long" }, 413);
  }
  if (Object.values(answers).every((a) => a.length === 0)) {
    return json({ skills: [], interests: [], goals: [], area: "" });
  }

  // The app gives up after 8 seconds, so don't wait longer than that here.
  const client = new Anthropic({ apiKey, timeout: 7000, maxRetries: 0 });

  try {
    const response = await client.beta.messages.create({
      model: MODEL,
      max_tokens: 4000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      output_config: {
        effort: "low",
        format: { type: "json_schema", schema: SCHEMA },
      },
      system: SYSTEM,
      messages: [
        {
          role: "user",
          content: [
            "What I can offer:",
            answers.offer || "(blank)",
            "",
            "What I'm looking for:",
            answers.seek || "(blank)",
            "",
            "My interests:",
            answers.interests || "(blank)",
            "",
            "Where I'd like to find opportunities:",
            answers.area || "(blank)",
          ].join("\n"),
        },
      ],
    });

    if (response.stop_reason === "refusal") return json({ error: "declined" }, 422);
    if (response.stop_reason === "max_tokens") return json({ error: "incomplete" }, 502);

    const text = response.content
      .filter((block) => block.type === "text")
      .map((block) => (block as { text: string }).text)
      .join("");
    return json(JSON.parse(text));
  } catch (error) {
    if (error instanceof Anthropic.APIConnectionTimeoutError) return json({ error: "timeout" }, 504);
    if (error instanceof Anthropic.RateLimitError) return json({ error: "rate_limited" }, 429);
    if (error instanceof Anthropic.AuthenticationError) return json({ error: "ai_misconfigured" }, 503);
    if (error instanceof Anthropic.APIError) return json({ error: "upstream_error" }, 502);
    if (error instanceof SyntaxError) return json({ error: "malformed_output" }, 502);
    console.error("extract-profile failed", error);
    return json({ error: "internal_error" }, 500);
  }
});
