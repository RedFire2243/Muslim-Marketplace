# Production cost model

Prepared October 25, 2026. USD per month unless stated otherwise. Planning scenarios, not measured bills. “Query search” means typed search, as confirmed by the owner.

## What the app currently consumes

- Voice: microphone audio → Gemini `gemini-3.8-flash` transcription → the same search pipeline as typing. Recording stops at 15 seconds or earlier. Silent recordings are filtered before transmission.
- Typed search: deterministic Dart parsing and ranking, with no model call. Matching explanations are deterministic too. There is no external web-search API in this flow.
- Data: connected mode uses Supabase Postgres, Auth, Realtime and optional Edge Functions. Demo mode uses local storage.
- Optional onboarding extraction: a server function calls `claude-opus-5-5` when AI extraction is enabled. This is separate from recurring searches.
- No QR-specific cost or product-catalog API is required for this scope.

Evidence: `lib/src/voice/speech_transcriber.dart`, `lib/src/state/voice_search.dart`, `lib/src/state/discovery.dart`, `lib/src/data/supabase/supabase_backend.dart`, `supabase/functions/extract-profile/index.ts`.

## Assumptions

N is monthly active authenticated users, not registered accounts or daily users.

| Driver | Base scenario |
| --- | ---: |
| Searches per MAU per month | 20 |
| Voice share | 40% |
| Voice recordings per MAU | 8 |
| Average recording | 10 seconds |
| Text prompt per transcription | 250 tokens |
| Billed output per transcription, including thinking | 60 tokens |
| Backend uncached egress per MAU | 10 MB/month |
| Extra database compute allowance, at 1K / 10K / 100K / 1M MAU | $0 / $50 / $200 / $1,000 |

The token, traffic and compute quantities are assumptions. The compute allowances are reserves, not provider quotes or capacity guarantees. The model assumes indexed, paginated search before substantial growth; it does not extrapolate the current full-list download pattern. The 10 MB egress allowance covers structured API data and a light messaging workload, excluding media-heavy usage. Initial web-app downloads are also excluded pending measurement.

## Voice unit economics

[Google pricing](https://ai.google.dev/gemini-api/docs/pricing) lists Gemini 3.8 Flash Standard at $0.75/M input tokens and $3.75/M output tokens through December 31, 2026, then $1.50/M and $7.50/M starting January 1, 2027. [Audio documentation](https://ai.google.dev/gemini-api/docs/audio) specifies 32 input tokens per audio second.

```text
Voice cost = ((32 × audio seconds + prompt tokens) × input rate
              + billed output tokens × output rate) / 1,000,000

10-second search, 2026 = ((320 + 250) × 0.75 + 60 × 3.75) / 1,000,000
                      = $0.0006525
                      = $0.6525 per 1,000 voice searches
2027                  = $1.305 per 1,000 voice searches
```

At unchanged prompt/output sizes, 5 / 10 / 15 seconds cost $0.5325 / $0.6525 / $0.7725 per thousand in 2026. Thinking can materially raise billed output: the current transcription request does not set a generation token cap or thinking budget. Measure actual usage metadata before treating the estimate as a production unit cost. A further 1,000 billed output tokens per call adds $3.75 per thousand calls in 2026.

No free model quota is assumed. No audio generation, live conversation, web grounding or Maps grounding is included. Candidate cheaper transcription models need accuracy and latency evaluation on community names, accents and supported languages before switching.

## Supabase model and scale

[Supabase pricing](https://supabase.com/pricing) starts Pro at $25, including compute credit sufficient for one Micro instance, 100K auth MAU and 250 GB uncached egress. The model applies $0.00325 per auth MAU above 100K and $0.09 per uncached GB above 250. Included database disk is 8 GB; disk growth is separate. The auth allowance does not guarantee enough database compute for that many users.

```text
Backend = 25
        + max(N - 100,000, 0) × 0.00325
        + max(N × 0.01 - 250, 0) × 0.09
        + extra compute allowance
Voice   = N × 20 × 0.40 × 0.0006525
```

| MAU | Total searches | Voice searches | Voice, 2026 | Backend incl. compute reserve | Core total, 2026 | Core total, 2027 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 20,000 | 8,000 | $5.22 | $25.00 | $30.22 | $35.44 |
| 10,000 | 200,000 | 80,000 | $52.20 | $75.00 | $127.20 | $179.40 |
| 100,000 | 2,000,000 | 800,000 | $522.00 | $292.50 | $814.50 | $1,336.50 |
| 1,000,000 | 20,000,000 | 8,000,000 | $5,220.00 | $4,827.50 | $10,047.50 | $15,267.50 |

The 2027 column changes only the announced Gemini rates; all other prices and quantities are held constant. At 100K MAU the backend breakdown is $25 base + $67.50 egress + $200 compute reserve. At 1M it is $25 + $2,925 auth overage + $877.50 egress + $1,000 compute reserve.

Core cost per MAU in 2026 is approximately $0.0302 / $0.0127 / $0.0081 / $0.0100 across these scenarios. This is infrastructure unit cost, not full business cost or a recommended subscription price.

For an initial operating envelope, add 30% to the core total for variability: approximately $40 / $170 / $1,060 / $13,100 in 2026, or $50 / $235 / $1,740 / $19,850 in 2027. This contingency is not a quote for the excluded services below.

## Adding AI interpretation to typed and voice queries

There is no recurring search inference charge today. If we later interpret queries with an LLM, retrieve candidates in the database and send a small bounded payload rather than the entire catalog.

Illustration: Gemini 3.5 Flash-Lite Standard, 1,000 input tokens and 100 total billed output tokens, at $0.30/M input and $2.50/M output, costs $0.00055 per query, or $0.55 per thousand. Rates from [Google](https://ai.google.dev/gemini-api/docs/pricing); token sizes are assumptions, not a measured quality result.

| MAU | Add AI to 60% typed queries only | Add AI to every query |
| ---: | ---: | ---: |
| 1,000 | $6.60 | $11 |
| 10,000 | $66 | $110 |
| 100,000 | $660 | $1,100 |
| 1,000,000 | $6,600 | $11,000 |

These are additive to the core model, with voice transcription still charged separately. Long contexts, retries, thinking and generated summaries raise the price. Voice transcription and interpretation could potentially be combined into one request, but that needs a different implementation and validation.

## Cloudflare comparison

### Retain Supabase, add Cloudflare selectively

Recommended first production approach: keep Supabase accounts, Postgres access rules and private messaging. Use Cloudflare for static delivery and optionally a voice API proxy or future public media. Supabase Edge Functions can also provide the proxy; another vendor is not necessary just to hide the key.

[Workers](https://developers.cloudflare.com/workers/platform/pricing/) Paid starts at $5, including 10M monthly requests and 30M CPU milliseconds, with $0.30/M extra requests and $0.02/M extra CPU milliseconds. Waiting on a model's network response is not CPU time. A proxy does not remove the Gemini charge or Supabase auth/database charges.

[R2 Standard](https://developers.cloudflare.com/r2/pricing/) includes 10 GB-month, 1M Class A and 10M Class B operations. Beyond that, storage costs $0.015/GB-month, writes $4.50/M and reads $0.36/M; internet egress is free. For example, 100 GB of public media costs $1.35/month for storage after the allowance, plus operations. Access control and cache behavior still need design for private media.

### Move the backend to Workers + D1

This can lower the raw runtime bill but requires replacing the current Supabase integration, authorization rules, auth integration and realtime behavior. Authentication, email and messaging are not included in the following partial comparison.

Illustrative workload: 60 Worker requests per MAU per month at 5 ms CPU each; 2,000 billed D1 rows read and 10 billed rows written per MAU per month; 20 KB structured storage per MAU. Reads include scanned rows, not just results; this requires appropriate indexes and validation against real queries.

[D1 pricing](https://developers.cloudflare.com/d1/platform/pricing/) includes 25B monthly rows read, 50M rows written and 5 GB storage on Paid; overages are $0.001/M reads, $1/M writes and $0.75/GB-month storage.

| MAU | Workers + D1 only; excludes AI, auth, email, realtime and media |
| ---: | ---: |
| 1,000 | $5.00 |
| 10,000 | $5.00 |
| 100,000 | $5.00 |
| 1,000,000 | $36.65 |

At 1M MAU, Workers is $25.40 and D1 storage is $11.25; modeled read/write volumes remain within included quotas. This is a raw metered-cost illustration, not a complete replacement budget or throughput guarantee. [D1 limits](https://developers.cloudflare.com/d1/platform/limits/) cap each database at 10 GB, so the modeled 20 GB dataset requires splitting across databases or a different database design. Cross-community search and write concurrency need benchmarking. The raw cost advantage alone is insufficient to justify migration.

Migration economics: payback months = migration hours × loaded hourly cost / net monthly savings. An illustrative 40-hour migration at $75/hour costs $3,000; saving $50/month takes 60 months to recover before ongoing maintenance.

## Scaling risk in the present implementation

`_Listings.visible()` selects all rows allowed by row-level security, with no pagination or server-side search. The client ranks these locally. Providers reuse fetched data, so this is not necessarily a full download per typed query. However, listing changes invalidate the listing provider through Realtime and can cause another full fetch.

Example, not observed traffic: 10K listings × 2 KB each × 10 catalog fetches per MAU per month = 200 MB per MAU. At 100K MAU that is 20,000 GB uncached egress, producing approximately $1,777.50 in egress overage alone at $0.09/GB after 250 GB included. Compression, visibility, SDK/API row limits and cache lifetime change the actual result. Default API result limits can also truncate the catalog, creating a correctness issue before the full transfer estimate is reached.

Before growth: retrieve bounded candidate results on the server, index searchable fields, paginate, return only needed columns, scope realtime subscriptions, and invalidate individual records where practical. Fetching 25 rows of 2 KB produces a 50 KB result page instead of transferring the catalog.

## Costs outside the core table

- Onboarding AI: [Opus 5.5](https://platform.claude.com/docs/en/models/opus-5-5/overview) costs $4/M input and $20/M output tokens. Assuming 1,000 input and 500 billed output tokens, extraction is $0.014 per call or $140 per 10K calls. The function allows 4,000 output tokens: at that output level and assumed input it is $0.084/call. Thinking and configured provider fallbacks affect actual usage. Cost follows extraction attempts, including edits/retries, rather than MAU alone. Rules-only onboarding has no model charge.
- Realtime: message volume and peak connections depend on chat activity and fan-out, not just MAU. Price and forecast separately before a chat-heavy launch.
- Edge Functions: proxy calls consume invocations as well as Gemini usage; use provider included allowances and avoid double-counting a proxy in both Workers and Supabase. Supabase Pro includes 2M invocations, then $2/M; proxying all 8M voice calls at the largest scenario would add about $12 before other function activity.
- Database storage/indexes, accumulating message history, uploaded media, initial app downloads, image transformations and bandwidth beyond the assumed amount.
- Transactional email, optional SMS/phone verification, monitoring/log retention, backups beyond included retention, additional environments, domains, taxes and payment fees.
- Engineering, maintenance, community moderation, support and customer acquisition. These can exceed API spending, but are not estimated without a staffing plan.

## Recommended decision

Keep the present Supabase backend for the first production stage. Budget roughly $50–$250/month for 1K–10K MAU under this workload, including the upcoming voice price increase and some operating room. Fix data retrieval before a larger rollout. Proxy voice calls on the server with per-user quotas and rate limits, since the current build embeds the Gemini key and therefore does not enforce a trustworthy per-user spending limit.

Instrument actual audio duration, total billed input/output/thinking tokens, searches by modality, backend bytes, query latency, peak simultaneous connections, realtime fan-out and extraction attempts. Rebuild this forecast from those measurements after the first pilot. Evaluate Cloudflare migration when measured savings exceed the cost of rebuilding and maintaining equivalent features.
